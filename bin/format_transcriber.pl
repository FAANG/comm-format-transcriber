#!/usr/bin/env perl

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

format_transcriber - Run a set of filters on a given input file

=head1 SYNOPSIS

format_transcriber.pl -i <input_file> -o <output_file> -c <config> -format <format> [-filter <filters>]

=head1 DESCRIPTION

For a given input file in a given format, and configuration, execute the set of rules on the input
file and write them back out to output file.

A configuration file is a JSON chunk which may include other JSON chucks to be merged.

Optionally a list of filters can be given to only evaluate a subset of the filters.

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

use Bio::FormatTranscriber;

my $input_file;
my $output_file;
my $config_file;
my $format;
my @filters;

get_options();

# Allow both multiple options and comma seaprated lists
@filters = split(/,/,join(',',@filters));

my $ft = Bio::FormatTranscriber->new(-config => $config_file, -format => $format, -filters => \@filters);

$ft->transcribe_file($input_file, $output_file);

sub get_options {
    my $help;

    GetOptions(
	"input=s"                => \$input_file,
	"output=s"               => \$output_file,
	"config=s"               => \$config_file,
	"format=s"               => \$format,
	"filters=s"              => \@filters,
	"help"                   => \$help,
	);
    
    if ($help) {
	exec('perldoc', $0);
    }

}
