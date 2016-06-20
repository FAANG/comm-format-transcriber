#!/bin/env perl

# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


=head1 NAME

insdc_ucsc_report.pl - build a structure of chromsome synonyms for UCSC's itendifiers

=head1 SYNOPSIS

insdc_ucsc_report.pl [options]

=head1 DESCRIPTION

This script is a partially working script for generating a report of species that have insdc
identifiers, have gca accessions and exist in the ucsc dataset. It doesn't have any use
beyond getting this rough reporting for deeper investigation of linkages.

=head1 OPTIONS

--dbhost     host name for database (gets put as host= in locator)

--dbport     For RDBs, what port to connect to (port= in locator)

--dbuser     For RDBs, what username to connect as (dbuser= in locator)

--dbpass     For RDBs, what password to use (dbpass= in locator)

--release    Ensembl release to search against, default is whichever your Ensembl libray uses

--help       Usage information

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use feature qw/say/;

use Data::Dumper;
use JSON;
use DBI;

use Bio::EnsEMBL::Registry;

my %ucsc_name_cache;
my %insdc_to_ucsc;
my %insdc_to_ensembl;
my %insdc;
my %ucsc;
my %has_gca;
my %has_chromosome;

# Lookup of Ensembl full name to UCSC database name
#
# Derived from https://genome.ucsc.edu/FAQ/FAQreleases.html#release1
#
my $ensembl2ucsc = {
    # Mammals
    # Human
    'homo_sapiens'             => 'hg38',
    # Alpaca
    'vicugna_pacos'            => 'vicPac2',
    #Armadillo
    'dasypus_novemcinctus'     => 'dasNov3',
    # Bushbaby
    'otolemur_garnettii'       => 'otoGar3',
    # Baboon
    'papio_anubis'             => 'papAnu2',
    # Cat
    'felis_catus'              => 'felCat5',
    # Chimp
    'pan_troglodytes'          => 'panTro4',
    # Cow
    'bos_taurus'               => 'bosTau8',
    # Dog
    'canis_familiaris'         => 'canFam3',
    # Dolphin
    'tursiops_truncatus'       => 'turTru2',
    # Elephant
    'loxodonta_africana'       => 'loxAfr3',
    # Ferret
    'mustela_putorius_furo'    => 'musFur1',
    # Gibbon
    'nomascus_leucogenys'      => 'nomLeu3',
    # Gorilla
    'gorilla_gorilla'          => 'gorGor3',
    # Guinea pig
    'cavia_porcellus'          => 'cavPor3',
    # Hedgehog
    'erinaceus_europaeus'      => 'eriEur2',
    # Horse
    'equus_caballus'           => 'equCab2',
    # Kangaroo rat
    'dipodomys_ordii'          => 'dipOrd1',
    # Marmoset
    'callithrix_jacchus'       => 'calJac3',
    # Megabat
    'pteropus_vampyrus'        => 'pteVam1',
    # Microbat
    'myotis_lucifugus'         => 'myoLuc2',
    # Mouse
    'mus_musculus'             => 'mm10',
    # Mouse lemur
    'microcebus_murinus'       => 'micMur1',
    # Opossum
    'monodelphis_domestica'    => 'monDom5',
    # Orangutan
    'pongo_abelii'             => 'ponAbe2',
    # Panda
    'ailuropoda_melanoleuca'   => 'ailMel1',
    # Pig
    'sus_scrofa'               => 'susScr3',
    # Pika
    'ochotona_princeps'        => 'ochPri3',
    # Platypus
    'ornithorhynchus_anatinus' => 'ornAna1',
    # Rabbit
    'oryctolagus_cuniculus'    => 'oryCun2',
    # Rat
    'rattus_norvegicus'        => 'rn6',
    # Rhesus
    'macaca_mulatta'           => 'rheMac3',
    # Rock hyrax
    'procavia_capensis'        => 'proCap1',
    # Sheep
    'ovis_aries'               => 'oviAri3',
    # Shrew
    'sorex_araneus'            => 'sorAra2',
    # Sloth
    'choloepus_hoffmanni'      => 'choHof1',
    # Squirrel
    'ictidomys_tridecemlineatus' => 'speTri2',
    # Tarsier
    'tarsius_syrichta'         => 'tarSyr2',
    # Tasmanian devil
    'sarcophilus_harrisii'     => 'sarHar1',
    # Tenrec
    'echinops_telfairi'        => 'echTel2',
    # Tree shrew
    'tupaia_belangeri'         => 'tupBel1',
    # Wallaby
    'macropus_eugenii'         => 'macEug2',
 
   # Vertebrates
    # Atlantic cod
    'gadus_morhua'             => 'gadMor1',
    # Chicken
    'gallus_gallus'            => 'galGal4',
    # Coelacanth
    'latimeria_chalumnae'      => 'latCha1',
    # Fugu
    'takifugu_rubripes'        => 'fr3',
    # Lamprey
    'petromyzon_marinus'       => 'petMar2',
    # green anole lizard
    'anolis_carolinensis'      => 'anoCar2',
    # Medaka
    'oryzias_latipes'          => 'oryLat2',
    # Nile tilapia
    'oreochromis_niloticus'    => 'oreNil2',
    # Stickleback
    'gasterosteus_aculeatus'   => 'gasAcu1',
    # Tetraodon
    'tetraodon_nigroviridis'   => 'tetNig2',
    # Turkey
    'meleagris_gallopavo'      => 'melGal1',
    # xenopus tropicalis
    'xenopus_tropicalis'       => 'xenTro3',
    # Zebra finch
    'taeniopygia_guttata'      => 'taeGut2',
    # Zebrafish
    'danio_rerio'              => 'danRer10',

    # Deuterostomes
    # C. intestinalis
    'ciona_intestinalis'       => 'ci2',
    # S. purpuratus
    'strongylocentrotus_purpuratus' => 'strPur2',

    # Insects
    # A. mellifera
    'apis_mellifera'           => 'apiMel2',
    # A. gambiae
    'anopheles_gambiae'        => 'anoGam1',
    # D. ananassae
    'drosophila_ananassae'     => 'droAna2',
    # D. erecta
    'drosophila_erecta'        => 'droEre1',
    # D. grimshawi
    'drosophila_grimshawi'     => 'droGri1',
    # D. melanogaster
    'drosophila_melanogaster'  => 'dm6',
    # D. mojavensis
    'drosophila_mojavensis'    => 'droMoj2',
    # drosophila persimilis
    'drosophila_persimilis'    => 'droPer1',
    # drosophila pseudoobscura
    'drosophila_pseudoobscura' => 'dp3',
    # drosophila sechellia
    'drosophila_sechellia'     => 'droSec1',
    # drosophila simulans
    'drosophila_simulans'      => 'droSim1',
    # drosophila virilis
    'drosophila_virilis'       => 'droVir2',
    # drosophila yakuba
    'drosophila_yakuba'        => 'droYak2',

    # Nematodes
    # caenorhabditis brenneri
    'caenorhabditis_brenneri'  => 'caePb2',
    # caenorhabditis briggsae
    'caenorhabditis_briggsae'  => 'cb3',
    # caenorhabditis elegans
    'caenorhabditis_elegans'   => 'ce10',
    # caenorhabditis japonica
    'caenorhabditis_japonica'  => 'caeJap1',
    # caenorhabditis remanei
    'caenorhabditis_remanei'   => 'caeRem3',
    # pristionchus pacificus
    'pristionchus_pacificus'   => 'priPac1',
 
   # Other
    # Yeast
    'saccharomyces_cerevisiae' => 'sacCer3',
};

