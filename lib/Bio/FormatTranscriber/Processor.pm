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

Bio::FormatTranscriber::Processor

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Processor;

  my $processor = Bio::FormatTranscriber::Processor->new($config);

  $processor->validate_filters();

  $processor->process_record($record);

=head1 DESCRIPTION

Process records as they are read serially from the source. Most methods in this
base class should not be called, instead are stubs for inherited classes for
each format type.

The validate_filters() function can be used to check a configuration
before processing a stream, to ensure all requested filters for fields exist.

=cut

package Bio::FormatTranscriber::Processor;

use strict;
use warnings;
use Carp;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
    my $class = shift;

    my $self = {};

    my($config, $filters) =
	rearrange([qw(CONFIG FILTERS)], @_);    

    if($config) {
	$self->{config} = $config;
    } else {
	throw("No config given when making object, that's naughty");
    }

    # Make the object so we can use the methods
    bless $self, $class;

    # Set the default filters
    $self->filters($filters ? $filters : [qw/input_filter processing output_filter/]);

    return $self;
}

=head2 process_record

    Description: Stub base method for processing a record, implemented
                 in inherited classes.

=cut

sub process_record {
    my $self = shift;
    my $record = shift;

    confess("Method process_record not implemented. This is really important");
}

=head2 process_metadata

    Description: Stub base method for processing metadata in a record, 
                 implemented in inherited classes.

=cut

sub process_metadata {
    my $self = shift;
    my $record = shift;

    confess("Method process_metadata not implemented. This is really important");
}

sub process_callback {
    my $self = shift;
    my $filter = shift;
    my $field = shift;
    my $mapping = shift;
    my $col_value = shift;
    my $record = shift;
    my $attr_path = shift || '';

    if(! $mapping->{_obj} ) {
	$self->init_callback($mapping, $field, $attr_path);
    }

    my $params = $self->eval_parameters($mapping->{_parameters}, {'FIELD' => $field,
								  'ATTR_PATH' => $attr_path,
								  'FORMAT' => $self->format,
								  'VALUE' => $col_value,
								  'FILTER' => $filter,
								  'RECORD' => $record } );
    my $callback = $mapping->{_callback};

    return $mapping->{_obj}->$callback($params);
}

sub init_callback {
    my $self = shift;
    my $mapping = shift;
    my $field = shift;
    my $attr_path = shift || '';

    # Try to load the module
    $self->load_module($mapping)
	unless($mapping->{_loaded});

    my $init_param = $self->eval_parameters($mapping->{_init}, {'FIELD' => $field,
								'ATTR_PATH' => $attr_path,
								'FORMAT' => $self->format} );

    $mapping->{_obj} = "$mapping->{_module}"->new($init_param);
    
}

sub load_module {
    my $self = shift;
    my $mapping = shift;

    eval "use $mapping->{_module}";
    if($@) {
	throw("Error loading processing module " . $mapping->{_module} . " $@");
    }

    # Mark down we've loaded it so we don't try to load it again
    $mapping->{_loaded} = 1;
}

=head2 eval_parameters

    Description: For a set of parameters to a callback function, evaluate
                 all the parameter substitutions.

                 Allowed types for parameter list is hash reference, array
                 reference or a string.

=cut

sub eval_parameters {
    my $self = shift;
    my $eval_params = shift;
    my $values = shift;

    if(ref $eval_params eq 'HASH') {
	foreach my $param (keys %{$eval_params}) {
	    $eval_params->{$param} = $self->eval_param($eval_params->{$param}, $values);
	}
    } elsif(ref $eval_params eq 'ARRAY') {
	for my $i (0 .. $#$eval_params) {
	    $eval_params->[$i] =  $self->eval_param($eval_params->[$i], $values);
	}
    } else {
	$eval_params = $self->eval_param($eval_params, $values);
    }

    return $eval_params;
}

=head2 eval_param

    Description: For a single parameter in a callback's parameter list,
                 attempt to look it up in the given values and substitute.

=cut 

sub eval_param {
    my $self = shift;
    my $param = shift;
    my $values = shift;

    if($param =~ /{{[\w_]+}}/) {
	# Find any {{key}} in the string, then if there's an uppercase of {{KEY}}
	# in our lookup parameter set, substitute it.
	# Otherwise leave the original value in place. Find all different {{key1}},
	# {{key2}}, ... in the string in one go.
	$param =~ s/{{([\w_]+)}}/$values->{uc($1)}?$values->{uc($1)}:"{{$1}}"/eg;
    }

    if($param =~ /\[\[\w_|\]\]/) {
	$param =~ s/\[\[([\w_|]+)\]\]/$self->nested_hash($self->{config}->{mapping}, $1)?$self->nested_hash($self->{config}->{mapping}, $1):"[[$1]]"/eg;
    }

    return $param;   
}

=head2

    Description: Validate all the filters, or a given subset, ensure they're
                 usable in trascribing a file.

=cut

