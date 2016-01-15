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

stream_file - Driver for Bio::FormatTranscriber::FileHandle library, mainly for testing

=head1 SYNOPSIS

stream_file.pl [-i <input_file>] [-o <output_file>]

=head1 DESCRIPTION

Streams a given input file, which can be remotely on an http werver and/or gziped. Spits the file
to STDOUT or a given output file.

=cut

# Don't buffer the output, stream immediately on write
$|++;

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

use Bio::FormatTranscriber::FileHandle;

my $input_file;
my $output_file;

get_options();

# If we aren't given input and/or output file, use STDIN/OUT
my $in_fh;
if($input_file) {
    $in_fh = Bio::FormatTranscriber::FileHandle->open($input_file);
} else {
    $in_fh = *STDIN;
}

my $out_fh;
if($output_file) {
    open $out_fh, ">", $output_file or
        die "Error opening output file $output_file: $!";
} else {
    $out_fh = *STDOUT;
}

while(<$in_fh>) {
  print $out_fh $_;
}

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
