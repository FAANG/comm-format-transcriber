=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::FormatTranscriber::Callback::UnpadSequence

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::UnpadSequence;

  $callback_obj = Bio::FormatTranscriber::Callback::UnpadSequence->new();

  $callback_obj->run({record => $record});

=head1 DESCRIPTION

Callback to trim leading and trailing N's from a sequence object, must be
a Fasta type or provide similar interfaces (sequence and display_id fetcher/setter)

Header is expected to be in EBI standard format, ie.
>1 dna:chromosome chromosome:GRCh38:1:1:248956422:1 REF

Mapping entry should look like:

    "UnpadSequence" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::UnpadSequence",
      "_parameters" : {"record" : "{{record}}"}
    }

and be called during the _pre or _post field step of a filter, ie.

  "input_filter": { "_pre" : "UnpadSequence"
		  },

=cut

package Bio::FormatTranscriber::Callback::UnpadSequence;

use strict;
use warnings;
use Carp;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::IO::Object::Fasta;

sub new {
    my $class = shift;

    my $self = {};

    return bless $self, $class;
}

sub run {
    my $self = shift;
    my $params = shift;

    unless((ref $params eq 'HASH') &&
	   $params->{record}) {
	throw "No record found for sequence";
    }

    my $seq = $params->{record}->sequence;

    my $start_offset = 0; my $end_offset = 0;
    my $modified = 0;

    # Find the trailing N's, if they exist
    if($seq =~ /[Nn]+$/p) {
	# Remove the trailing N's
	$seq = substr($seq, 0, $-[0]);
	# Get the adjustment to the offset, we want a
	# negative number since we'll be just adding it to
	# the existing end
	$end_offset = $-[0] - $+[0];

	$modified = 1;
    }

    # Find the leading N's, if they exist
    if($seq =~ /^[Nn]+/p) {
	# Remove the leading N's
	$seq = substr($seq, $+[0]);
	# Get the adjustment to the offset
	$start_offset = $+[0] - $-[0];

	$modified = 1;
    }

    # Only write back the sequence if it's been changed
    if($modified) {
	$params->{record}->seq($seq);
	$self->coord_offset($params->{record}, $start_offset, $end_offset);
    }

}

sub coord_offset {
    my $self = shift;
    my $record = shift;
    my $start_offset = shift;
    my $end_offset = shift;

    my $header = $record->display_id;

    # Split the header pieces apart
    my ($id, $type, $location, @remainder) = split ' ', $header;
    my ($obj, $assembly, $chr, $start, $end, @loc_remainder) = split ':', $location;

    # Apply the offsets
    $start += $start_offset;
    $end += $end_offset;

    # And reassemble the pieces
    $location = join ':', $obj, $assembly, $chr, $start, $end, @loc_remainder;
    $header = join ' ', $id, $type, $location, @remainder;

    $record->display_id($header);
}

1;
