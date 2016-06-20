#!/usr/bin/env perl

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

build_chromosome_config.pl - Take the Ensembl-UCSC mapping JSON and builds the base chromosome config

=head1 SYNOPSIS

build_chromosome_config.pl -options

=head1 DESCRIPTION

This script will take the JSON block produced by build_chromosome_synonyms.pl build a format-transcriber compatible json block of the base chromosome mapping configs.

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

use Bio::EnsEMBL::Utils::IO qw/slurp/;

use JSON;

my $input_file;
my $output_file;
my $output_struct;

get_options();

my $raw_json = slurp($input_file);

my $json = from_json($raw_json);

foreach my $species (keys %{$json}) {
    my $forward_key = "ensembl_to_ucsc";
    my $reverse_key = "ucsc_to_ensembl";

    for my $chr (keys %{$json->{$species}}) {
	$output_struct->{mapping}->{chromosome}->{$species}->{$forward_key}->{$chr} = $json->{$species}->{$chr};
	$output_struct->{mapping}->{chromosome}->{species}->{$reverse_key}->{$json->{$species}->{$chr}} = $chr;
    }
}

my $output_json = to_json($output_struct, { pretty => 1 });

open(OUT, ">$output_file") or
    die "Error opening output file $output_file: $!";

print OUT $output_json . "\n";

close OUT;

sub get_options {
    my $help;

    GetOptions(
	"input=s"                => \$input_file,
	"output=s"               => \$output_file,
	"help"                   => \$help,
	);
    
    if ($help) {
	exec('perldoc', $0);
    }

}

