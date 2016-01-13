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

merge_config - Load and merge a config and all of it's includes

=head1 SYNOPSIS

merge_config.pl -options

=head1 DESCRIPTION

Takes a configuration file via one of the supported methods (file, http, ftp),
merges the included pieces in to a unified configuration. Then prints out
the merged configuration.

Useful for testing composite configurations to ensure includes are in the
appropriate order.

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

use Bio::FormatTranscriber::Config qw/parse_config dump_config/;

my $config_file;

get_options();

my $config = parse_config($config_file);

my $json_str = dump_config($config);

print $json_str;

sub get_options {
    my $help;

    GetOptions(
	"config=s"               => \$config_file,
	"help"                   => \$help,
	);
    
    if ($help) {
	exec('perldoc', $0);
    }

}
