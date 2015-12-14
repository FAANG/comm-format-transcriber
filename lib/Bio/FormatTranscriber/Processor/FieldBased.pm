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

Bio::FormatTranscriber::Processor::FieldBased

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Processor::FieldBased;

  my $processor = Bio::FormatTranscriber::Processor::FieldBased->new(config => $config_reference);

  $processor->fields(@allowed_fields);

  $processor->process_record($record);

  $processor->process_metadata($record);

=head1 DESCRIPTION

Process records of type generic field based (GTF, GFF3, etc, plus fasta converted to generic field
based objects).  On creation the configuration of mappings should be passed in, this is a
multi-dimensional hash containing the field mappings and the rules to apply these mappings.

The object must be given a list of fields to process from a record, where a record
is a reference to a hash containing the fields for the record.

When streaming through the file to be processed, records should be passed to the
processor_record one by one, and metadata should be passed to process_metadata. 
Records should be passed as references as the mutation on the records is destructive!

An exception is thrown if the configuration doesn't map properly to the fields
requested.

=cut

package Bio::FormatTranscriber::Processor::FieldBased;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use Data::Dumper;

use base qw/Bio::FormatTranscriber::Processor/;

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);

    return $self;
}

=head2 fields

    Description: Accessor/mutator for fields in record type

=cut

sub fields {
    my $self = shift;

    if(@_) {
	my $arg = shift;
	if(ref $arg eq 'ARRAY') {
	    $self->{fields} = $arg;
	}
    } else {
	return $self->{'fields'} || [];
    }
}

=head2 process_record

    Description: Process a record against all the defined filters.

=cut

sub  process_record {
    my $self = shift;
    my $record = shift;

    # We want to allow in-order filtering, so all input are
    # completed before output, just in case there's a dependency
    # we want to allow deeper processing
    for my $filter (@{$self->filters}) {
	if(defined($self->{config}->{$filter})) {
	    $self->process_filter($filter, $record);
	}
    }

    # Unfortunately we have to write out the records here,
    # I'd rather decouple things a little more. But because
    # of how the metadata is processed and being unable to return
    # that line by line in the GXF type files...
    print Dumper $record;
}

=head2 process_filter

    Description: Process an individual filter, cycling through all
                 fields and nested fields specified for update in
                 the filter's configuration section of the configuration
                 file.

=cut

sub process_filter {
    my $self = shift;
    my $filter = shift;
    my $record = shift;

    # For all the allowed fields in the record type...
    # plus a pre and post filter if specified
    foreach my $field ('pre', @{$record->fields}, 'post') {

	# If we have a requested mapping for this record in the filter configuration...
	if(defined($self->{config}->{$filter}->{$field})) {

	    # Special case, if it's a nested hash in the field rules, cycle through
	    # processing those sub-filters unless it's a hash holding a callback routine
	    if(ref($self->{config}->{$filter}->{$field}) eq 'HASH') {
		foreach my $attr (keys %{$self->{config}->{$filter}->{$field}}) {
		    $self->process_field($filter, $field, $record, $attr);
		}
	    } else {

		# Otherwise just process the filter for this field against
		# the record.
		$self->process_field($filter, $field, $record);
	    }

	}
    }
}

=head2 process_field

    Description: Process a given field in the record, this can be
                 a field or a nested field lower down in a field.
=cut

sub process_field {
    my $self = shift;
    my $filter = shift;
    my $field = shift;
    my $record = shift;
    my $attr_path = shift || '';

    # Fetch the key for the mapping table we're supposed to grab
    my $mapping_key = $self->nested_hash($self->{config}->{$filter}, join('|', $field, $attr_path));
    my $mapping;

    # Fetch the requested mapping table from the set of mappings
    eval {
	$mapping = $self->nested_hash($self->{config}->{mapping}, $mapping_key)
    };
    if($@) {
	throw("Error looking up mapping key $mapping_key for field $field: $@");
    } elsif(! $mapping ) {
	throw("No value for mapping key $mapping_key for field $field");
    }
    
    # Now that we have the location in the record to filter and the loopup
    # set, go process that mapping.
    $self->process_mapping($filter, $field, $mapping, $record, $attr_path);

}

=head2 process_mapping

    Description: Process an individual mapping against a field in the
                 record. This field can be a nested field mutliple 
                 levels down.

                 The transformation is descructive on the original record/field.

=cut

sub process_mapping {
    my $self = shift;
    my $filter = shift;
    my $field = shift;
    my $mapping = shift;
    my $record = shift;
    my $attr_path = shift || '';

    # If we don't have this field for this record,
    # skip it
    unless($record->{$field}) {
	return;
    }

    # Processing a HASH type mapping, which are simple lookup tables.
    if(ref $mapping eq 'HASH') {
	# Retrieve the value of the field, going down any needed number of
	# levels in the structure.
	my $col_val = $self->nested_hash($record, join('|', $field, $attr_path));

	# Process if we have a mapping available for the field
	my $res;
	if( defined($mapping->{'_callback'}) ) {
	    $res = $self->process_callback($filter, $field, $mapping, $col_val, $record, $attr_path);
	} elsif(defined($mapping->{$col_val})) {
	    $res = $mapping->{$col_val};
	}

	# Write back the new value to the field in the record
	$self->nested_hash($record, join('|', $field, $attr_path), $res)
	    if($res);

    # Allow code fragments here as other "mapping" types?
    } else {
	throw("Unsupported mapping type: " . ref $mapping);
    }
}

1;
