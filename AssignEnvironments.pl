#!/usr/bin/env perl
my $USAGE = "Usage: $0 [--inifile inifile.ini] [--section section] [--list] [--exact] [--debug] [file.sfm]";
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

To Do:
List Allomorphs

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
	'listenv'       => \my $listenv, # list the environments
	'exact'       => \my $exact, # don't normalize environment strings before matching
	
# additional options go here.
# 'sampleoption:s' => \(my $sampleoption = "optiondefault"),
	'debug'       => \my $debug,
	) or die $USAGE;

use Config::Tiny;
my $config = Config::Tiny->read($inifilename, 'crlf');
die "Quitting: couldn't find the INI file $inifilename\n$USAGE\n" if !$config;
say "Using INI file $inifilename" if $debug;
my $allomorphSFMs= $config->{"$inisection"}->{allomorphSFMs};
say STDERR "allomorph SFM =\\$allomorphSFMs" if $debug;

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
my %envhash; # hash of environment rt entries
foreach my $rt ($fwdatatree->findnodes(q#//rt#)) {
	my $guid = $rt->getAttribute('guid');
	$rthash{$guid} = $rt;
	$envhash{$guid} = $rt	if ($rt->getAttribute('class') eq 'PhEnvironment')
	}
	
#say "envhash:", Dumper(%envhash) if $debug;
if ($listenv) {
	while ((my $envguid, my $envrt) = each (%envhash)) {
		say STDERR "Envguid:$envguid" if $debug;
		my $envtext = getStringfromNodeList ($envrt, './StringRepresentation/Str/Run/text()');
		say STDERR "Envtext:$envtext" if $debug;
		}
	}
exit;
=pod
		{
		my $envtext = "";
		foreach ($rt->findnodes('./StringRepresentation/Str/Run/text()')) {
			$envtext .= $_->toString;
			};
		my $envname;
		foreach ($rt->findnodes('./Name/AUni/text()')) {
			$envname .= $_->toString;
			};

		}
=cut

my $modeltag = "";
my $modifytag = "";
my ($modelTextrt) = $fwdatatree->findnodes(q#//*[contains(., '# . $modeltag . q#')]/ancestor::rt#);
if (!$modelTextrt) {
	say "The model, '", $modeltag, "' isn't in any records";
	exit;
	}
# say  rtheader($modelTextrt) ;

my ($modelOwnerrt) = traverseuptoclass($modelTextrt, 'LexEntry');
say  'For the model entry, using:', displaylexentstring($modelOwnerrt);

my $modelentryref = $rthash{$modelOwnerrt->findvalue('./EntryRefs/objsur/@guid')};
my $modelEntryTypeName;
if ($modelentryref) {
	# Fetch the name of the ComplexEntryType that the model uses
	my $modelEntryTypert = $rthash{$modelentryref->findvalue('./ComplexEntryTypes/objsur/@guid')};
	$modelEntryTypeName =$modelEntryTypert->findvalue('./Name/AUni'); 
	say "It has a $modelEntryTypeName EntryType";
	}
else {
	die "The model entry doesn't refer to another entry\nQuitting";
}
my ($modelHideMinorEntryval) = $modelentryref->findvalue('./HideMinorEntry/@val');
my ($modelRefTypeval) = $modelentryref->findvalue('./RefType/@val');
my $modelComplexEntryTypesstring= ($modelentryref->findnodes('./ComplexEntryTypes'))[0]->toString;
my ($modelHasAPrimaryLexemes) = $modelentryref->findnodes('./PrimaryLexemes') ;
my ($modelHasAShowComplexFormsIn) = $modelentryref->findnodes('./ShowComplexFormsIn');
say ''; say '';
=pod
say 'Found the model stuff:';
say 'HideMinorEntry val:', $modelHideMinorEntryval;
say 'RefType val:', $modelRefTypeval;
say 'ComplexEntryTypes (string):', $modelComplexEntryTypesstring;
say 'Has a PrimaryLexemes' if $modelHasAPrimaryLexemes;
say 'Has a ShowComplexFormsIn' if $modelHasAShowComplexFormsIn;
say 'End of the model stuff:';
=cut

foreach my $seToModifyTextrt ($fwdatatree->findnodes(q#//*[contains(., '# . $modifytag . q#')]/ancestor::rt#)) {
	my ($seModifyOwnerrt) = traverseuptoclass($seToModifyTextrt, 'LexEntry'); 
	say  "Modifying Reference to a $modelEntryTypeName for:", displaylexentstring($seModifyOwnerrt) ;	
	my $entryreftomodify = $rthash{$seModifyOwnerrt->findvalue('./EntryRefs/objsur/@guid')};
	# say 'EntryRefToModify Before: ', $entryreftomodify;
	if (!$entryreftomodify->findnodes('./ComponentLexemes')) {
		say STDERR "No Component Lexemes for: ", displaylexentstring($seModifyOwnerrt);
		next;
		}
	# Attribute values are done in place
	(my $attr) = $entryreftomodify->findnodes('./HideMinorEntry/@val');
	$attr->setValue($modelHideMinorEntryval) if $attr; 
	($attr) = $entryreftomodify->findnodes('./RefType/@val');
	$attr->setValue($modelRefTypeval) if $attr; 
	
	# New nodes are built from strings and inserted in order
	my $newnode = XML::LibXML->load_xml(string => $modelComplexEntryTypesstring)->findnodes('//*')->[0];
	# the above expression makes a new tree from the model ComplexEntryTypestring
	$entryreftomodify->insertBefore($newnode, ($entryreftomodify->findnodes('./ComponentLexemes'))[0]);
	
	# Additional new nodes use the objsur@guid from the ComponentLexemes
	# Stringify the ComponentLexemes node, change the tags, nodify the changed string and put the new node in its place
	my ($CLstring) = ($entryreftomodify->findnodes('./ComponentLexemes'))[0]->toString;
	my $tempstring = $CLstring;
	if ($modelHasAPrimaryLexemes)  {
		$tempstring =~ s/ComponentLexemes/PrimaryLexemes/g;
		$newnode = XML::LibXML->load_xml(string => $tempstring)->findnodes('//*')->[0];
		$entryreftomodify->insertBefore($newnode, ($entryreftomodify->findnodes('./RefType'))[0]);
		}
	$tempstring = $CLstring;
	if ($modelHasAShowComplexFormsIn)  {
		$tempstring =~ s/ComponentLexemes/ShowComplexFormsIn/g;
		$newnode = XML::LibXML->load_xml(string => $tempstring)->findnodes('//*')->[0];
		$entryreftomodify->insertAfter($newnode, ($entryreftomodify->findnodes('./RefType'))[0]);
		}
	# remove the VariantEntryTypes (VET) node if it's there
	my ($VETnode) = $entryreftomodify->findnodes('./VariantEntryTypes') ;
		$VETnode->parentNode->removeChild($VETnode) if $VETnode ;
=pod
	say "";
	say "EntryRefToModify  After: ", $entryreftomodify ;
	say "";
	say "";
=cut
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

my $guid = $lexentrt->getAttribute('guid');
return qq#$formstring (guid="$guid")#;
}
