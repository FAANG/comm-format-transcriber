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

Bio::FormatTranscriber::Callback::MaxLength

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::MaxLength;

  $callback_obj = Bio::FormatTranscriber::Callback::MaxLength->new({ length => 100000 });

  $less_than_max_bool = $callback_obj->run({record => $record});


=head1 DESCRIPTION

Filter a record based on if the length is greater than the
given maximum. Throws an error if the object type being filtered
doesn't support length()

Mapping entry could look like:


    "max_length" : {
      "_callback" : "run",
      "_module"   : "Bio::FormatTranscriber::Callback::MaxLength",
      "_init"     : { "length" : 100000 },
      "_parameters" : { "record" : "{{record}}" } 
    }

and be called during the _pre or _post field step of a filter, ie.

  "input_filter": { "_pre" : "max_length"
                  }

=cut

package Bio::FormatTranscriber::Callback::MaxLength;

use strict;
use warnings;
use Carp;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
    my $class = shift;
    my $params = shift;

    my $self = {};

    unless(defined $params->{length}) {
	throw "You must specify the maximum length, otherwise, what's the point?";
    }

    $self->{length} = $params->{length};
    
    return bless $self, $class;
}

sub run {
    my $self = shift;
    my $params = shift;

    # Die if we weren't configured to receive a record
    unless((ref $params eq 'HASH') &&
	   $params->{record}) {
	throw "No record found for sequence";
    }

    if($params->{record}->length() > $self->{length}) {
	return 0;
    }

    return 1;
}

1;
