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

use strict;
use warnings;
use JSON;
use Bio::EnsEMBL::Utils::IO qw/slurp/;

BEGIN {
  use FindBin qw/$Bin/;
  use lib "$Bin/../lib";
  sub binpath { return $Bin; }

  # We need to set our relative working directory
  # to where the test script lives since the sample
  # configs live under this path
  chdir($Bin);
}

use Test::More;
use Test::Differences;
use Test::Deep;

use Bio::FormatTranscriber::Config qw/parse_config/;

my $config;
ok($config = parse_config('file://testConfigs/morerecursive.conf'), 'Parsing recursive config file');

my $expected = from_json(slurp(binpath . "/testConfigs/morerecursive_full.conf"));

cmp_deeply($config, $expected, 'Testing if recursive config matches expected');

done_testing();