sub get_options {
    my $db_host = 'mysql-ensembl-mirror.ebi.ac.uk';
#    my $db_host = 'useastdb.ensembl.org';
    my $db_user = 'anonymous';
    my $db_pass;
    my $db_port = 4240;
    my $release;
    my $help;
    my @species;
    my $group = 'core';

    GetOptions(
	"db_host|dbhost|host=s"           => \$db_host,
	"db_user|dbuser|user|username=s"  => \$db_user,
	"db_pass|dbpass|pass|password=s"  => \$db_pass,
	"db_port|dbport|port=s"           => \$db_port,
	"version|release=i"               => \$release,
	"species=s@"                      => \@species,
	"help"                            => \$help,
	);
    
    if ($help) {
	exec('perldoc', $0);
    }

    my %args = (
	-HOST => $db_host,
	-USER => $db_user,
	-PORT => $db_port
	);
    $args{-PASS} = $db_pass if $db_pass;
    $args{-DB_VERSION} = $release if $release;
    
    my $registry = 'Bio::EnsEMBL::Registry';
    
    $registry->load_registry_from_db(%args);
    
    # Get all the species available for core
    my @dbas;
    if(@species) {
	say "Working against a restricted species list";
	foreach my $s (@species) {
	    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($s, $group);
	    die "Cannot find a DBAdaptor for the species ${s}" unless $dba;
	    push(@dbas, $dba);
	}
    }
    else {
	say "Dumping chain file for all available species";
	@dbas = @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')};
    }
    
    return @dbas;
}

