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
use Test::Exception;

use Bio::FormatTranscriber::Processor;

my $config = { "input_filter" => { 'source' => 'callback', 'location' => 'chromosome|human_map' },
	       'mapping' => {
		   'callback' => {
		       "_callback" => "run",
		       "_module" => "Bio::FormatTranscriber::Callback::Echo",
		       "_init" => ["{{Field}}", "{{Format}}"],
		       "_parameters" => {"field" => "{{FIELD}}", "value" => "{{Value}}", "filter" => "{{FiLTeR}}"}
		   },
		   'chromosome' => { 'human_map' => { 'X' => 'chrX',
						      'Y' => 'chrY' }
		   },
		   'scalarvalue' => 'mysubstitution'
	       }
};

my @array_params = [qw/{{Field}} {{format}}/];

# Test values for substitution
my $values = {'FIELD'  => 'source',
	      'FILTER' => 'input_filter',
	      'FORMAT' => 'GFF3' };

dies_ok { Bio::FormatTranscriber::Processor->new() } "Dies without a configuration";

my $processor = Bio::FormatTranscriber::Processor->new(-config => $config);

ok($processor, 'Make processor object');

dies_ok { $processor->process_record() } "Fail in call to process_record of parent class";
dies_ok { $processor->process_metadata() } "Fail in call to process_metadata of parent class";

ok($processor->init_callback($config->{mapping}->{callback}, 'default', 'callback'), "Initialize a callback module");
dies_ok { $processor->load_module( {_module => 'Non::Existent::Module' }) } "Dies loading an invalid module";

is_deeply($processor->eval_parameters(@array_params, $values), ['source', 'GFF3'], 'Testing parameter evaluation for array');

is_deeply($processor->eval_parameters($config->{mapping}->{callback}->{_parameters}, $values), 
	  {"field" => "source", "value" => "{{Value}}", "filter" => "input_filter"},
	  "Testing parameter evaluation for hash");

is($processor->eval_parameters('{{FORmat}}', $values), 'GFF3', 'Testing parameter evaluation for scalar');

is_deeply($processor->eval_parameters({ 'chromosome' => '[[scalarvalue]]'}, $values), { 'chromosome' => 'mysubstitution' }, 'Substitution from config entry');

is($processor->validate_filters('input_filter'), 0, "Validating one filter");
is_deeply($processor->filters, [qw/input_filter processing output_filter/], "Verify filters");
is($processor->validate_filters(), 0, "Validating all filters");

done_testing();
