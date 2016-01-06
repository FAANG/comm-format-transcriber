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

Bio::FormatTranscriber::Callback::Filter

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::Filter;

  $callback_obj = Bio::FormatTranscriber::Callback::Filter->new({'field1' => { match => "regex", "value" => [ "1\\d", "^X$" ] } } );

  $callback_obj->run("field" : "{{field}}", "value" : "{{value}}");

=head1 DESCRIPTION

Filter a field based record, for each field type in the record it allows
filtering by matching as set of values, matching a set of regex, or doing
and equality comparison against a value (ie. >, <, >=).

For a GFF3 entry such as:
1       havana  gene    52473   53312   .       1       .       gene_id=ENSG00000268020;ID=gene:ENSG00000268020;version=3;logic_name=havana;havana_version=1;description=olfactory receptor%2C family 4%2C subfamily G%2C member 4 pseudogene [Source:HGNC Symbol%3BAcc:HGNC:14822];biotype=unprocessed_pseudogene;havana_gene=OTTHUMG00000185779;Name=OR4G4P

a mapping entry that would match this line could look like:

    "filter_chromosome" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::Filter",
      "_init" : {"start" : {"match" : "equality", "equality" : ">", "value" : "20000" }, 
                 "seqname" : {"match" : "regex", "value" : [ "1\\d", "^X$" ], "inverse" : 1 },
		 "type" : ["gene"] },
      "_parameters" : {"field" : "{{field}}", "value" : "{{value}}"},
      "_filter" : 1
    }

and be called during and field's rule or by using the _all rule of a filter, ie.

  "input_filter" : { "_all" : "filter_chromosome" },

OR

  "input_filter" : { "start" : "filter_chromosome", "seqname": "filter_chromosome", "type" : "filter_chromosome" }

=cut

package Bio::FormatTranscriber::Callback::Filter;

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

    unless(ref $params eq 'HASH') {
	throw "We must specify at least one filter";
    }

    # Go through the parameters and set them up for later,
    # if it's a scalar (ie. individual match) make it an array
    # so our code is cleaner later on
    foreach my $param (keys %{$params}) {
	if(ref $params->{$param} eq 'ARRAY') {
	    $self->{$param} = $params->{$param};
	} elsif(ref $params->{$param} eq 'HASH') {
	    # Do a bit of munging, first ensure the value is an array if
	    # we're doing a regex, then precompile all the regex to speed
	    # up evaluation later
	    my $filter = $params->{$param};
	    if($filter->{match} eq 'regex') {
		if(ref $filter->{value} ne 'ARRAY') {
		    $filter->{value} = [$filter->{value}];
		}
		my @regexs = map( qr/$_/, @{$filter->{value}} );
		$filter->{value} = \@regexs;

		$self->{$param} = $filter;
	    }
	    $self->{$param} = $params->{$param};
	} else {
	    $self->{$param} = [$params->{$param}];
	}
    }

    return bless $self, $class;
}

sub run {
    my $self = shift;
    my $params = shift;

    # If we don't have a valid filter request, throw an error
    unless((ref $params eq 'HASH') &&
	   $params->{field} && $params->{value}) {
	throw "No field and/or value found for record";
    }

    # Current field being operated on
    my $field = $params->{field};

    # If we don't have a filter for this field, skip, say
    # we're fine with the record
    return 1
	unless($self->{$field});

    # Current filter, assign locally for a bit easier to read code
    my $filter = $self->{$field};
    my $value = $params->{value};

    # Simple type of filter, pure matching
    if(ref $filter eq 'ARRAY') {
	# If we don't find the value in our list of allowed
	# values, return that we should remove the record
	return grep( /^$value$/, @$filter );
    }

    # If we're doing a regex type filter, cycle through the precompiled
    # regex comparing them against the value, stopping if we find a match
    my $matched = 0;
    if($filter->{match} eq 'regex') {
	foreach my $match (@{$filter->{value}}) {

	    if($value =~ $match) {
		$matched = 1;
		last;
	    }
	}
    # If we're doing an quality type match
    } elsif($filter->{match} eq 'equality') {
	# Evaluate the equality against the value
	$matched = eval "$value $filter->{equality} $filter->{value}";
    }

    # Invert the match if we've been told this is a reverse (not) filter
    $matched = !$matched
	if($filter->{inverse});

    return $matched;
}

1;