run();

sub run {
    my @dbas = get_options();
    foreach my $dbadaptor (@dbas) {
	fetch_meta($dbadaptor);
	fetch_INSDC($dbadaptor);
	fetch_UCSC($dbadaptor);
	run_on_dba($dbadaptor);
    }

    # Report what we've found
    report();

#exit;
    print Dumper \%ucsc_name_cache;
    my $json_str = to_json(%ucsc_name_cache, { pretty => 1 });
    print $json_str;
}

sub report {
    my @found_ucsc; my @missing_ucsc; my @nomap_ucsc;

    foreach my $species (sort keys %ucsc) {
	if($ucsc{$species} == 1) {
	    push @found_ucsc, $species;
	} elsif($ucsc{$species} == -1) {
	    push @missing_ucsc, $species;
	} elsif($ucsc{$species} == -2) {
	    push @nomap_ucsc, $species;
	}
    }

    print "UCSC Mappings:\n";
    print "Found mappings:\t" . join(', ', @found_ucsc) . "\n\n";
    print "Missing from UCSC:\t" . join(', ', @missing_ucsc) . "\n\n";
    print "No UCSC mapping:\t" . join(', ', @nomap_ucsc) . "\n\n";


    my @found_insdc; my @missing_insdc;
    foreach my $species (sort keys %insdc) {
	if($insdc{$species} == 1) {
	    push @found_insdc, $species;
	} else {
	    push @missing_insdc, $species;
	}
    }

    print "INSDC Mappings:\n";
    print "Found mappings:\t" . join(', ', @found_insdc) . "\n\n";
    print "Missing INSDC\t" . join(', ', @missing_insdc) . "\n\n";

    my @found_gca; my @missing_gca;
    foreach my $species (sort keys %has_gca) {
	if($has_gca{$species} == 1) {
	    push @found_gca, $species;
	} else {
	    push @missing_gca, $species;
	}
    }

    print "GCA Accessions:\n";
    print "Found Accession:\t" . join(', ', @found_gca) . "\n";
    print "Missing Accession:\t" . join(', ', @missing_gca) . "\n";

    my %missing_insdc_map = map{$_ => 1} @missing_insdc;
    my @has_gca_no_insdc = grep( $missing_insdc_map{$_}, @found_gca );
    print "\nHave GCA accession, missing INSDC: " . join(', ', @has_gca_no_insdc) . "\n\n" ;

    my @has_chromosome_and_no_insdc = grep( $has_chromosome{$_}, @has_gca_no_insdc );
    print "Has GCA accessing, no INSDC, yet has a chromosome: " . join(', ', @has_chromosome_and_no_insdc) . "\n\n";

}

