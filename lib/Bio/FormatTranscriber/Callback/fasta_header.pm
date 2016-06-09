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

Bio::FormatTranscriber::Callback::fasta_header

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::fasta_header

  $callback_obj = Bio::FormatTranscriber::Callback::fasta_header->new({header_pattern => "regex_of_fasta_header",
                                                                       parameter_1 => { hash of substitutions },
                                                                       parameter_2 => { hash of substitutions },
                                                                      );

  $callback_obj->run({record => $record});

=head1 DESCRIPTION

Callback to match a given FASTA header using regular expressions, and do
hash based substitutions on capture groups ($1, $2, $3).

For example a standard Ensembl FASTA header like:
>1 dna:chromosome chromosome:GRCh38:1:1:248956422:1 REF

would be matched by a regex such as:
"\\w+ [\\w:]+ \\w+:(\\w+):(\\w+):\\w+:\\w+:\\w+ \\w+"

where in this regex the assembly and slice (chromosome name) are captured
in to $1 and $2. In the callback initialization there should be
corresponding parameter_1 and parameter_2 options giving the
hash lookup tables to try and substitute the capture group from.

Mapping entry could look like:


    "fasta_header" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::fasta_header",
      "_init" : { "header_pattern" : "(\\w+) [\\w:]+ \\w+:(\\w+):\\w+:\\w+:\\w+:\\w+ \\w+",
                  "parameter_1" : "[[chromosome|homo_sapiens_ensembl_to_ucsc]]",
                  "parameter_2" : "[[assembly]]" },
      "_parameters" : { "record" : "{{record}}" } 
    },
    "assembly" : { "GRCh38" : "New_Chromosome_Name" }

and be called during the _pre or _post field step of a filter, ie.

  "input_filter": { "_pre" : "fasta_header"
		  },

=cut

package Bio::FormatTranscriber::Callback::fasta_header;

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

    unless($params->{header_pattern}) {
	throw("No regex given for the fasta header format");
    }
    $self->{pattern} = $params->{header_pattern};

    # Try to find substitution parameters which should match
    # the capture groups () in the regex
    $self->{parameters} = ();
    for(my $i=1; $i <= 9; $i++) {
	my $param_str = "parameter_$i";
	if($params->{$param_str}) {
	    $self->{parameters}->[$i] = $params->{$param_str};
	}
    }

    return bless $self, $class;
}

# Run routine for module, for each header of a fasta record,
# compare it against the regex string we received during
# initialization.

sub run {
    my $self = shift;
    my $params = shift;

    # Die if we weren't configured to receive a record
    unless((ref $params eq 'HASH') &&
	   $params->{record}) {
	throw "No record found for sequence";
    }

    # Extract the fasta header
    my $header = $params->{record}->header;

    # Try to compare the fasta header against the regex and if
    # it matches send it off to the switcher helper to make the changes
    if($header =~ s/$self->{pattern}/switcher($self->{parameters})/e) {
	$params->{record}->header($header);
    }

}

# Helper routine to do the actual substitution in the matching string,
# it takes the list of capture groups and their coordinates and tries
# to substitute in the replacement strings if they match in the
# corresponding lookup tables.

sub switcher {
    my $params = shift;

    # $& is the original matching string
    my $header = $&;
    # Capture all the capture groups in to an array we
    # can point at by index, rather than individual variables
    my @P = (undef,$1,$2,$3,$4,$5,$6,$7,$8,$9);

    # Working backwards since we're slicing an array and indexes will change,
    # go through all the parameters we've been given which should match
    # the capture groups, and see if we can substitute a new string
    # from the hash based lookup.
    for(my $i = $#{$params}; $i > 0; $i--) {
	# $params is a reference to an array of the lookup tables for the
	# substitutions, the index of the lookup table in $params should
	# correspond to the capture group () in the regex. ie. the 3rd
	# element in $params->[] should match the third () in the regex
	if($params->[$i]->{$P[$i]}) {
	    # Once we've found a match, use substr to replace the existing
	    # string at the point of the capture group () using the new
	    # one from the lookup table. @- is an array of the starting indexes
	    # of the matches and @+ is an array of the ending indexes of the
	    # matches in the original string.
	    substr $header, $-[$i], $+[$i] - $-[$i], $params->[$i]->{$P[$i]};
	}
    }

    return $header;
}

1;
