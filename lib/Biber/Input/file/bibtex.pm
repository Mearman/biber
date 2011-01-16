package Biber::Input::file::bibtex;
use sigtrap qw(handler TBSIG SEGV);
use strict;
use warnings;
use Carp;

use Text::BibTeX 0.48 qw(:nameparts :joinmethods :metatypes);
use Text::BibTeX::Name;
use Text::BibTeX::NameFormat;
use Biber::Constants;
use Biber::Entries;
use Biber::Entry;
use Biber::Entry::Names;
use Biber::Entry::Name;
use Biber::Sections;
use Biber::Section;
use Biber::Structure;
use Biber::Utils;
use Biber::Config;
use Encode;
use File::Spec;
use Log::Log4perl qw(:no_extra_logdie_message);
use base 'Exporter';
use List::AllUtils qw(first);

my $logger = Log::Log4perl::get_logger('main');

our $cache = {};

=head2 TBSIG

     Signal handler to catch fatal Text::BibTex SEGFAULTS. It has bugs
     and we want to say at least something if it coredumps

=cut

sub TBSIG {
  my $sig = shift;
  $logger->logdie("Caught signal: $sig\nLikely your .bib has a bad entry: $!");
}

=head2 extract_entries

   Main data extraction routine.
   Accepts a data source identifier (filename in this case),
   preprocesses the file and then looks for the passed keys,
   creating entries when it finds them and passes out an
   array of keys it didn't find.

=cut

sub extract_entries {
  my ($biber, $filename, $keys) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $bibentries = $section->bibentries;
  my @rkeys = @$keys;

  # Need to get the filename even if using cache so we increment
  # the filename count for preambles at the bottom of this sub
  $filename .= '.bib' unless $filename =~ /\.bib\z/xms; # Normalise filename
  my $trying_filename = $filename;
  if ($filename = locate_biber_file($filename)) {
    $logger->info("Processing bibtex format file '$filename' for section $secnum");
  }
  else {
    $logger->logdie("Cannot find file '$trying_filename'!")
  }

  # Text::BibTeX can't be controlled by Log4perl so we have to do something clumsy
  if (Biber::Config->getoption('quiet')) {
    open OLDERR, '>&', \*STDERR;
    open STDERR, '>', '/dev/null';
  }

  # Don't read the file again if it's already cached
  unless ($cache->{data}{$filename}) {
    $logger->debug("Caching data for bibtex format file '$filename' for section $secnum");
    cache_data($biber, $filename);
  }
  else {
    $logger->debug("Using cached data for bibtex format file '$filename' for section $secnum");
  }

  if ($section->is_allkeys) {
    $logger->debug("All cached citekeys will be used for section '$secnum'");
    # Loop over all entries, creating objects
    while (my (undef, $entry) = each %{$cache->{data}{$filename}}) {
      # We have to pass the datasource cased (and UTF-8ed) key to
      # create_entry() as this sub needs to know the original case of the
      # citation key so we can do case-insensitive key/entry comparisons
      # later but we need to put the original citation case when we write
      # the .bbl. If we lowercase before this, we lose this information.
      # Of course, with allkeys, "citation case" means "datasource entry case"
      create_entry($biber, decode_utf8($entry->key), $entry);
    }

    # if allkeys, push all bibdata keys into citekeys (if they are not already there)
    $section->add_citekeys($section->bibentries->sorted_keys);
    $logger->debug("Added all citekeys to section '$secnum': " . join(', ', $section->get_citekeys));
  }
  else {
    # loop over all keys we're looking for and create objects
    $logger->debug('Text::BibTeX cache keys: ' . join(', ', keys %{$cache->{data}{$filename}}));
    $logger->debug('Wanted keys: ' . join(', ', @$keys));
    foreach my $wanted_key (@$keys) {
      $logger->debug("Looking for key '$wanted_key' in Text::BibTeX cache");
      # Cache index keys are lower-cased. This next line effectively implements
      # case insensitive citekeys
      if (my $entry = $cache->{data}{$filename}{lc($wanted_key)}) {
        $logger->debug("Found key '$wanted_key' in Text::BibTeX cache");
        # See comment above about the importance of the case of the key
        # passed to create_entry()
        create_entry($biber, $wanted_key, $entry);
        # found a key, remove it from the list of keys we want
        @rkeys = grep {$wanted_key ne $_} @rkeys;
      }
      $logger->debug('Wanted keys now: ' . join(', ', @rkeys));
    }
  }

  if (Biber::Config->getoption('quiet')) {
    open STDERR, '>&', \*OLDERR;
  }

  # Only push the preambles from the file if we haven't seen this data file before
  # and there are some preambles to push
  if ($cache->{counts}{$filename} < 2 and @{$cache->{preamble}{$filename}}) {
    push @{$biber->{preamble}}, @{$cache->{preamble}{$filename}};
  }

  return @rkeys;
}

