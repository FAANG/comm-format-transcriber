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

build_chromosome_synonyms.pl - build a structure of chromsome synonyms for UCSC's itendifiers

=head1 SYNOPSIS

build_chromosome_synonyms.pl -options

=head1 DESCRIPTION

This script will build a json structure of all the chromosome name mappings from
Ensembl names to UCSC names. The json structure will be printed on stdout, while
statistics on the run will be printed to stderr.

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
my $ensembl2ucsc;

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
	print STDERR "Working against a restricted species list";
	foreach my $s (@species) {
	    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($s, $group);
	    die "Cannot find a DBAdaptor for the species ${s}" unless $dba;
	    push(@dbas, $dba);
	}
    }
    else {
	print STDERR "Dumping chain file for all available species";
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
    }

    # Report what we've found and get a list of
    # species that have both an Ensembl INSDC
    # and a UCSC mapping
    my @species = merge_and_report();

    # Go through the species we know have both an Ensembl INSDC 
    # and a UCSC mapping
    foreach my $species (@species) {
	foreach my $insdc (keys %{$insdc_to_ensembl{$species}}) {
	    if($insdc_to_ucsc{$species}{$insdc}) {
		
		$ucsc_name_cache{$species}{ $insdc_to_ensembl{$species}{$insdc} } = $insdc_to_ucsc{$species}{$insdc};
	    }
	}
    }

    # Make the json for the structure and spit it out
    my $json_str = to_json(\%ucsc_name_cache, { pretty => 1 });
    print $json_str;
}

# Merge the sets of identifiers and return all the species
# that have both an Ensembl INSDC and a UCSC mapping,
# also report back on some general stats.

sub merge_and_report {
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

    print STDERR "UCSC Mappings:\n";
    print STDERR "Found mappings:\t" . join(', ', @found_ucsc) . "\n\n";
    print STDERR "Missing from UCSC:\t" . join(', ', @missing_ucsc) . "\n\n";
    print STDERR "No UCSC mapping:\t" . join(', ', @nomap_ucsc) . "\n\n";


    my @found_insdc; my @missing_insdc;
    foreach my $species (sort keys %insdc) {
	if($insdc{$species} == 1) {
	    push @found_insdc, $species;
	} else {
	    push @missing_insdc, $species;
	}
    }

    print STDERR "INSDC Mappings:\n";
    print STDERR "Found mappings:\t" . join(', ', @found_insdc) . "\n\n";
    print STDERR "Missing INSDC\t" . join(', ', @missing_insdc) . "\n\n";

    my @found_gca; my @missing_gca;
    foreach my $species (sort keys %has_gca) {
	if($has_gca{$species} == 1) {
	    push @found_gca, $species;
	} else {
	    push @missing_gca, $species;
	}
    }

    print STDERR "GCA Accessions:\n";
    print STDERR "Found Accession:\t" . join(', ', @found_gca) . "\n";
    print STDERR "Missing Accession:\t" . join(', ', @missing_gca) . "\n";

    my %missing_insdc_map = map{$_ => 1} @missing_insdc;
    my @has_gca_no_insdc = grep( $missing_insdc_map{$_}, @found_gca );
    print STDERR "\nHave GCA accession, missing INSDC: " . join(', ', @has_gca_no_insdc) . "\n\n" ;

    my @has_chromosome_and_no_insdc = grep( $has_chromosome{$_}, @has_gca_no_insdc );
    print STDERR "Has GCA accessing, no INSDC, yet has a chromosome: " . join(', ', @has_chromosome_and_no_insdc) . "\n\n";

    my %has_insdc_map = map{$_ => 1} @found_insdc;
    my @has_insdc_and_ucsc = grep( $has_insdc_map{$_}, @found_ucsc );
    print STDERR "Has Ensembl INSDC and UCSC: " . join(', ', @has_insdc_and_ucsc) . "\n\n";

    return @has_insdc_and_ucsc;
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
    
    my @ucsc_mapping = 
	@{ $meta_adaptor->list_value_by_key('assembly.ucsc_alias') };

    # Grab the UCSC db name if available
    if(@ucsc_mapping) {
	$ensembl2ucsc->{ $dbadaptor->species() } = 
	    shift @ucsc_mapping;
    }

}

# Go fetch all mappings for INSDC to our chromosome identifier

sub fetch_INSDC {
    my ($dbadaptor) = @_;

    print STDERR "Examining " . $dbadaptor->species() . "\n";

    # Remember if we've found an insdc identifier in this database
    my $found_insdc = 0;

    # Fetch all the chromosome slices
    my $slice_adaptor = $dbadaptor->get_SliceAdaptor();
    my $slices = $slice_adaptor->fetch_all('chromosome');

    $has_chromosome{$dbadaptor->species()} = 0;

    while(my $slice = shift @{$slices}) {
	$has_chromosome{$dbadaptor->species()} = 1;

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

    }

    $insdc{$dbadaptor->species()} = $found_insdc;
}

# Go ask UCSC for all their mappings for INSDC to their chromosome name

sub fetch_UCSC {
    my ($dbadaptor) = @_;

    print STDERR "Examining " . $dbadaptor->species();

    my $db_name = $ensembl2ucsc->{$dbadaptor->species()};

    unless($db_name) {
	print STDERR "\n";
	print STDERR "Error, no UCSC database for ". $dbadaptor->species() . " known\n";
	$ucsc{$dbadaptor->species()} = -1;
	return;
    }

    print STDERR " ($db_name)\n";

    my $dbh; my $fetch_chromosomes;
    eval {
	$dbh = DBI->connect("dbi:mysql:$db_name:genome-mysql.cse.ucsc.edu:3306:max_allowed_packet=1MB", 'genome', '', undef);

	$fetch_chromosomes = $dbh->prepare(qq[SELECT chrom, name FROM ucscToINSDC]);

	$fetch_chromosomes->execute() || die "Error with execute: $DBI::errstr\n";

    };
	if($@) {
	    print STDERR "Error fetching chromosomes for species " . $dbadaptor->species() . ": $@\n";
	    $ucsc{$dbadaptor->species()} = -2;
	    return;
	}

    while( my @row = $fetch_chromosomes->fetchrow_array() ) {
	# Remember the mapping for later
	$insdc_to_ucsc{$dbadaptor->species()}{$row[1]} = $row[0];
    }

    $ucsc{$dbadaptor->species()} = 1;
}

