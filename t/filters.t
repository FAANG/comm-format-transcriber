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
use Test::Exception;

use Bio::FormatTranscriber::Processor;

my $config = { "input_filter" => { 'location' => 'chromosome|invalid_human_map', 'name' => 'empty_map', 'attribute' => 'callback', 'seq' => 'callback2' },
	       'mapping' => {
		   'chromosome' => { 'human_map' => { 'X' => 'chrX',
						      'Y' => 'chrY' }
		   },
		   'empty_map' => '',
		   'callback' => {
		       "_callback" => "run",
		       "_module" => "Bio::FormatTranscriber::Invalid",
		       "_init" => ["{{Field}}", "{{Format}}"],
		       "_parameters" => {"field" => "{{FIELD}}", "value" => "{{Value}}", "filter" => "{{FiLTeR}}"}
		   },
		   'callback2' => {
		       "_callback" => "fake_method",
		       "_module" => "Bio::FormatTranscriber::Callback",
		       "_init" => ["{{Field}}", "{{Format}}"],
		       "_parameters" => {"field" => "{{FIELD}}", "value" => "{{Value}}", "filter" => "{{FiLTeR}}"}
		   }
	       }
};

my $processor = Bio::FormatTranscriber::Processor->new(-config => $config);

ok($processor, 'Make processor object');

dies_ok { $processor->validate_filters(); } "Fail in call to validate invalid filter";

done_testing();
