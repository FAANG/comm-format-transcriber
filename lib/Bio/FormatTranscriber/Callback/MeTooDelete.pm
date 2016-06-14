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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.
  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::FormatTranscriber::Callback::MeTooDelete

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::MeTooDelete;

  $callback_obj = Bio::FormatTranscriber::Callback::MeTooDelete->new();

  $write_rec_bool = $callback_obj->run({record => $record, last_written => $last_record});

=head1 DESCRIPTION

Specifically for GTF/GFF3 files, for each record if the previous record has
been deleted, delete the current record as well. Do this until an end of
reference (###) metadata record is found.

This is meant to be used in cojunction with filters such as the MaxLength and EndReference
filters.

Mapping entry should look like:

    "metoo_delete" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::MeTooDelete",
      "_parameters" : {"record" : "{{record}}", "last_record" : "{{last_record}}"},
      "_filter" : 1
    }

and usually should be called during the output_filter, ie.

  "processor": { "_post" : "metoo_delete"
		  },

=cut

package Bio::FormatTranscriber::Callback::MeTooDelete;

use strict;
use warnings;
use Carp;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base qw/Bio::FormatTranscriber::Callback/;

sub run {
    my $self = shift;
    my $params = shift;

    unless( exists($params->{last_record}) &&
	    exists($params->{record}) ) {
	throw("We're missing the LAST_RECORD or the RECORD for the filter call");
    }

    # A very simple filter, if both the last record is not a metadata type AND
    # the last record is set to be deleted, return false (delete record), otherwise
    # return true (don't delete record)
    return !(ref($params->{last_record}) ne 'Bio::EnsEMBL::IO::Object::GFF3Metadata' &&
	    $params->{last_record}->{delete});
	    
}

1;
