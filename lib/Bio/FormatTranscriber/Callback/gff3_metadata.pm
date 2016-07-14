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

Bio::FormatTranscriber::Callback::gff3_metadata

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::gff3_metadata

  $callback_obj = Bio::FormatTranscriber::Callback::gff3_metadata->new({directive => "sequence-region",
                                                                       slot_0 => { hash of substitutions },
                                                                       slot_3 => { hash of substitutions },
                                                                      );

  $updated_record = $callback_obj->run({record => $record});

=head1 DESCRIPTION

Similar to the basic hash substitution filter, but designed for GFF3 metadata
records. Metadata records are passed as Bio::EnsEMBL::IO::Object::GFF3Metadata
objects, including that type of metadata field their are, a directive (if applicable),
and the values of the metadata separated in to an array based on split '\s+'

The callback takes a list of "slots" to attempt to lookup and substitute in
a given lookup table. By "slot" we mean the array subscript, the first element
in the array is slot_0, the second is slot_1, etc.

So for a metadata record like:

##sequence-region   13 1 114364328

If you wanted to lookup and substitute the chromosome field you'd use slot_0
on a directive of type "sequence-region"

Mapping entry could look like:

    "gff3_metadata" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::gff3_metadata",
      "_init" : { "directive": "sequence-region",
                  "slot_0" : "[[chromosome|homo_sapiens|ensembl_to_ucsc]]",
                  "slot_1" : "[[assembly]]" },
      "_parameters" : { "record" : "{{record}}" } 
    },
    "assembly" : { "GRCh38" : "New_Chromosome_Name" }

and be called during the _pre or _post field step of a filter, ie.

  "input_filter": { "_metadata" : "gff3_metadata" 
		  },

=cut

package Bio::FormatTranscriber::Callback::gff3_metadata;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base qw/Bio::FormatTranscriber::Callback/;

sub new {
    my $class = shift;
    my $params = shift;
    my $self;

    unless($params->{directive}) {
	throw("No directive type given for gff3 metadata");
    }
    $self->{directive} = $params->{directive};

    # Try to find substitution parameters which should match
    # the capture groups () in the regex
    $self->{parameters} = {};
    for(my $i=0; $i <= 9; $i++) {
	my $param_str = "slot_$i";
	if($params->{$param_str}) {
	    $self->{parameters}->{$i} = $params->{$param_str};
	}
    }

    return bless $self, $class;
}

# Run routine for module, for each metadata elements found,
# check all the slots in the values array we've been asked to
# inspect, and see if that value exists in the corresponding
# lookup table.

sub run {
    my $self = shift;
    my $params = shift;

    # Die if we weren't configured to receive a record
    unless((ref $params eq 'HASH') &&
	   $params->{record} && 
	   (ref $params->{record} eq 'Bio::EnsEMBL::IO::Object::GFF3Metadata')) {
	throw "No record found for metadata, did you configure the filter correctly?";
    }

    # Extract the fasta header
    my $record = $params->{record};

    # If the directive type of the metadata doesn't match
    unless(defined($record->{directive}) &&
	   $record->{directive} eq $self->{directive}) {
	return;
    }

    # For each of the slots in the metadata header we've been given,
    # try and run the substitution on it.
    # Check the lookup table in the slot parameter we were given at init to see
    # if the corresponding array element in the metadata values exists. If so,
    # substitute it in to the record (just like the basic lookup hash type filter).
    foreach my $slot ( keys %{$self->{parameters}} ) {
	if( $self->{parameters}->{$slot}->{ $record->{value}->[$slot] } ) {
	    $record->{value}->[$slot] = $self->{parameters}->{$slot}->{ $record->{value}->[$slot] };
	}
    }

}

1;
