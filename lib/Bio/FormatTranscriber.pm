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

use Data::Dumper;

use Bio::FormatTranscriber::Config qw/parse_config/;

my $PARSERS = {FASTA => 'Bio::EnsEMBL::IO::Parser::Fasta',
                     GFF3  => 'Bio::FormatTranscriber::Parser::GFF3',
                     GTF   => 'Bio::EnsEMBL::IO::Parser::GTF',
                     GFF2  => 'Bio::EnsEMBL::IO::Parser::GTF'
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

    my($config, $format, $filters) =
	rearrange(['CONFIG', 'FORMAT', 'FILTERS'], @_);

    # Ensure we have a valid format for transcribing
    $self->{format} = uc($format);
    unless( $PARSERS->{ $self->{format} } ) {
	throw("Format $format is not a valid format");
    }

    # Pull and parse the config file, this will
    # throw an exception if the parsing fails
    $self->{config} = parse_config($config);
    print Dumper $self->{config};

    # Initialize the parsers and filters
    $self->{parser} = $PARSERS->{ $self->{format} };
    eval "use $self->{parser}";
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
#    $self->{processor} = "$processor"->new($self->{config});

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
#	no strict 'refs';
	$parser = "$self->{parser}"->open($infile);
    }

    # So dirty, but because of the way the parsers handle metadata lines
    # as one chunk, losing order and context, and the fact we have to make
    # an object in order to open a file...we sadly need to execution paths
    # to reach the stream processing code.
    if($parser->can('set_metadata_callback')) {
	my $callback = sub { my $line = shift; $self->{processor}->process_metadata($line); };
	$parser->set_metadata_callback($callback);
    }

    # Because the Fasta parser is mixed case we need to be a little ugly in
    # how we get the format to pass to the writer.
    my $format_str = (split '::', $self->{parser})[-1];
#    $self->{writer} = Bio::EnsEMBL::IO::Writer->new($format_str, $outfile);

    # This will handle looping through GXF and Fasta type files which the
    # parsers can produce objects for.
    while($parser->next()) {
	$self->{processor}->process_record($parser->create_object);
    }

    # More dirtiness, if we're parsing a GFF3 or similar that can have an
    # embedded Fasta, we need a way to transition to sequences and read those.
    # Check if our processor can handle sequences and if the parser is indeed
    # in fasta mode.
    if( $self->{processor}->can('process_sequences') &&
	$parser->can('in_fasta_mode') &&
	$parser->in_fasta_mode() ) {
	while($parser->next_sequence()) {
	    $self->{processor}->process_record($parser->create_object);
	}
    }
}

sub get_processor {
    my $self = shift;

    return $self->{processor};
}