=head2 create_entry

   Create a Biber::Entry object from a Text::BibTeX object

=cut

sub create_entry {
  my ($biber, $origkey, $entry) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);
  my $struc = Biber::Config->get_structure;
  my $bibentries = $section->bibentries;

  # Want a version of the key that is the same case as any citations which
  # reference it, in case they are different. We use this as the .bbl
  # entry key
  my $citecasekey = first {lc($origkey) eq lc($_)} $section->get_citekeys;
  $citecasekey = $origkey unless $citecasekey;
  my $lc_key = lc($origkey);

  my $bibentry = new Biber::Entry;
  $bibentry->set_field('origkey', $origkey);
  $bibentry->set_field('citecasekey', $citecasekey);

  # all fields used for this entry
  my @flist = $entry->fieldlist;

  # here we only keep those that do not require splitting
  my @flistnosplit = reduce_array(\@flist, $struc->get_field_type('split'));

  if ( $entry->metatype == BTE_REGULAR ) {
    foreach my $f ( @flistnosplit ) {
      next unless $entry->exists($f);
      my $value = decode_utf8($entry->get($f));

      $bibentry->set_datafield($f, $value);

      # We have to process local options as early as possible in order
      # to make them available for things that need them like parsename()
      if (lc($f) eq 'options') {
        $biber->process_entry_options($bibentry);
      }
    }

    # Set entrytype. This may be changed later in process_aliases
    $bibentry->set_field('entrytype', $entry->type);

    foreach my $f ( @{$struc->get_field_type('split')} ) {
      next unless $entry->exists($f);
      my @tmp = $entry->split($f);

      if ($struc->is_field_type('name', $f)) {
        my $useprefix = Biber::Config->getblxoption('useprefix', $bibentry->get_field('entrytype'), $lc_key);
        my $names = new Biber::Entry::Names;
        foreach my $name (@tmp) {

          # Consecutive "and" causes Text::BibTeX::Name to segfault
          unless ($name) {
            $logger->warn("Name in key '$origkey' is empty (probably consecutive 'and'): skipping name");
            $biber->{warnings}++;
            $section->del_citekey($origkey);
            next;
          }

          $name = decode_utf8($name);

          # Check for malformed names in names which aren't completely escaped

          # Too many commas
          unless ($name =~ m/\A{.+}\z/xms) { # Ignore these tests for escaped names
            my @commas = $name =~ m/,/g;
            if ($#commas > 1) {
              $logger->warn("Name \"$name\" has too many commas: skipping entry $origkey");
              $biber->{warnings}++;
              $section->del_citekey($origkey);
              next;
            }

            # Consecutive commas cause Text::BibTeX::Name to segfault
            if ($name =~ /,,/) {
              $logger->warn("Name \"$name\" is malformed (consecutive commas): skipping entry $origkey");
              $biber->{warnings}++;
              $section->del_citekey($origkey);
              return;
            }
          }

          $names->add_element(parsename($name, $f, {useprefix => $useprefix}));
        }
        $bibentry->set_datafield($f, $names);

      }
      else {
        # Name fields are decoded during parsing, others here
        @tmp = map { decode_utf8($_) } @tmp;
        @tmp = map { remove_outer($_) } @tmp;
        $bibentry->set_datafield($f, [ @tmp ]);
      }
    }
    $bibentry->set_field('datatype', 'bibtex');
    $bibentries->add_entry($lc_key, $bibentry);
  }

  return;
}



=head2 cache_data

   Caches file data into T::B objects indexed by the original
   datasource key, decoded into UTF8

=cut

