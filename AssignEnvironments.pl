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
=cut

use File::Basename;
use Getopt::Long;
use Data::Dumper qw(Dumper);

my $scriptname = fileparse($0, qr/\.[^.]*/); # script name without the .pl
GetOptions (
	'inifile:s'   => \(my $inifilename = "$scriptname.ini"), # ini filename
	'section:s'   => \(my $inisection = "AssignEnvironments"), # section of ini file to use
	'list'       => \my $listonly, # list the environments and stop
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
	if ($rt->getAttribute('class') eq 'PhEnvironment') {
		$envhash{$guid} = $rt;
		}
	}
	
#say "envhash:", Dumper(%envhash) if $debug;
if ($listonly) {
	while ((my $envguid, my $envrt) = each (%envhash)) {
		say STDERR "guid:$envguid" if $debug;
		my $envtext = "";
		foreach ($envrt->findnodes('./StringRepresentation/Str/Run/text()')) {
			$envtext .= $_->toString;
			};
		say STDERR "envtext:$envtext" if $debug;
		}
	}
exit;

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
