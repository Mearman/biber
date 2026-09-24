#!/bin/bash
#
# Pack an installed biber into a standalone PAR::Packer executable for the
# current macOS architecture (arm64 or x86_64), using a Homebrew Perl toolchain
# instead of the fixed MacPorts layout that dist/darwin_arm64/build.sh and
# dist/darwin_x86_64/build.sh assume. Run from the repository root, after
# `perl Build.PL`, `./Build installdeps` and `./Build install` have completed
# against the Perl on PATH, and after installing the pinned PAR::Packer commit
# that fixes the macOS 27 `lipo -extract_family` removal.
#
# Usage: dist/darwin_common/pack.sh <output-name>

set -euo pipefail

output="${1:?usage: pack.sh <output-name>}"

sitebin=$(perl -MConfig -e 'print $Config{installsitebin}')
sitelib=$(perl -MConfig -e 'print $Config{installsitelib}')
sitearch=$(perl -MConfig -e 'print $Config{installsitearch}')
archlib=$(perl -MConfig -e 'print $Config{archlib}')

# The packed main script must not be called "biber": on a case-insensitive
# filesystem this collides with the sibling Biber/ lib directory pp bundles
# and produces a harmless warning on first run, matching the upstream
# dist/darwin_*/build.sh scripts' own cp-to-/tmp workaround.
work_script=$(mktemp -t biber-darwin-src)
cp "${sitebin}/biber" "${work_script}"
trap 'rm -f "${work_script}"' EXIT

# Locate data files that ship inside CPAN-installed modules rather than
# biber's own tree, so pp can bundle them under the lib/ paths biber's code
# expects at runtime. Found by inspecting the actually-installed module
# layout rather than a hardcoded MacPorts path, so this works regardless of
# which Perl toolchain provided them.
ucollate_dir=$(perl -MUnicode::Collate -e '($p = $INC{"Unicode/Collate.pm"}) =~ s/\.pm$//; print $p')
mozilla_ca=$(perl -MMozilla::CA -e 'print Mozilla::CA::SSL_ca_file()')
isbn_rangemsg=$(find "${sitelib}" "${sitearch}" -name RangeMessage.xml -print -quit)
linebreak_bundle=$(find "${sitearch}" "${archlib}" \( -name 'LineBreak.bundle' -o -name 'LineBreak.so' \) -print -quit)

[ -n "${ucollate_dir}" ] || { echo "pack.sh: Unicode::Collate install dir not found" >&2; exit 1; }
[ -n "${mozilla_ca}" ] || { echo "pack.sh: Mozilla::CA cacert.pem not found" >&2; exit 1; }
[ -n "${isbn_rangemsg}" ] || { echo "pack.sh: Business::ISBN RangeMessage.xml not found" >&2; exit 1; }
[ -n "${linebreak_bundle}" ] || { echo "pack.sh: Unicode::LineBreak XS bundle not found" >&2; exit 1; }

# PAR::Packer's static dependency scan (Module::ScanDeps) follows perl-level
# use/require, so it reliably finds each XS module's own directly-linked
# dylibs. Collect every non-system dylib actually linked by an installed XS
# bundle and hand each to --link explicitly. This is the same thing biber's
# own dist/darwin_*/build.sh scripts do by hand for a fixed MacPorts layout;
# doing it by inspection here reproduces that bundling for whatever
# Homebrew or CPAN prefixes the current runner happens to use.
declare -A seen_libs=()
link_args=()
while IFS= read -r -d '' bundle; do
  while IFS= read -r lib; do
    case "${lib}" in
      /usr/lib/*|/System/*|@rpath/*|@loader_path/*|@executable_path/*) continue ;;
    esac
    [ -n "${seen_libs[${lib}]:-}" ] && continue
    seen_libs[${lib}]=1
    link_args+=(--link="${lib}")
  done < <(otool -L "${bundle}" | tail -n +2 | awk '{print $1}')
done < <(find "${sitearch}" "${archlib}" \( -name '*.bundle' -o -name '*.so' \) -print0)

echo "pack.sh: resolved --link arguments:"
printf '  %s\n' "${link_args[@]}"

PAR_VERBATIM=1 pp \
  --module=deprecate \
  --module=Biber::Input::file::bibtex \
  --module=Biber::Input::file::biblatexml \
  --module=Biber::Output::dot \
  --module=Biber::Output::bbl \
  --module=Biber::Output::bblxml \
  --module=Biber::Output::bibtex \
  --module=Biber::Output::biblatexml \
  --module=Pod::Simple::TranscodeSmart \
  --module=Pod::Simple::TranscodeDumb \
  --module=List::MoreUtils::XS \
  --module=List::SomeUtils::XS \
  --module=List::MoreUtils::PP \
  --module=HTTP::Status \
  --module=HTTP::Date \
  --module=Encode:: \
  --module=File::Find::Rule \
  --module=IO::Socket::SSL \
  --module=IO::String \
  --module=PerlIO::utf8_strict \
  --module=Text::CSV_XS \
  --module=DateTime \
  "${link_args[@]}" \
  --addfile="data/biber-tool.conf;lib/Biber/biber-tool.conf" \
  --addfile="data/schemata/config.rnc;lib/Biber/config.rnc" \
  --addfile="data/schemata/config.rng;lib/Biber/config.rng" \
  --addfile="data/schemata/bcf.rnc;lib/Biber/bcf.rnc" \
  --addfile="data/schemata/bcf.rng;lib/Biber/bcf.rng" \
  --addfile="lib/Biber/LaTeX/recode_data.xml;lib/Biber/LaTeX/recode_data.xml" \
  --addfile="data/bcf.xsl;lib/Biber/bcf.xsl" \
  --addfile="${ucollate_dir}/Locale;lib/Unicode/Collate/Locale" \
  --addfile="${ucollate_dir}/CJK;lib/Unicode/Collate/CJK" \
  --addfile="${ucollate_dir}/allkeys.txt;lib/Unicode/Collate/allkeys.txt" \
  --addfile="${ucollate_dir}/keys.txt;lib/Unicode/Collate/keys.txt" \
  --addfile="${mozilla_ca};lib/Mozilla/CA/cacert.pem" \
  --addfile="${isbn_rangemsg};lib/Business/ISBN/RangeMessage.xml" \
  --addfile="${linebreak_bundle};lib/auto/Unicode/LineBreak/$(basename "${linebreak_bundle}")" \
  --cachedeps=scancache \
  --output="${output}" \
  "${work_script}"