sub cache_data {
  my ($biber, $filename) = @_;

  # Initialise this
  $cache->{preamble}{$filename} = [];

  # Convert/decode file
  my $pfilename = preprocess_file($biber, $filename);

  my $bib = Text::BibTeX::File->new( $pfilename, '<' )
    or $logger->logdie("Cannot create Text::BibTeX::File object from $pfilename: $!");
  while ( my $entry = new Text::BibTeX::Entry $bib ) {

    if ( $entry->metatype == BTE_PREAMBLE ) {
      push @{$cache->{preamble}{$filename}}, decode_utf8($entry->value);
      next;
    }

    # Ignore misc bibtex entry types we don't care about
    next if ( $entry->metatype == BTE_MACRODEF or $entry->metatype == BTE_UNKNOWN
              or $entry->metatype == BTE_COMMENT );

    # If an entry has no key, ignore it and warn
    unless( $entry->key ) {
      $logger->warn("Invalid or undefined BibTeX entry key in file '$pfilename', skipping ...");
      $biber->{warnings}++;
      next;
    }

    # Text::BibTeX >= 0.46 passes through all citekey bits, thus allowing utf8 keys
    my $origkey = decode_utf8($entry->key);

    # Bad entry
    unless ($entry->parse_ok) {
      $logger->warn("Entry $origkey does not parse correctly: skipping");
      $biber->{warnings}++;
      next;
    }

    # Cache the entry so we don't have to read the file again on next pass.
    # Two reasons - So we avoid T::B macro redef warnings and speed
    $cache->{data}{$filename}{lc($origkey)} = $entry;
    $logger->debug("Cached Text::BibTeX entry for key '$origkey' from bibtex file '$filename'");
  }

  unlink $pfilename if -e $pfilename;

  return;
}


=head2 preprocess_file

   Convert file to UTF-8 and potentially decode LaTeX macros to UTF-8

=cut

sub preprocess_file {
  my ($biber, $filename) = @_;
  my $secnum = $biber->get_current_section;
  my $section = $biber->sections->get_section($secnum);

  my $ufilename = "${filename}_$$.utf8";

  # bib encoding is not UTF-8
  if (Biber::Config->getoption('bibencoding') ne 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($filename, encoding => Biber::Config->getoption('bibencoding'))
      or $logger->logdie("Can't read $filename");

    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or $logger->logdie("Can't write $ufilename");

  }
  else {
    File::Copy::copy($filename, $ufilename);
  }

  # Decode LaTeX to UTF8 if output is UTF-8
  if (Biber::Config->getoption('bblencoding') eq 'UTF-8') {
    require File::Slurp::Unicode;
    my $buf = File::Slurp::Unicode::read_file($ufilename, encoding => 'UTF-8')
      or $logger->logdie("Can't read $ufilename");
    require Biber::LaTeX::Recode;
    $logger->info('Decoding LaTeX character macros into UTF-8');
    $buf = Biber::LaTeX::Recode::latex_decode($buf, strip_outer_braces => 1,
                                              scheme => Biber::Config->getoption('decodecharsset'));

    File::Slurp::Unicode::write_file($ufilename, {encoding => 'UTF-8'}, $buf)
        or $logger->logdie("Can't write $ufilename");
  }

  # Increment the number of times each datafile has been referenced
  # For example, a datafile might be referenced in more than one section.
  # Some things find this information useful, for example, setting preambles is global
  # and so we need to know if we've already saved the preamble for a datafile.
  $cache->{counts}{$filename}++;

  return $ufilename;
}

=head2 parsename

    Given a name string, this function returns a Biber::Entry::Name object
    with all parts of the name resolved according to the BibTeX conventions.

    parsename('John Doe')
    returns an object which internally looks a bit like this:

    { firstname     => 'John',
      firstname_i   => 'J.',
      firstname_it  => 'J',
      lastname      => 'Doe',
      lastname_i    => 'D.',
      lastname_it   => 'D',
      prefix        => undef,
      prefix_i      => undef,
      prefix_it     => undef,
      suffix        => undef,
      suffix_i      => undef,
      suffix_it     => undef,
      namestring    => 'Doe, John',
      nameinitstring => 'Doe_J',
      strip          => {'firstname' => 0,
                         'lastname'  => 0,
                         'prefix'    => 0,
                         'suffix'    => 0}
      }

=cut

