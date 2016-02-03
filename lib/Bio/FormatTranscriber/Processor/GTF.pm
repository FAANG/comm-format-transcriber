=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.
  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::FormatTranscriber::Processor::GTF

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Processor::GTF;

  my $processor = Bio::FormatTranscriber::Processor::GTF->new(config => $config_reference);

  $processor->fields(@allowed_columns);

  $processor->process_record($record);

  $processor->process_metadata($record);

=head1 DESCRIPTION

Process records of type GTF.  On creation the configuration of mappings should be
passed in, this is a multi-dimensional hash containing the column mappings and the
rules to apply these mappings.

The object must be given a list of fields to process from a record, where a record
is a reference to a hash containing the fields for the record.

When streaming through the file to be processed, records should be passed to the
processor_record one by one, and metadata should be passed to process_metadata. 
Records should be passed as references as the mutation on the records is destructive!

An exception is thrown if the configuration doesn't map properly to the columns
requested.

=cut

package Bio::FormatTranscriber::Processor::GTF;

use strict;
use warnings;

use base qw/Bio::FormatTranscriber::Processor::FieldBased/;

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);

    return $self;
}


1;
