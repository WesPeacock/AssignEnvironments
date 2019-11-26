#!/usr/bin/env perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section section] [--list] [--exact] [--debug] [file.sfm]";
=pod
A script to process a FLEx database and:
 - list alternate forms
 - list environments
 - parse alternate forms for an environment specification and assign the matching environment to the alternate form
  - matches can be exact or fuzzy, i.e. with spaces deleted
=cut
use 5.016;
use strict;
use warnings;
use utf8;

use open qw/:std :utf8/;
use XML::LibXML;
use Config::Tiny;
=pod
; AssignEnvironments.ini file looks like:
[AssignEnvironments]
infilename=Panao Quechua.fwdata
outfilename=Panao Quechua.1.fwdata
allomorphSFMs=a
ListEnvs=Yes
ListAllos=Yes

; MorphType guids
prefixguid=d7f713db-e8cf-11d3-9764-00c04f186933
suffixguid=d7f713dd-e8cf-11d3-9764-00c04f186933
stemguid=d7f713e8-e8cf-11d3-9764-00c04f186933
phraseguid=a23b6faa-1052-4f4d-984b-4b338bdaf95f

To Do:
List Allomorphs -- done
move listing settings to INI file

add noXML setting

If Allomorph contains an environment

Handle clitics
	?marked by Form= or =Form
=cut

use File::Basename;
use Getopt::Long;
use Data::Dumper qw(Dumper);

my $scriptname = fileparse($0, qr/\.[^.]*/); # script name without the .pl
GetOptions (
	'inifile:s'   => \(my $inifilename = "$scriptname.ini"), # ini filename
	'section:s'   => \(my $inisection = "AssignEnvironments"), # section of ini file to use
	'list'       => \my $list, # list only
	'exact'       => \my $exact, # don't normalize environment strings before matching
	
# additional options go here.
# 'sampleoption:s' => \(my $sampleoption = "optiondefault"),
	'debug'       => \my $debug,
	) or die $USAGE;

use Config::Tiny;
my $config = Config::Tiny->read($inifilename, 'crlf');
die "Quitting: couldn't find the INI file $inifilename\n$USAGE\n" if !$config;
say "Using INI file $inifilename" if $debug;

my $aflang = $config->{"$inisection"}->{AlterateFormLanguage};
say STDERR "Using language code:$aflang";
my $allomorphxpath = './Form/AUni[@ws="' . $aflang .'"]/text()';
say STDERR "Allomorph Form Xpath: $allomorphxpath" if $debug;


my $allomorphSFMs= $config->{"$inisection"}->{allomorphSFMs};
say STDERR "allomorph SFM =\\$allomorphSFMs" if $debug;
my $listenv = $list && ($config->{"$inisection"}->{ListEnvs} =~ m/(t|y)/i); # True or Yes
my $listallo = $list && ($config->{"$inisection"}->{ListAllos} =~ m/(t|y)/i); # True or Yes
my $listxml = $list && ($config->{"$inisection"}->{ListAsXML} =~ m/(t|y)/i); # True or Yes

my $stemguid = $config->{"$inisection"}->{stemguid};
my $prefixguid = $config->{"$inisection"}->{prefixguid};
my $suffixguid = $config->{"$inisection"}->{suffixguid};
my $phraseguid = $config->{"$inisection"}->{phraseguid};

=pod
\lx abiatarlx
\a abiatarbare
\a abiatarpre-
\a -abiatarsuf
\a abiatar phrase
\a abiatarbareenv / _ #
\a abiatarpreenv- / _ #
\a -abiatarsufenv / _ #
produces:
Note that the final one is imported as a suffix not a phrase
this fwdata extract is backed up in:
	PanaoQuechua 2019-11-12 1606 With 7 Abiatar allomorphs.fwbackup
<AlternateForms>
<objsur guid="c5760b7e-ee57-4cc3-857d-457524e8b6c5" t="o"/>
	<rt class="MoStemAllomorph" guid="c5760b7e-ee57-4 ...
		<Form><AUni ws="qxh">abiatarbare</AUni>...
		<MorphType><objsur guid="d7f713e8-e8cf-1...
			<rt class="MoMorphType" guid="d7f713e8-e8cf-1...
				<Name><AUni ws="en">stem</AUni><AUni ws="es">tema

<objsur guid="d4f37a26-800a-47dd-ba87-bc8b274b11bd" t="o"/>
	<rt class="MoAffixAllomorph" guid="d4f37a26-800a-47dd-b...
		<Form><AUni ws="qxh">abiatarpre</AU...
		<MorphType><objsur guid="d7f713db-e8cf-...
			<rt class="MoMorphType" guid="d7f713db-e8cf-11d3...
				<Name><AUni ws="en">prefix</AUni><AUni ws="es">prefijo</
				<Postfix><Uni>-</Uni...


