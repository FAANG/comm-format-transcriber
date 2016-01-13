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

BEGIN {
  use FindBin qw/$Bin/;
  use lib "$Bin/../lib";
  sub binpath { return $Bin; }
}

use Test::More;
use Test::Differences;

use Bio::FormatTranscriber::Parser::GFF3;

my $parser; my $metadata_lines = 0;
ok($parser = Bio::FormatTranscriber::Parser::GFF3->open(binpath . '/data/data_with_fasta.gff3'), 'Making GFF3 parser');

my $callback = sub { my $line = shift; $metadata_lines += 1; };

is($parser->set_metadata_callback([]), 0, "Setting a bad metadata callback");
is($parser->clear_metadata_callback(), 0, "Clear unset metadata callback");
ok($parser->set_metadata_callback($callback), 'Setting read_metadata callback');
is($parser->clear_metadata_callback(), 1, "Clear metadata callback");
ok($parser->set_metadata_callback($callback), 'Re-setting read_metadata callback');
ok($parser->next(), 'Reading a record from the GFF3 file');
is($metadata_lines, 7, 'Ensure we found 7 lines of metadata');
is($parser->get_seqname, 'NC_000001.11', 'Testing get_seqname');
is($parser->get_source, '1', 'Testing get_source');
ok($parser->next(), 'Reading next record from the GFF3 file');
ok($parser->next(), 'Reading last record from the GFF3 file');
ok(!$parser->next(), "Should return empty, end of records");
ok($parser->in_fasta_mode(), "We should be in Fasta mode");
ok($parser->next_sequence(), "Read the first Fasta sequence");
is($parser->getHeader(), 'HSBGPG Human gene for bone gla protein (BGP)', "Checking fasta header");
is(length($parser->getSequence()), 1231, "Checking the sequence is the correct length");
ok($parser->next_sequence(), "Test jumping to the next record, don't read the sequence");
ok(!$parser->next_sequence(), "Should return empty, end of sequences");

done_testing();
