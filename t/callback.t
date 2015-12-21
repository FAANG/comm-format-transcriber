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

use strict;
use warnings;

use Test::More;
use Test::Differences;

use Bio::FormatTranscriber::Callback;

my $callback = Bio::FormatTranscriber::Callback->new();

ok($callback, "Callback object created");

is($callback->run('param'), '__param__', 'Scalar parameter to callback');

my @params = [qw/param second/];
is($callback->run(@params), '__param__', 'Array parameter to callback');

my $params = {value => 'param',
	      second => 'otherparam'};
is($callback->run($params), '__param__', 'Hash parameter to callback');

$params = {first => 'param',
	      second => 'otherparam'};
is($callback->run($params), '__unknown__', 'Missing hash parameter to callback');

is($callback->run(), '__unknown__', 'Missing hash parameter to callback');

done_testing();