<objsur guid="5ee290d3-8dfd-45bc-86d2-e9c2b9ed27c0" t="o"/>
	<rt class="MoAffixAllomorph" guid="5ee290d3-8dfd-45bc-86d2-...
		<Form><AUni ws="qxh">abiatarsuf</AU...
		<MorphType><objsur guid="d7f713dd-e8cf-11d...
			<rt class="MoMorphType" guid="d7f713dd-e8cf-11d...
				<Name><AUni ws="en">suffix</AUni><AUni ws="es">sufijo</AU...
				<Prefix><Uni>-</U...

<objsur guid="7f2e52a2-9f6c-4f52-ac48-406c74a26a56" t="o"/>
	<rt class="MoStemAllomorph" guid="7f2e52a2-9f6c-4f52-ac48...
	<Form><AUni ws="qxh">abiatar phrase</AUn
	<MorphType><objsur guid="a23b6faa-1052-4f
		<rt class="MoMorphType" guid="a23b6faa-1052-4f4
			<Name><AUni ws="en">phrase</AUni><AUni...

<objsur guid="f538192e-fbfc-4844-a3e4-9b9b7ae6cf08" t="o"/>
	<rt class="MoStemAllomorph" guid="f538192e-fbfc-484...
	<Form><AUni ws="qxh">abiatar / _ #</AUn
	<MorphType><objsur guid="a23b6faa-1052-4...
		see "phrase" previous

<objsur guid="d32b01c4-871e-4600-b0c7-d311a50727a6" t="o"/>
	<rt class="MoStemAllomorph" guid="d32b01c4-871e-4600-b0c7...
	<Form><AUni ws="qxh">abiatarpreenv- / _ #</AUni...
	<MorphType><objsur guid="a23b6faa-1052-4f...
		see "phrase" previous

<objsur guid="730c53fd-3091-435f-91b7-dc3e46c037b1" t="o"/>
	<rt class="MoAffixAllomorph" guid="730c53fd-3091-435f-9...
	<Form><AUni ws="qxh">abiatarsufenv / _ #</AUni...
	<MorphType><objsur guid="d7f713dd-e8cf-11d3...
		see "suffix" previous (-4)

</AlternateForms>

=cut

my $infwdata = $config->{"$inisection"}->{infwdata};
#say STDERR "config:", Dumper($config) if $debug;
say STDERR "infwdata:$infwdata" if $debug;

my $outfwdata = $config->{"$inisection"}->{outfwdata};
my $lockfile = $infwdata . '.lock' ;
die "A lockfile exists: $lockfile\
Don't run $0 when FW is running.\
Run it on a copy of the project, not the original!\
I'm quitting" if -f $lockfile ;


say "Processing fwdata file: $infwdata";

my $fwdatatree = XML::LibXML->load_xml(location => $infwdata);
say STDERR "$infwdata Loaded" if $debug;

