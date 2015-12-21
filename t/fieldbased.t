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

use Bio::FormatTranscriber::Processor::FieldBased;

my $config = { "input_filter" => { 'source' => 'callback', 'location' => 'chromosome|human_map' },
	       'mapping' => {
		   'callback' => {
		       "_callback" => "run",
		       "_module" => "Bio::FormatTranscriber::Callback",
		       "_init" => ["{{Field}}", "{{Format}}"],
		       "_parameters" => {"field" => "{{FIELD}}", "value" => "{{Value}}", "filter" => "{{FiLTeR}}"}
		   },
		   'chromosome' => { 'human_map' => { 'X' => 'chrX',
						      'Y' => 'chrY' }
		   }
	       }
};

my $fields = [qw/source location seqname attributes/];

# Munge a little to make a temporary object rather than depend on
# an external package such as ensembl-io
my $record = {source => 'Ensembl', 'location' => 'X', 'seqname' => 'hypothetical_protein'};
$record = bless $record, 'Object';
*Object::fields = sub {return $fields};

my $processor = Bio::FormatTranscriber::Processor::FieldBased->new(-config => $config);

ok($processor, 'Make processor object');

is_deeply($processor->process_record($record), 
	  {source => '__Ensembl__', 'location' => 'chrX', 'seqname' => 'hypothetical_protein'},
	  "Processing a record");

done_testing();
