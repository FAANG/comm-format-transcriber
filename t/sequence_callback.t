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

use Test::More;
use Test::Differences;

use Bio::FormatTranscriber::Callback::Sequence;

my $callback = Bio::FormatTranscriber::Callback::Sequence->new();

ok($callback, "Callback object created");

my $param = 'ACTGACTGACTGACTGACTGNNNNNNNNNN';
my $truncated = 'ACTGACTGACTGACTGACTG';

is($callback->run($param), $truncated, 'Scalar parameter to callback');

my @params = [$param, 'second'];
is($callback->run(@params), $truncated, 'Array parameter to callback');

my $params = {sequence => $param,
	      second => 'otherparam'};
is($callback->run($params), $truncated, 'Hash parameter to callback');

$params = {first => 'param',
	      second => 'otherparam'};
is($callback->run($params), 'unknown_seq', 'Missing hash parameter to callback');

is($callback->run(), 'unknown_seq', 'Missing hash parameter to callback');

done_testing();
