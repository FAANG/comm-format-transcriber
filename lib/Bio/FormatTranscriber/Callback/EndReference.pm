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

Bio::FormatTranscriber::Callback::EndReference

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::EndReference;

  $callback_obj = Bio::FormatTranscriber::Callback::UnpadSequence->new();

  $callback_obj->run({record => $record});

=head1 DESCRIPTION

When filtering lines from a GFF3 file, numerous end forward reference (###) can
stack up on sequential lines. This filter can be placed in the output_filter to
clean these references.

Mapping entry should look like:

    "forward_ref" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::EndReference",
      "_parameters" : {"record" : "{{record}}", "last_written" : "{{last_written}}"},
      "_filter" : 1
    }

and usually should be called during the output_filter, ie.

  "output_filter": { "_metadata" : "forward_ref"
		  },

=cut

package Bio::FormatTranscriber::Callback::EndReference;

use strict;
use warnings;
use Carp;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
    my $class = shift;

    my $self = {};

    return bless $self, $class;
}

sub run {
    my $self = shift;
    my $params = shift;

    unless( exists($params->{last_written}) &&
	    exists($params->{record}) ) {
	throw("We're missing the LAST_WRITTEN or the RECORD for the filter call");
    }

    # A very simple filter, if we're written a foward reference delimeter (###) last, and we're
    # about to write another... don't.
    return !(ref($params->{last_written}) eq 'Bio::EnsEMBL::IO::Object::GFF3Metadata' &&
	     $params->{last_written}->{type} eq 'fwd-ref-delimeter' &&
	     ref($params->{record}) eq 'Bio::EnsEMBL::IO::Object::GFF3Metadata' &&
	     $params->{record}->{type} eq 'fwd-ref-delimeter');
}

1;