my %rthash; # hash of all rt entries
my %mostemallohash; # hash of AlternateForms MoStemAllomorph
my %moaffixallohash; # hash of AlternateForms MoAffixAllomorph text forms by guid
my %envhash; # hash of environment rt entries
my %envtexthash; # hash of environment guid/exact environment
my %envfuzztexthash; # hash of environment guid/fuzzy environment
foreach my $rt ($fwdatatree->findnodes(q#//rt#)) {
	my $guid = $rt->getAttribute('guid');
	$rthash{$guid} = $rt;
	if ($rt->getAttribute('class') eq 'PhEnvironment') {
		$envhash{$guid} = $rt;
		my $envtext = getStringfromNodeList ($rt, './StringRepresentation/Str/Run/text()');
		if (defined $envtexthash{$envtext}) {
			say STDERR "Environment already in hash:$envtext";
			say STDERR "guids:$envtexthash{$envtext} & $guid";
			}
		else {
			$envtexthash{$envtext} = $guid;
			}
		$envtext =~ s/\s//g; # fuzzy match delete whitespace
		if (defined $envfuzztexthash{$envtext}) {
			say STDERR "Environment already in  fuzzy hash:$envtext";
			say STDERR "guids:$envfuzztexthash{$envtext} & $guid";
			}
		else {
			$envfuzztexthash{$envtext} = $guid;
			}
		}
	}

#say "envhash:", Dumper(%envhash) if $debug;
if ($listenv) {
	while ((my $envguid, my $envrt) = each (%envhash)) {
		my $envtext = getStringfromNodeList ($envrt, './StringRepresentation/Str/Run/text()');
		if ($listxml) {
			say '<Envguid>', $envguid, '</Envguid><Envtext>', $envtext, '</Envtext>';
			}
		else {
			say 'Env GUID: ', $envguid, ' Env Text: ', $envtext;
			}
		}
	while ((my $envtext, my $envguid) = each (%envtexthash)) {
		if ($listxml) {
			say '<Envguid>', $envguid, '</Envguid><EnvTextExact>', $envtext, '</EnvTextExact>';
			}
		else {
			say 'Env GUID: ', $envguid, ' Env Exact Text: ', $envtext;
			}
		}
	while ((my $envfuzztext, my $envguid) = each (%envfuzztexthash)) {
		if ($listxml) {
			say '<Envguid>', $envguid, '</Envguid><EnvTextFuzz>', $envfuzztext, '</EnvTextFuzz>';
			}
		else {
			say 'Env GUID: ', $envguid, ' Env Fuzzy Text: ', $envfuzztext;
			}
		}
	}

foreach my $afobjsur ($fwdatatree->findnodes(q#//AlternateForms/objsur#)) {
	my $guid = $afobjsur->getAttribute('guid');
	my $rt = $rthash{$guid};
	my $allotext = getStringfromNodeList ($rt, './Form/AUni[@ws="' . $aflang .'"]/text()');
	if ( !$allotext ) {
		say STDERR "Bad or Empty Allomorph GUID:", $guid;
		my $lexrt = traverseuptoclass($rt, 'LexEntry');
		say STDERR "   Under:", displaylexentstring($lexrt);
		next;
		}
	if ($rt->getAttribute('class') eq 'MoStemAllomorph') {
		$mostemallohash{$guid} = $allotext;
		}
	else {
		$moaffixallohash{$guid} = $allotext;
		}
	}

#say "StemAllohash:", Dumper(%mostemallohash) if $debug;
#say "AffixAllohash:", Dumper(%moaffixallohash) if $debug;
	if ($listallo) {
	while ((my $alloguid, my $allotext) = each (%mostemallohash)) {
		if ($listxml) {
			say '<StemAlloguid>', $alloguid, '</StemAlloguid><StemAlloText>', $allotext, '</StemAlloText>';
			}
		else {
			say 'Stem GUID: ', $alloguid, ' Stem Text: ', $allotext;
			}
		}
	while ((my $alloguid, my $allotext) = each (%moaffixallohash)) {
		if ($listxml) {
			say '<AffixAlloguid>', $alloguid, '</AffixAlloguid><AffixAlloText>', $allotext, '</AffixAlloText>';
			}
		else {
			say 'Affix GUID: ', $alloguid, ' Affix Text: ', $allotext;
			}
		}
	}

exit if ($listenv || $listallo);

while ((my $alloguid, my $allotext) = each (%mostemallohash)) {
	(my $matchtype, my $envguid) = matchEnvironment($allotext, \%envtexthash, \%envfuzztexthash);
	next if !$matchtype; # no env in this allomorph
	if ($matchtype eq "nomatch") {
		say STDERR qq[No environment match for stem allomorph:"$allotext"];
		next;
		}
	say STDERR qq[$matchtype match -- will put env "] .
		getStringfromNodeList ($rthash{$envguid}, './StringRepresentation/Str/Run/text()') .
		qq[", guid:$envguid attached to stem allomorph "$allotext"; guid:$alloguid"] if $debug;
	# code for Stems with matched Environments goes here
	# $envguid is the environment; $alloguid is the matching stem.
	if ($allotext =~ m[(.*?)\-(\ *?)(/.*)]) { # prefix with an env is imported as a phrase, i.e., a stem
		my $trunctext = $1;
		my $allort = $rthash{$alloguid};
		# Attribute values are done in place
		(my $attr) = $allort->findnodes('./@class');
		$attr->setValue("MoAffixAllomorph") if $attr;
		($attr) = $allort->findnodes('./MorphType/objsur/@guid');
		$attr->setValue($prefixguid) if $attr;

		# Copy the MorphType node to  make a new tree with PhonEnv node with the environment guid
		my $XMLstring = ($allort->findnodes('./MorphType'))[0]->toString;
		$XMLstring =~ s/MorphType/PhoneEnv/g;
		$XMLstring =~ s/(?<=guid\=\")[^\"]*/$envguid/;
		say STDERR "PhoneEnv node:$XMLstring" if $debug;
		my $newnode = XML::LibXML->load_xml(string => $XMLstring )->findnodes('//*')->[0];
		$allort->insertAfter($newnode, ($allort->findnodes('./MorphType'))[0]);

		# rewrite Form with the truncated text
		my ($oldTextnode) = $allort->findnodes('./Form/AUni[@ws="' . $aflang .'"]');
		say STDERR "Old envform:", $oldTextnode->toString if $debug;
		say STDERR "trunctext:$trunctext" if $debug;
		$XMLstring = qq[<AUni ws="$aflang">$trunctext</AUni>];
		say STDERR "New envform:$XMLstring" if $debug;
		$newnode = XML::LibXML->load_xml(string => $XMLstring )->findnodes('//*')->[0];
		$oldTextnode->parentNode->replaceChild($newnode, $oldTextnode) if $oldTextnode;
		}
	else { # not a prefix
		$allotext =~ m[(.*?)(\ *?)(/.*)];
		my $trunctext = $1;
		if ($trunctext =~ m/ /) { # a space means it's really a phrase
			say STDERR "Todo phrase matched alloform $allotext " if $debug;
			}
		else { # regular single word stem
			say STDERR "Todo stem matched alloform $allotext " if $debug;
			}
		}
	}


my $xmlstring = $fwdatatree->toString;
# Some miscellaneous Tidying differences
$xmlstring =~ s#><#>\n<#g;
$xmlstring =~ s#(<Run.*?)/\>#$1\>\</Run\>#g;
$xmlstring =~ s#/># />#g;
say "Finished processing, writing modified  $outfwdata" ;
open my $out_fh, '>:raw', $outfwdata;
print {$out_fh} $xmlstring;


# Subroutines

sub matchEnvironment {
# given an allophone's text, and exacthash and fuzzyhash of the environment guids
# returns
# $matchtype
#    0 if no environment in the text
#    "exact" if exact
#    "fuzzy" if fuzzy
#    "nomatch" if environment in the text but not found
# $guid -- guid of the matching environment, null string if no environment or no matches.
# environment is "/" to  the end of allomorph field
my( $allotext, $exact_h, $fuzzy_h ) = @_;
my %exacthash = %$exact_h;
my %fuzzyhash = %$fuzzy_h;

my $matchtype;
# say STDERR "in matchEnv sub with $allotext" if $debug;
return (0, "") if !($allotext =~ m[(\ *?)(/.*)]); # no env in allomorph
my $alloenv = $2;
say STDERR "Will check $allotext for \"$alloenv\"" if $debug;
my $envguid; # guid of environment found in the allophone text
if (!defined $exacthash{$alloenv}) { # not in exact hash
	$alloenv =~ s/\s//g; # delete whitespace for fuzzy match
	if ( !defined $fuzzyhash{$alloenv} ) { # not in fuzzy hash either
		$matchtype="nomatch";
		}
	else {
		$envguid = $envfuzztexthash{$alloenv};
		$matchtype = "fuzzy";
		}
	}
else { # exact match
	$envguid = $envtexthash{$alloenv};
	$matchtype = "exact";
	}
return ($matchtype, $envguid);
}

sub getStringfromNodeList {
# concatenate all the strings from a node list
my ($node, $xpath) =@_; # 
=pod
For Example,
$rt points to the following node:
	<rt class="..." guid="..." ownerguid="...">
	<OtherStuff>...</OtherStuff>
	<StringRepresentation><Str>
	<Run underline="none" ws="en">/_(</Run>
	<Run underline="none" ws="nko">[C]</Run>
	<Run underline="none" ws="en">)</Run>
	<Run underline="none" ws="nko">[+ATR]</Run>
	</Str></StringRepresentation>
	</rt>
$xpath= './StringRepresentation/Str/Run/text()';
Returns:
	'/_([C])[+ATR]'
=cut
my $retstring;
foreach ($node->findnodes($xpath)) {
	$retstring .= $_->toString;
	}
return $retstring;
}

sub rtheader { # dump the <rt> part of the record
my ($node) = @_;
return  ( split /\n/, $node )[0];
}

sub traverseuptoclass { 
	# starting at $rt
	#    go up the ownerguid links until you reach an
	#         rt @class == $rtclass
	#    or 
	#         no more ownerguid links
	# return the rt you found.
my ($rt, $rtclass) = @_;
	while ($rt->getAttribute('class') ne $rtclass) {
#		say ' At ', rtheader($rt);
		if ( !$rt->hasAttribute('ownerguid') ) {last} ;
		# find node whose @guid = $rt's @ownerguid
		$rt = $rthash{$rt->getAttribute('ownerguid')};
	}
#	say 'Found ', rtheader($rt);
	return $rt;
}

sub displaylexentstring {
my ($lexentrt) = @_;

my ($formguid) = $lexentrt->findvalue('./LexemeForm/objsur/@guid');
my $formrt =  $rthash{$formguid};
my ($formstring) =($rthash{$formguid}->findnodes('./Form/AUni/text()'))[0]->toString;
# If there's more than one encoding, you only get the first

my ($homographno) = $lexentrt->findvalue('./HomographNumber/@val');

my $guid = $lexentrt->getAttribute('guid');
return qq#$formstring hm:$homographno (guid="$guid")#;
}
