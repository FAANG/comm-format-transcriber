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

Bio::FormatTranscriber::Callback::Remap

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::Remap;

  $callback_obj = Bio::FormatTranscriber::Callback::Remap->new();

  $callback_obj->run({record => $record});

=head1 DESCRIPTION

Remaps features in a given sequence_region from coordinates based on
the reference genome to based on the sequence_region itself, ie.

##sequence-region CHR_HG1651_PATCH 61123605 61444354

with feature

CHR_HG126_PATCH ensembl gene    72374621        72447493 ...

becomes

CHR_HG126_PATCH ensembl gene    49181   122053 ...

The filter takes a series of regexes for the regions to remap.

Mapping entry should look like:

    "remap" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::Remap",
      "_init" : { "locations" : "[[patches]]" },
      "_parameters" : { "record" : "{{record}}" } 
    },
    "patches": [ ".*_PATCH$", "^X$" ]

and must be called both during the metadata phase to capture the
offsets of the regions and during the either the _pre or _post step of
a subsequent filter, ie.

  "input_filter" : { "_metadata" : "remap" },
  "processing" : { "_pre" : "remap" }

=cut

package Bio::FormatTranscriber::Callback::Remap;

use strict;
use warnings;
use Carp;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
    my $class = shift;
    my $params = shift;

    unless($params->{locations} || $params->{any_offset}) {
	throw("No filter locations or any-offset specified, you must specify at least one location or any-offset");
    }

    # We're going to treat all locations as regex
    my $locations = $params->{locations};
    if(ref $params->{locations} ne 'ARRAY') {
	$params->{locations} = [$params->{locations}];
    }
    my @locations = map( qr/$_/, @{$params->{locations}} );

    # Remember the locations that we're remapping and create
    # a place to store the offsets when we find them
    my $self = {'locations' => \@locations, 'offsets' => {} };

    # If we've been told that any non-one offset should be
    # remapped, remember that for when we encounter metadata records
    if($params->{any_offset}) {
	$self->{any_offset} = 1;
    }

    return bless $self, $class;
}

sub run {
    my $self = shift;
    my $params = shift;

    unless( exists($params->{record}) ) {
	throw("We're missing the RECORD for the filter call");
    }

    # Keep is locally for slightly more readable code
    my $record = $params->{record};

    # If we've found a sequence-region metadata directive
    if(ref $record eq 'Bio::EnsEMBL::IO::Object::GFF3Metadata' &&
       $record->{type} eq 'directive' &&
       $record->{directive} eq 'sequence-region') {
	# For each of the locations we've been asked to remap...
	foreach my $loc (@{$self->{locations}}) {

	    # Check it against the sequence-region name for a match
	    if($record->{value}[0] =~ $loc) {

		# We treat the sequence-record rows as being formatted the
		# Ensembl manner, so fields are hardcoded, this will break
		# if the records are formatted differently
		my $found_loc = $record->{value}[0];

		$self->{offsets}->{$found_loc} = $record->{value}[1];
	    }
	}

	# If we've been told to remap any non-one offset (ie. any region
	# that doesn't start at 1), and this region starts at a value larger
	# than 1, remember it for remapping later.
	if($self->{any_offset} && $record->{value}[1] > 1) {
	    my $found_loc = $record->{value}[0];
	    $self->{offsets}->{$found_loc} = $record->{value}[1];
	}

    # We've found a data record
    } elsif(ref $record eq 'Bio::EnsEMBL::IO::Object::ColumnBasedGeneric') {
	my $seqname = $record->seqname;

	# Did we find one of the sequence locations we're looking to remap?
	if($self->{offsets}->{$seqname}) {
	    # Rewrite the start and end location
	    my $offset = $self->{offsets}->{$seqname};
	    $record->start( $record->start() - $offset + 1 );
	    $record->end( $record->end() - $offset + 1 );
	}
    }

}

1;