sub parsename {
  my ($namestr, $fieldname, $opts) = @_;
  $logger->debug("   Parsing namestring '$namestr'");
  my $usepre = $opts->{useprefix};
  # First sanitise the namestring due to Text::BibTeX::Name limitations on whitespace
  $namestr =~ s/\A\s*//xms; # leading whitespace
  $namestr =~ s/\s*\z//xms; # trailing whitespace
  $namestr =~ s/\s+/ /g;    # Collapse internal whitespace

  open OLDERR, '>&', \*STDERR;
  open STDERR, '>', '/dev/null';
  my $name = new Text::BibTeX::Name($namestr);
  open STDERR, '>&', \*OLDERR;

  # Formats so we can get BibTeX compatible nbsp inserted
  # We can't use formats to get initials as Text::BibTeX < 0.42 as it
  # has a problem dealing with braced names when extracting initials
  my $l_f = new Text::BibTeX::NameFormat('l', 0);
  my $f_f = new Text::BibTeX::NameFormat('f', 0);
  my $p_f = new Text::BibTeX::NameFormat('v', 0);
  my $s_f = new Text::BibTeX::NameFormat('j', 0);
  $l_f->set_options(BTN_LAST,  0, BTJ_MAYTIE, BTJ_NOTHING);
  $f_f->set_options(BTN_FIRST, 0, BTJ_MAYTIE, BTJ_NOTHING);
  $p_f->set_options(BTN_VON,   0, BTJ_MAYTIE, BTJ_NOTHING);
  $s_f->set_options(BTN_JR,    0, BTJ_MAYTIE, BTJ_NOTHING);

  # Generate name parts
  my $lastname  = decode_utf8($name->format($l_f));
  my $firstname = decode_utf8($name->format($f_f));
  my $prefix    = decode_utf8($name->format($p_f));
  my $suffix    = decode_utf8($name->format($s_f));

  # Variables to hold either the Text::BibTeX::NameFormat generated initials
  # or our own generated ones in case we are using a broken version of Text::BibTeX
  my $gen_lastname_i;
  my $gen_lastname_it;
  my $gen_firstname_i;
  my $gen_firstname_it;
  my $gen_prefix_i;
  my $gen_prefix_it;
  my $gen_suffix_i;
  my $gen_suffix_it;

  # Use a copy of $name so that when we generate the
  # initials, we do so without diacritics. This is easier than trying
  # hack the diacritics code into btparse ...

  # Initials formats
  my $li_f = new Text::BibTeX::NameFormat('l', 1);
  my $fi_f = new Text::BibTeX::NameFormat('f', 1);
  my $pi_f = new Text::BibTeX::NameFormat('v', 1);
  my $si_f = new Text::BibTeX::NameFormat('j', 1);

  # Truncated initials formats
  my $lit_f = new Text::BibTeX::NameFormat('l', 1);
  my $fit_f = new Text::BibTeX::NameFormat('f', 1);
  my $pit_f = new Text::BibTeX::NameFormat('v', 1);
  my $sit_f = new Text::BibTeX::NameFormat('j', 1);

  # first name doesn't need this customisation as it's automatic for
  # an abbreviated first name format but we'll do it anyway for consistency
  my $nd_name = new Text::BibTeX::Name(strip_nosort($namestr, $fieldname));

  # Period following normal initials
  $li_f->set_text(BTN_LAST,  undef, undef, undef, '.');
  $fi_f->set_text(BTN_FIRST, undef, undef, undef, '.');
  $pi_f->set_text(BTN_VON,   undef, undef, undef, '.');
  $si_f->set_text(BTN_JR,    undef, undef, undef, '.');
  $li_f->set_options(BTN_LAST,  1, BTJ_MAYTIE, BTJ_NOTHING);
  $fi_f->set_options(BTN_FIRST, 1, BTJ_MAYTIE, BTJ_NOTHING);
  $pi_f->set_options(BTN_VON,   1, BTJ_MAYTIE, BTJ_NOTHING);
  $si_f->set_options(BTN_JR,    1, BTJ_MAYTIE, BTJ_NOTHING);

  # Nothing following truncated initials
  $lit_f->set_text(BTN_LAST,  undef, undef, undef, '');
  $fit_f->set_text(BTN_FIRST, undef, undef, undef, '');
  $pit_f->set_text(BTN_VON,   undef, undef, undef, '');
  $sit_f->set_text(BTN_JR,    undef, undef, undef, '');
  $lit_f->set_options(BTN_LAST,  1, BTJ_NOTHING, BTJ_NOTHING);
  $fit_f->set_options(BTN_FIRST, 1, BTJ_NOTHING, BTJ_NOTHING);
  $pit_f->set_options(BTN_VON,   1, BTJ_NOTHING, BTJ_NOTHING);
  $sit_f->set_options(BTN_JR,    1, BTJ_NOTHING, BTJ_NOTHING);

  $gen_lastname_i    = decode_utf8($nd_name->format($li_f));
  $gen_lastname_it   = decode_utf8($nd_name->format($lit_f));
  $gen_firstname_i   = decode_utf8($nd_name->format($fi_f));
  $gen_firstname_it  = decode_utf8($nd_name->format($fit_f));
  $gen_prefix_i      = decode_utf8($nd_name->format($pi_f));
  $gen_prefix_it     = decode_utf8($nd_name->format($pit_f));
  $gen_suffix_i      = decode_utf8($nd_name->format($si_f));
  $gen_suffix_it     = decode_utf8($nd_name->format($sit_f));

  # Only warn about lastnames since there should always be one
  $logger->warn("Couldn't determine Last Name for name \"$namestr\"") unless $lastname;

  my $namestring = '';
  # prefix
  my $ps;
  my $prefix_stripped;
  my $prefix_i;
  my $prefix_it;
  if ($prefix) {
    $prefix_i        = $gen_prefix_i;
    $prefix_it       = $gen_prefix_it;
    $prefix_stripped = remove_outer($prefix);
    $ps = $prefix ne $prefix_stripped ? 1 : 0;
    $namestring .= "$prefix_stripped ";
  }
  # lastname
  my $ls;
  my $lastname_stripped;
  my $lastname_i;
  my $lastname_it;
  if ($lastname) {
    $lastname_i        = $gen_lastname_i;
    $lastname_it       = $gen_lastname_it;
    $lastname_stripped = remove_outer($lastname);
    $ls = $lastname ne $lastname_stripped ? 1 : 0;
    $namestring .= "$lastname_stripped, ";
  }
  # suffix
  my $ss;
  my $suffix_stripped;
  my $suffix_i;
  my $suffix_it;
  if ($suffix) {
    $suffix_i        = $gen_suffix_i;
    $suffix_it       = $gen_suffix_it;
    $suffix_stripped = remove_outer($suffix);
    $ss = $suffix ne $suffix_stripped ? 1 : 0;
    $namestring .= "$suffix_stripped, ";
  }
  # firstname
  my $fs;
  my $firstname_stripped;
  my $firstname_i;
  my $firstname_it;
  if ($firstname) {
    $firstname_i        = $gen_firstname_i;
    $firstname_it       = $gen_firstname_it;
    $firstname_stripped = remove_outer($firstname);
    $fs = $firstname ne $firstname_stripped ? 1 : 0;
    $namestring .= "$firstname_stripped";
  }

  # Remove any trailing comma and space if, e.g. missing firstname
  # Replace any nbspes
  $namestring =~ s/,\s+\z//xms;
  $namestring =~ s/~/ /gxms;

  # Construct $nameinitstring
  my $nameinitstr = '';
  $nameinitstr .= $prefix_it . '_' if ( $usepre and $prefix );
  $nameinitstr .= $lastname if $lastname;
  $nameinitstr .= '_' . $suffix_it if $suffix;
  $nameinitstr .= '_' . $firstname_it if $firstname;
  $nameinitstr =~ s/\s+/_/g;
  $nameinitstr =~ s/~/_/g;

  # The "strip" entry tells us which of the name parts had outer braces
  # stripped during processing so we can add them back when printing the
  # .bbl so as to maintain maximum BibTeX compatibility
  return Biber::Entry::Name->new(
    firstname       => $firstname      eq '' ? undef : $firstname_stripped,
    firstname_i     => $firstname      eq '' ? undef : $firstname_i,
    firstname_it    => $firstname      eq '' ? undef : $firstname_it,
    lastname        => $lastname       eq '' ? undef : $lastname_stripped,
    lastname_i      => $lastname       eq '' ? undef : $lastname_i,
    lastname_it     => $lastname       eq '' ? undef : $lastname_it,
    prefix          => $prefix         eq '' ? undef : $prefix_stripped,
    prefix_i        => $prefix         eq '' ? undef : $prefix_i,
    prefix_it       => $prefix         eq '' ? undef : $prefix_it,
    suffix          => $suffix         eq '' ? undef : $suffix_stripped,
    suffix_i        => $suffix         eq '' ? undef : $suffix_i,
    suffix_it       => $suffix         eq '' ? undef : $suffix_it,
    namestring      => $namestring,
    nameinitstring  => $nameinitstr,
    strip           => {'firstname' => $fs,
                        'lastname'  => $ls,
                        'prefix'    => $ps,
                        'suffix'    => $ss}
    );
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Biber::Input::BibTeX - parse a bib database with Text::BibTeX

=head1 DESCRIPTION

Internal method ...

=head1 AUTHOR

François Charette, C<< <firmicus at gmx.net> >>
Philip Kime C<< <philip at kime.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests on our sourceforge tracker at
L<https://sourceforge.net/tracker2/?func=browse&group_id=228270>.

=head1 COPYRIGHT & LICENSE

Copyright 2009-2011 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# vim: set tabstop=2 shiftwidth=2 expandtab:
