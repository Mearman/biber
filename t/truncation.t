# -*- cperl -*-
use strict;
use warnings;
use utf8;
no warnings 'utf8';

use Test::More tests => 12;
use Test::Differences;
unified_diff;

use Biber;
use Biber::Utils;
use Biber::Output::bbl;
use Log::Log4perl;
chdir("t/tdata");

# Set up Biber object
my $biber = Biber->new(noconf => 1);
my $LEVEL = 'ERROR';
my $l4pconf = qq|
    log4perl.category.main                             = $LEVEL, Screen
    log4perl.category.screen                           = $LEVEL, Screen
    log4perl.appender.Screen                           = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.utf8                      = 1
    log4perl.appender.Screen.Threshold                 = $LEVEL
    log4perl.appender.Screen.stderr                    = 0
    log4perl.appender.Screen.layout                    = Log::Log4perl::Layout::SimpleLayout
|;
Log::Log4perl->init(\$l4pconf);

$biber->parse_ctrlfile('truncation.bcf');
$biber->set_output_obj(Biber::Output::bbl->new());

# Options - we could set these in the control file but it's nice to see what we're
# relying on here for tests

# Biber options
Biber::Config->setoption('sortlocale', 'en_GB.UTF-8');

# Turn this off so minbibnames is always 1 (from .bcf)
Biber::Config->setblxoption(undef, 'uniquelist', 'false');

# Now generate the information
$biber->prepare;
my $section = $biber->sections->get_section(0);
my $main = $biber->datalists->get_list('nty/global//global/global/global');
my $out = $biber->get_output_obj;

my $us1 = q|    \entry{us1}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=6a9b0705c275273262103333472cc656}{%
           family={Elk},
           familyi={E\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Elk},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{6a9b0705c275273262103333472cc656}
      \strng{fullhash}{6a9b0705c275273262103333472cc656}
      \strng{fullhashraw}{6a9b0705c275273262103333472cc656}
      \strng{bibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usbibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usfullhash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usfullhashraw}{6a9b0705c275273262103333472cc656}
      \field{labelalpha}{Elk72}
      \field{sortinit}{E}
      \strng{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{A Theory on Brontosauruses}
      \field{year}{1972}
      \field{dateera}{ce}
    \endentry
|;

my $us2a = q|    \entry{us2}{book}{}{}
      \true{moreauthor}
      \true{morelabelname}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=6a9b0705c275273262103333472cc656}{%
           family={Elk},
           familyi={E\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Elk},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{fullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{fullhashraw}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{bibnamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authordefaulten-usbibnamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authordefaulten-usnamehash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authordefaulten-usfullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authordefaulten-usfullhashraw}{40a337fc8d6319ae5a7b50f6324781ec}
      \field{labelalpha}{Elk\textbf{+}72}
      \field{sortinit}{E}
      \strng{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{A Theory on Einiosauruses}
      \field{year}{1972}
      \field{dateera}{ce}
    \endentry
|;

my $us3 = q|    \entry{us3}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=e06f6e5a8c1d5204dea326aa5f4f8d17}{%
           family={Uthor},
           familyi={U\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Uthor},
          familydefaulten-usi={U\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{fullhash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{fullhashraw}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{bibnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usbibnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usfullhash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usfullhashraw}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \field{labelalpha}{Uth00}
      \field{sortinit}{U}
      \strng{sortinithash}{6901a00e45705986ee5e7ca9fd39adca}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title B}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;


my $us4a = q|    \entry{us4}{book}{}{}
      \name[default][en-us]{author}{4}{}{%
        {{un=0,uniquepart=base,hash=e06f6e5a8c1d5204dea326aa5f4f8d17}{%
           family={Uthor},
           familyi={U\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=0868588743cd096fcda1144f2d3dd258}{%
           family={Ditor},
           familyi={D\bibinitperiod},
           given={Editha},
           giveni={E\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=7b10345a9314a9ba279e795d29f0a304}{%
           family={Writer},
           familyi={W\bibinitperiod},
           given={William},
           giveni={W\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=d6cfb2b8c4b3f9440ec4642438129367}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={Jane},
           giveni={J\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Uthor},
          familydefaulten-usi={U\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={Ditor},
          familydefaulten-usi={D\bibinitperiod},
          givendefaulten-us={Editha},
          givendefaulten-usi={E\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Writer},
          familydefaulten-usi={W\bibinitperiod},
          givendefaulten-us={William},
          givendefaulten-usi={W\bibinitperiod}
      }
      \namepartms{author}{4}{%
          familydefaulten-us={Doe},
          familydefaulten-usi={D\bibinitperiod},
          givendefaulten-us={Jane},
          givendefaulten-usi={J\bibinitperiod}
      }
      \strng{namehash}{f3c0538e23d09e1678b81f4ba4253fcc}
      \strng{fullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{fullhashraw}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{bibnamehash}{f3c0538e23d09e1678b81f4ba4253fcc}
      \strng{authordefaulten-usbibnamehash}{f3c0538e23d09e1678b81f4ba4253fcc}
      \strng{authordefaulten-usnamehash}{f3c0538e23d09e1678b81f4ba4253fcc}
      \strng{authordefaulten-usfullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{authordefaulten-usfullhashraw}{fe131471bcc6dda25dc02e0dd6a7c488}
      \field{extraname}{1}
      \field{labelalpha}{Uth\textbf{+}00}
      \field{sortinit}{U}
      \strng{sortinithash}{6901a00e45705986ee5e7ca9fd39adca}
      \field{extradate}{1}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title A}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;

my $us2b = q|    \entry{us2}{book}{}{}
      \true{moreauthor}
      \true{morelabelname}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=6a9b0705c275273262103333472cc656}{%
           family={Elk},
           familyi={E\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Elk},
          familydefaulten-usi={E\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \strng{namehash}{6a9b0705c275273262103333472cc656}
      \strng{fullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{fullhashraw}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{bibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usbibnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usnamehash}{6a9b0705c275273262103333472cc656}
      \strng{authordefaulten-usfullhash}{40a337fc8d6319ae5a7b50f6324781ec}
      \strng{authordefaulten-usfullhashraw}{40a337fc8d6319ae5a7b50f6324781ec}
      \field{extraname}{2}
      \field{labelalpha}{Elk\textbf{+}72}
      \field{sortinit}{E}
      \strng{sortinithash}{8da8a182d344d5b9047633dfc0cc9131}
      \field{extradate}{2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{A Theory on Einiosauruses}
      \field{year}{1972}
      \field{dateera}{ce}
    \endentry
|;


my $us4b = q|    \entry{us4}{book}{}{}
      \name[default][en-us]{author}{4}{}{%
        {{un=0,uniquepart=base,hash=e06f6e5a8c1d5204dea326aa5f4f8d17}{%
           family={Uthor},
           familyi={U\bibinitperiod},
           given={Anne},
           giveni={A\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=0868588743cd096fcda1144f2d3dd258}{%
           family={Ditor},
           familyi={D\bibinitperiod},
           given={Editha},
           giveni={E\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=7b10345a9314a9ba279e795d29f0a304}{%
           family={Writer},
           familyi={W\bibinitperiod},
           given={William},
           giveni={W\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=d6cfb2b8c4b3f9440ec4642438129367}{%
           family={Doe},
           familyi={D\bibinitperiod},
           given={Jane},
           giveni={J\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Uthor},
          familydefaulten-usi={U\bibinitperiod},
          givendefaulten-us={Anne},
          givendefaulten-usi={A\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={Ditor},
          familydefaulten-usi={D\bibinitperiod},
          givendefaulten-us={Editha},
          givendefaulten-usi={E\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Writer},
          familydefaulten-usi={W\bibinitperiod},
          givendefaulten-us={William},
          givendefaulten-usi={W\bibinitperiod}
      }
      \namepartms{author}{4}{%
          familydefaulten-us={Doe},
          familydefaulten-usi={D\bibinitperiod},
          givendefaulten-us={Jane},
          givendefaulten-usi={J\bibinitperiod}
      }
      \strng{namehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{fullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{fullhashraw}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{bibnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usbibnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usnamehash}{e06f6e5a8c1d5204dea326aa5f4f8d17}
      \strng{authordefaulten-usfullhash}{fe131471bcc6dda25dc02e0dd6a7c488}
      \strng{authordefaulten-usfullhashraw}{fe131471bcc6dda25dc02e0dd6a7c488}
      \field{extraname}{2}
      \field{labelalpha}{Uth\textbf{+}00}
      \field{sortinit}{U}
      \strng{sortinithash}{6901a00e45705986ee5e7ca9fd39adca}
      \field{extradate}{2}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title A}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;

my $us6 = q|    \entry{us6}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=cbe9a5912d961199801c3fcd32356ecf}{%
           family={Red},
           familyi={R\bibinitperiod},
           given={Roger},
           giveni={R\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Red},
          familydefaulten-usi={R\bibinitperiod},
          givendefaulten-us={Roger},
          givendefaulten-usi={R\bibinitperiod}
      }
      \strng{namehash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{fullhash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{fullhashraw}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{bibnamehash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{authordefaulten-usbibnamehash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{authordefaulten-usnamehash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{authordefaulten-usfullhash}{cbe9a5912d961199801c3fcd32356ecf}
      \strng{authordefaulten-usfullhashraw}{cbe9a5912d961199801c3fcd32356ecf}
      \field{labelalpha}{Red71}
      \field{sortinit}{R}
      \strng{sortinithash}{5e1c39a9d46ffb6bebd8f801023a9486}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Ragged Rubles}
      \field{year}{1971}
      \field{dateera}{ce}
    \endentry
|;

my $us7 = q|    \entry{us7}{misc}{}{}
      \true{moreauthor}
      \true{morelabelname}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=cbe9a5912d961199801c3fcd32356ecf}{%
           family={Red},
           familyi={R\bibinitperiod},
           given={Roger},
           giveni={R\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Red},
          familydefaulten-usi={R\bibinitperiod},
          givendefaulten-us={Roger},
          givendefaulten-usi={R\bibinitperiod}
      }
      \strng{namehash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{fullhash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{fullhashraw}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{bibnamehash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{authordefaulten-usbibnamehash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{authordefaulten-usnamehash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{authordefaulten-usfullhash}{d70785a70cdf36c7b5dc7b136207ada9}
      \strng{authordefaulten-usfullhashraw}{d70785a70cdf36c7b5dc7b136207ada9}
      \field{labelalpha}{Red\textbf{+}71}
      \field{sortinit}{R}
      \strng{sortinithash}{5e1c39a9d46ffb6bebd8f801023a9486}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Ragged Rupees}
      \field{year}{1971}
      \field{dateera}{ce}
    \endentry
|;

my $us8 = q|    \entry{us8}{book}{}{}
      \name[default][en-us]{author}{1}{}{%
        {{un=0,uniquepart=base,hash=a280925c093d27fe81e88f11d8f0e537}{%
           family={Sly},
           familyi={S\bibinitperiod},
           given={Simon},
           giveni={S\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Sly},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Simon},
          givendefaulten-usi={S\bibinitperiod}
      }
      \strng{namehash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{fullhash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{fullhashraw}{a280925c093d27fe81e88f11d8f0e537}
      \strng{bibnamehash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{authordefaulten-usbibnamehash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{authordefaulten-usnamehash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{authordefaulten-usfullhash}{a280925c093d27fe81e88f11d8f0e537}
      \strng{authordefaulten-usfullhashraw}{a280925c093d27fe81e88f11d8f0e537}
      \field{extraname}{1}
      \field{labelalpha}{Sly00}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{extradate}{1}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title B}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;

my $us9 = q|    \entry{us9}{book}{}{}
      \name[default][en-us]{author}{4}{}{%
        {{un=0,uniquepart=base,hash=a280925c093d27fe81e88f11d8f0e537}{%
           family={Sly},
           familyi={S\bibinitperiod},
           given={Simon},
           giveni={S\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=8c554215938d0dd957e9d4d6d397117e}{%
           family={Tremble},
           familyi={T\bibinitperiod},
           given={Terrence},
           giveni={T\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=4298e3d6e385e61d7901144a7d5a1458}{%
           family={Miserable},
           familyi={M\bibinitperiod},
           given={Mark},
           giveni={M\bibinitperiod},
           givenun=0}}%
        {{un=0,uniquepart=base,hash=af60b6c4ffd6f2311900410a5210e169}{%
           family={Jolly},
           familyi={J\bibinitperiod},
           given={Jake},
           giveni={J\bibinitperiod},
           givenun=0}}%
      }
      \namepartms{author}{1}{%
          familydefaulten-us={Sly},
          familydefaulten-usi={S\bibinitperiod},
          givendefaulten-us={Simon},
          givendefaulten-usi={S\bibinitperiod}
      }
      \namepartms{author}{2}{%
          familydefaulten-us={Tremble},
          familydefaulten-usi={T\bibinitperiod},
          givendefaulten-us={Terrence},
          givendefaulten-usi={T\bibinitperiod}
      }
      \namepartms{author}{3}{%
          familydefaulten-us={Miserable},
          familydefaulten-usi={M\bibinitperiod},
          givendefaulten-us={Mark},
          givendefaulten-usi={M\bibinitperiod}
      }
      \namepartms{author}{4}{%
          familydefaulten-us={Jolly},
          familydefaulten-usi={J\bibinitperiod},
          givendefaulten-us={Jake},
          givendefaulten-usi={J\bibinitperiod}
      }
      \strng{namehash}{86a4e119adbea22d40084fa1337729be}
      \strng{fullhash}{afe15ce8d7d22d0bbc042705c4b5fdf6}
      \strng{fullhashraw}{afe15ce8d7d22d0bbc042705c4b5fdf6}
      \strng{bibnamehash}{86a4e119adbea22d40084fa1337729be}
      \strng{authordefaulten-usbibnamehash}{86a4e119adbea22d40084fa1337729be}
      \strng{authordefaulten-usnamehash}{86a4e119adbea22d40084fa1337729be}
      \strng{authordefaulten-usfullhash}{afe15ce8d7d22d0bbc042705c4b5fdf6}
      \strng{authordefaulten-usfullhashraw}{afe15ce8d7d22d0bbc042705c4b5fdf6}
      \field{labelalpha}{Sly\textbf{+}00}
      \field{sortinit}{S}
      \strng{sortinithash}{b164b07b29984b41daf1e85279fbc5ab}
      \field{extradatescope}{labelyear}
      \field{labeldatesource}{}
      \field{extraalpha}{1}
      \fieldmssource{labelname}{author}{default}{en-us}
      \fieldmssource{labeltitle}{title}{default}{en-us}
      \field[default][en-us]{title}{Title A}
      \field{year}{2000}
      \field{dateera}{ce}
    \endentry
|;

eq_or_diff( $out->get_output_entry('us1', $main), $us1, 'Truncation - 1') ;
eq_or_diff( $out->get_output_entry('us3', $main), $us3, 'Truncation - 2') ;

# Should be different to us1 and us3 respectively with default (nohashothers=false)
eq_or_diff( $out->get_output_entry('us2', $main), $us2a, 'Truncation - 3') ;
eq_or_diff( $out->get_output_entry('us4', $main), $us4a, 'Truncation - 4') ;

Biber::Config->setblxoption(undef,'nohashothers', 1);
Biber::Config->setblxoption(undef,'nohashothers', 0, 'ENTRYTYPE', 'misc');

$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global/global');
$out = $biber->get_output_obj;

# namehash now the same as us1 and us3 respectively with (nohashothers=true)
eq_or_diff( $out->get_output_entry('us2', $main), $us2b, 'Truncation - 5') ;
eq_or_diff( $out->get_output_entry('us4', $main), $us4b, 'Truncation - 6') ;


eq_or_diff( $out->get_output_entry('us6', $main), $us6, 'Truncation - 7') ;
eq_or_diff( $out->get_output_entry('us8', $main), $us8, 'Truncation - 8') ;

# namehash not the same as for us6 and us7 due to entrytype option
eq_or_diff( $out->get_output_entry('us7', $main), $us7, 'Truncation - 9') ;
# namehash not the same as for us8 and us9 due to entry option
eq_or_diff( $out->get_output_entry('us9', $main), $us9, 'Truncation - 10') ;


# Testing nosortothers
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global/global');
$out = $biber->get_output_obj;

# Sorting with nosortothers=false
is_deeply($main->get_keys, ['us1', 'us2','us6', 'us7', 'us8', 'us9', 'us10','us3', 'us4', 'us5'], 'Truncation - 11');

Biber::Config->setblxoption(undef,'nosortothers', 1);
$biber->prepare;
$section = $biber->sections->get_section(0);
$main = $biber->datalists->get_list('nty/global//global/global/global');
$out = $biber->get_output_obj;

# Sorting with nosortothers=true
is_deeply($main->get_keys, ['us1', 'us2','us6', 'us7', 'us8', 'us10', 'us9','us4', 'us3', 'us5'], 'Truncation - 12');