sub run_on_dba {
    my ($dbadaptor) = @_;

    say "Examining " . $dbadaptor->species() . "\n";

    # Fetch all the chromosome slices
    my $slice_adaptor = $dbadaptor->get_SliceAdaptor();
    my $slices = $slice_adaptor->fetch_all('chromosome');
    
    while(my $slice = shift @{$slices}) {
	next if $ucsc_name_cache{$dbadaptor->species()}{$slice->seq_region_name};
	
	my $synonyms = $slice->get_all_synonyms('UCSC');
	if(@{$synonyms}) {
	    $ucsc_name_cache{$dbadaptor->species()}{$slice->seq_region_name} = $synonyms->[0]->name();
	}
    }
}

sub fetch_meta {
    my ($dbadaptor) = @_;

    my $meta_adaptor = $dbadaptor->get_MetaContainerAdaptor();

    my @accession_info =
	@{ $meta_adaptor->list_value_by_key('assembly.accession') };

    if(@accession_info) {
	$has_gca{$dbadaptor->species()} = 1;
    } else {
	$has_gca{$dbadaptor->species()} = 0;
    }
    
}

# Go fetch all mappings for INSDC to our chromosome identifier

sub fetch_INSDC {
    my ($dbadaptor) = @_;

    say "Examining " . $dbadaptor->species() . "\n";

    # Remember if we've found an insdc identifier in this database
    my $found_insdc = 0;

    # Fetch all the chromosome slices
    my $slice_adaptor = $dbadaptor->get_SliceAdaptor();
    my $slices = $slice_adaptor->fetch_all('chromosome');
#    my $slices = $slice_adaptor->fetch_all('toplevel');

    $has_chromosome{$dbadaptor->species()} = 0;

    while(my $slice = shift @{$slices}) {
	$has_chromosome{$dbadaptor->species()} = 1;
	print $slice->seq_region_name . "\t" .  $slice->coord_system_name() .  "\n";

	my $synonyms = $slice->get_all_synonyms('INSDC');

	if(@{$synonyms}) {
	    # We have at least one INSDC synonym for this species
	    $found_insdc = 1;

	    # We only care about chromosomes for mapping purposes
	    if($slice->coord_system_name() eq 'chromosome') {
		# Based on older scripts we're going to assume it'll be
		# the first (and only) synonym
		$insdc_to_ensembl{$dbadaptor->species()}{$synonyms->[0]->name()} = $slice->seq_region_name;
	    }
	}
#	print Dumper $synonyms;

    }

    say "Species " . $dbadaptor->species() . " found INSDC: " . $found_insdc . "\n";
    print Dumper $insdc_to_ensembl{$dbadaptor->species()};
    $insdc{$dbadaptor->species()} = $found_insdc;
    print "Has GCA: " . $has_gca{$dbadaptor->species()} . "\n";
}

# Go ask UCSC for all their mappings for INSDC to their chromosome name

sub fetch_UCSC {
    my ($dbadaptor) = @_;

    print "Examining " . $dbadaptor->species();

    my $db_name = $ensembl2ucsc->{$dbadaptor->species()};

    unless($db_name) {
	print "\n";
	say "Error, no UCSC database for ". $dbadaptor->species() . " known\n";
	$ucsc{$dbadaptor->species()} = -1;
	return;
    }

    print " ($db_name)\n";

    my $dbh; my $fetch_chromosomes;
    eval {
	$dbh = DBI->connect("dbi:mysql:$db_name:genome-mysql.cse.ucsc.edu:3306:max_allowed_packet=1MB", 'genome', '', undef);

	$fetch_chromosomes = $dbh->prepare(qq[SELECT chrom, name FROM ucscToINSDC]);

	$fetch_chromosomes->execute() || die "Error with execute: $DBI::errstr\n";

    };
	if($@) {
	    say "Error fetching chromosomes for species " . $dbadaptor->species() . ": $@\n";
	    $ucsc{$dbadaptor->species()} = -2;
	    return;
	}

    while( my @row = $fetch_chromosomes->fetchrow_array() ) {
	# Remember the mapping for later
	$insdc_to_ucsc{$dbadaptor->species()}{$row[1]} = $row[0];
    }

    print Dumper $insdc_to_ucsc{$dbadaptor->species()};
    $ucsc{$dbadaptor->species()} = 1;
}

