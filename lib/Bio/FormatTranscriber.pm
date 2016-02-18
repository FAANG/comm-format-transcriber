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

Bio::FormatTranscriber

=head1 SYNOPSIS

  use Bio::FormatTranscriber;

  my $ft = Bio::FormatTranscriber->new(

=head1 DESCRIPTION



=cut

package Bio::FormatTranscriber;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::IO::Writer;

use Bio::FormatTranscriber::Config qw/parse_config/;
use Scalar::Util qw/openhandle/;

my $PARSERS = {FASTA => 'Bio::EnsEMBL::IO::Parser::Fasta',
                     GFF3  => 'Bio::FormatTranscriber::Parser::GFF3',
                     GTF   => 'Bio::FormatTranscriber::Parser::GTF',
                     GFF2  => 'Bio::EnsEMBL::IO::Parser::GTF'
};

my $OBJECTS = {FASTA => 'Bio::EnsEMBL::IO::Object::ColumnBasedGeneric',
               GFF3  => 'Bio::EnsEMBL::IO::Object::ColumnBasedGeneric',
               GTF   => 'Bio::EnsEMBL::IO::Object::GTF'
};

my $SERIALIZERS = {Fasta => 'Bio::EnsEMBL::Utils::IO::FASTASerializer'
};

=head2 new

  Description: Creates a new format transcriber object.
  Arguments  : Config file to use, format of the files
               being transcribed
  Returntype : Bio::FormatTranscriber
  Exceptions : If the format isn't one of the allowed
               If we aren't able to retrieve/parse the
               config file(s)

=cut

sub new {
    my $class = shift;

    my $self = {};

    my($config, $format, $filters, $output_format) =
	rearrange(['CONFIG', 'FORMAT', 'FILTERS', 'OUT_FORMAT'], @_);

    # Ensure we have a valid format for transcribing
    $self->{format} = uc($format);
    unless( $PARSERS->{ $self->{format} } ) {
	throw("Format $format is not a valid format");
    }

    # If we've been asked to convert the format, load the new
    # object type so we'll write the records in the correct format.
    # This is highly experimental.
    $self->{out_format} = uc($output_format);
    if( $self->{format} ne $self->{out_format} ) {
	unless( $OBJECTS->{ $self->{out_format} } ) {
	    throw("Format $output_format is not a valid output format");
	}

	$self->{output_obj} = $OBJECTS->{ $self->{out_format} };
	eval "use $self->{output_obj}";
	if($@) {
	    throw("Error loading module for output format $output_format: $@" );
	}
    }

    # Pull and parse the config file, this will
    # throw an exception if the parsing fails
    $self->{config} = parse_config($config);

    # Initialize the parsers and filters
    $self->{parser_obj} = $PARSERS->{ $self->{format} };
    eval "use $self->{parser_obj}";
    if($@) {
	throw("Error loading module for format $format: $@");
    }

    # Create the processor for records for the given format
    my $processor = 'Bio::FormatTranscriber::Processor::' . $self->{format};
    eval "use $processor";
    if($@) {
	throw("Error loading processor module for format $format: $@");
    }
    $self->{processor} = "$processor"->new(-CONFIG => $self->{config});

    $self->{processor}->filters($filters)
	if(@$filters);

    # Initialize the various filters here

    return bless $self, $class;

}

=head2 transcribe_file

  Description: Transcribe a file filtering the
               fields based on the config initialized
               with
  Arguments  : Input file, destination file
  Returntype : Boolean
  Exceptions : 

=cut

sub transcribe_file {
    my ($self, $infile, $outfile) = @_;

    # Create the parser to read the input file
    my $parser;
    {
	$parser = "$self->{parser_obj}"->open($infile);
	$self->{parser} = $parser;
    }

    # Use the handle we've been passed or create the output handle
    if(openhandle($outfile)) {
	$self->{out_handle} = $outfile;
    } else {
	$self->{outfile} = $outfile;
	CORE::open($self->{out_handle}, ">$outfile") ||
	    throw("Error opening output file $outfile: $@");
    }

    # So dirty, but because of the way the parsers handle metadata lines
    # as one chunk, losing order and context, and the fact we have to make
    # an object in order to open a file...we sadly need the execution paths
    # to reach the stream processing code.
    # So call the processor's metadata handler giving it the output handle so
    # it can write the lines out.
    if($parser->can('set_metadata_callback')) {
	my $callback = sub { my $line = shift; $self->{processor}->process_metadata($line, $self->{out_handle}); };
	$parser->set_metadata_callback($callback);
    }

    # Because the Fasta parser is mixed case we need to be a little ugly in
    # how we get the format to pass to the writer.
    my $format_str = (split '::', $self->{parser})[-1];

    # This will handle looping through GXF and Fasta type files which the
    # parsers can produce objects for.
    while($parser->next()) {
	my $rec = $self->{processor}->process_record($parser->create_object);
	$self->write_record($rec)
	    unless($rec->{delete});
    }

    # More dirtiness, if we're parsing a GFF3 or similar that can have an
    # embedded Fasta, we need a way to transition to sequences and read those.
    # Check if our processor can handle sequences and if the parser is indeed
    # in fasta mode.
    if( $self->{processor}->can('process_sequences') &&
	$parser->can('in_fasta_mode') &&
	$parser->in_fasta_mode() ) {
	while($parser->next_sequence()) {
	    my $rec = $self->{processor}->process_record($parser->create_object);
	    $self->write_record($rec)
		unless($rec->{delete});
	}
    }
}

=head2 write_record

    Description: Write out a record, using the serializer in the record
                 object if available, otherwise the external serializer.

                 We have to be a little messy because of formats like GFF3
                 that can have both a column based section and a sequence
                 section.

=cut

sub write_record {
    my $self = shift;
    my $record = shift;

    # What's the format of the record being written
    my $format = (split '::', ref($record))[-1];

    # If we've been asked to do a format conversion, try to
    # cast the object to the proper type so it knows how to
    # write itself. This should work for all types derived
    # from FieldBased, but will likely blow up spectactularly
    # for any incompatible format conversions.
    if($self->{output_obj}) {
	bless $record, $self->{output_obj};
    }

    # If the object knows how to turn itself in to it's native format,
    # let it take care of itself
    if($record->can('create_record')) {
	print { $self->{out_handle} } $record->create_record;

    # Otherwise use the external serializer
    } elsif($SERIALIZERS->{$format}) {
	my $serializer = $self->get_serializer_by_type($format);
	$serializer->print_Seq($record);
    } else {
	throw("Can't write record of type" . ref($record));
    }
}

=head2 get_serializer_by_type

    Description: Get the serializer for the given format, either load it or
                 return a pre-existing reference

=cut

sub get_serializer_by_type {
    my $self = shift;
    my $type = shift;

    # If we don't have an existing serializer
    unless($self->{serializer}->{$type}) {
    
	# Get the module name and create an instance
	my $serializer = $SERIALIZERS->{$type};
	eval "use $serializer";
	if($@) {
	    throw("Error loading serializer for format $type: $@");
	}
	$self->{serializer}->{$type} = "$serializer"->new($self->{out_handle});
    }

    # Return out loaded instance of the serializer
    return $self->{serializer}->{$type};
}

sub get_processor {
    my $self = shift;

    return $self->{processor};
}