sub validate_filters {
    my $self = shift;
    my $filters = shift || $self->filters;
    my $errors = 0;

    unless($filters) {
	confess("We can't validate a configuration if no filters have been set.");
	return;
    }

    # If we've been given a single filter, turn it in to an array so we
    # can have generic code below
    if(ref($filters) ne 'ARRAY') {
	$filters = [$filters];
    }

    # Cycle through the filters, check and add to the count of errors we've found
    foreach my $filter (@{$filters}) {
	$errors += $self->validate_filter($filter);
    }

    if($errors) {
	throw("We found $errors error" . ($errors>1?'(s)':'') . " in the configuration mappings.");
    }

}

=head2 validate_filter

    Description: For a given filter, verify all the requested mappings are valid and exist either
                 in the mappings set or are loadable modules.

=cut

sub validate_filter {
    my $self = shift;
    my $filter_name = shift;
    my $errors = 0;

    # If a user hasn't defied a type of filter, that's ok, skip it
    unless(defined($self->{config}->{$filter_name})) {
	print "\tNo filter in configuration: $filter_name\n";
	return 0;
    }

    # Go through all the mappings for a filter, and dig deeper if it's a
    # nested filter with a second level within it
    my $filter = $self->{config}->{$filter_name};
    foreach my $key (keys %{$filter}) {
	if(ref($filter->{$key}) eq 'HASH') {
	    foreach my $attr (keys %{$filter->{$key}}) {
		my $res = $self->validate_mapping($filter, $key, $attr);
		$errors++ unless($res);
	    }
	} else {
	    my $res = $self->validate_mapping($filter, $key);
	    $errors++ unless($res);
	}
    }

    return $errors;
}

=head2 validate_mapping

    Description: Ensures a given filter actually exists in the filters set.

=cut

sub validate_mapping {
    my $self = shift;
    my $filter = shift;
    my $key = shift;
    my $attr_path = shift || '';

    # Fetch the key for the mapping table we're supposed to grab
    my $mapping_key = $self->nested_hash($filter, join('|', $key, $attr_path));

    # Can we find the mapping in the mapping structure?
    my $mapping;
    eval {
	$mapping = $self->nested_hash($self->{config}->{mapping}, $mapping_key);
    };
    if($@) {
	print "*\tNo mapping for $mapping_key in configuration.\n";
	return 0;
    } elsif(! $mapping ) {
	print "*\tMapping for $mapping_key is empty.\n";
	return 0;
    }

    # If it's a callback type, try to load the module
    if($mapping->{_callback}) {
	eval {
	    # Try to load the module
	    $self->load_module($mapping)
		unless($mapping->{_loaded});
	};
	if($@) {
	    print "\tCallback module " . $mapping->{_module} . " for $mapping_key failed to load\n";
	    return 0;
	}

	# Ensure the callback method requested exists
	my $callback = $mapping->{_callback};
	unless("$mapping->{_module}"->can($callback)) {
	    print "\tCallback module " . $mapping->{_module} . " has no method $callback\n";
	    return 0;
	}

	# Ensure we can map the substitutions from the mapping section [[ ]]
	eval {
	    $self->eval_parameters($mapping->{_init}, {})
		if($mapping->{_init});
	};
	if($@) {
	    print "\tCallback module " . $mapping->{_module} . ", _init can't evaluate mapping substitutions\n";
	    return 0;
	}

	# Ensure we can map the substitutions from the mapping section [[ ]]
	eval {
	    $self->eval_parameters($mapping->{_parameters}, {})
		if($mapping->{_parameters});
	};
	if($@) {
	    print "\tCallback module " . $mapping->{_module} . ", _parameters can't evaluate mapping substitutions\n";
	    return 0;
	}
    }

    print "\tConfiguration for " . ($attr_path ? join('|', $key, $attr_path) : $key) . " looks good.\n";
    return 1;
}

=head2 filters

    Description: Accessor/mutator for filters to process

=cut

sub filters {
    my $self = shift;

    if(@_) {
	my $arg = shift;
	if(ref $arg eq 'ARRAY') {
	    $self->{filters} = $arg;
	}
    } else {
	return $self->{filters} || [];
    }
}

=head2 format

    Description: Placeholder for returning the format of the
                 file we're parsing.

=cut

sub format {
    return 'None';
}

=head2 nested_hash

    Description: Accessor/Mutator for nested hash structures, given the key list as
                 a | separated string in the $attr_path argument.

=cut

sub nested_hash {
    my $self = shift;
    my $record = shift;
    my $attr_path = shift;
    my $value = shift;

    # If we're not given a path to access that's a big problem
    throw("Attribute path for accessing hash is empty")
	unless($attr_path);

    # Split out the hash key components
    my @path = split '\|', $attr_path;
 
    # Loop through the nested hash, walking
    # each key
    my $ref = \$record;
    foreach my $key (@path) {
	# Address autovivification, we don't want that behaviour
	# if we're not setting a value, we should fail out if
	# a hash path doesn't exist.
	unless($value || defined($$ref->{ $key })) {
	    throw("Error, $key not defined");
	}
	# Loop getting the next reference
	$ref = \$$ref->{ $key };
    }
    
    # Once we have a reference to the depth
    # we've been asked to access, get or set
    # the value pointed to by the reference
    if($value) {
	$$ref = $value;
    } else {
	return $$ref;
    }
   
}

1;
