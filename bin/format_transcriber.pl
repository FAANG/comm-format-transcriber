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

format_transcriber - Run a set of filters on a given input file

=head1 SYNOPSIS

format_transcriber.pl [-i <input_file>] [-o <output_file>] -c <config> -format <format> [-filter <filters>]

=head1 DESCRIPTION

For a given input file in a given format, and configuration, execute the set of rules on the input
file and write them back out to output file. If no input and/or output file are specified, use
STDIN and STDOUT to read and write files to be transcribed.

A configuration file is a JSON chunk which may include other JSON chucks to be merged.

Optionally a list of filters can be given to only evaluate a subset of the filters.

=cut

# Don't buffer the output, stream immediately on write
$|++;

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

use Bio::FormatTranscriber;
use Bio::FormatTranscriber::FileHandle;

my $input_file;
my $output_file;
my $config_file;
my $output_format;
my $format;
my @filters;

get_options();

# Allow both multiple options and comma seaprated lists
@filters = split(/,/,join(',',@filters));

# If we aren't given input and/or output file, use STDIN/OUT
my $in_fh;
if($input_file) {
#$in_fh = $input_file;
    $in_fh = Bio::FormatTranscriber::FileHandle->open($input_file);
} else {
    $in_fh = *STDIN;
}

$output_file = *STDOUT
    unless($output_file);

my $ft = Bio::FormatTranscriber->new( -config => $config_file, -format => $format, -filters => \@filters, -out_format => ($output_format ? $output_format : $format) );

$ft->transcribe_file($in_fh, $output_file);

sub get_options {
    my $help;

    GetOptions(
	"input=s"                => \$input_file,
	"output=s"               => \$output_file,
	"config=s"               => \$config_file,
	"format=s"               => \$format,
        "write_format=s"         => \$output_format,
	"filters=s"              => \@filters,
	"help"                   => \$help,
	);
    
    if ($help) {
	exec('perldoc', $0);
    }

}
