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

Bio::FormatTranscriber::Config

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Config qw/parse_config/;

  my $config = parse_config('/my/config/file');
  
=head1 DESCRIPTION

Parses a config file from a file, in JSON format. Allows parsing of nested
config files where 

=head1 DEPENDENCIES
L<JSON> is needed to parse the config files passed in.

=head1 METHODS

=cut

package Bio::FormatTranscriber::Config;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::URI qw(parse_uri);
use Bio::EnsEMBL::Utils::Net qw/do_GET do_FTP/;
use Bio::EnsEMBL::Utils::IO qw/slurp/;

use JSON;
use Hash::Union 'union';

use base qw/Exporter/;
our @EXPORT_OK;
our %EXPORT_TAGS;
@EXPORT_OK = qw/parse_config dump_config/;
%EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head2 parse_config()

  Description: Fetch and parse the config file given via the 
               argument.

               Recursively fetch config files as included
               via the "include" tag and array. See Hash::Union
               for special merging rules for items in the hash,
               be default arrays are overridden by config files
               higher up the include tree. 

               Also, items from the include tree are added in
               post-order, so include order matters.

  Argv[1]    : string
               uri of the config to initially load

  Returntype : HashRef
  Exceptions : If we're unable to parse a json chunk,
               if a uri scheme type is unsupported

=cut

sub parse_config {
    my ($uri) = @_;

    # Start the recursive calls to build
    # our config based on the uri given and
    # all the includes it may contain
    my $config = _apply_config($uri);

    return $config;
}

=head2 dump_config

    Description: Takes a configuration object and attempts to produce
                 the JSON encoding.

    Argv[1]    : ref
                 configuration structure to encode

    Returntype : string
    Exceptions : If we're unable to encode the object as json

=cut

sub dump_config {
    my ($config) = @_;

    my $json_str;
    eval {
	$json_str = to_json($config, { ascii => 1, pretty => 1 });
    };
    if($@) {
	throw("Unable to encode config: $@");
    }

    return $json_str;
}

=head2 _apply_config()

  Description: Recursively fetch config files as included
               via the "include" tag and array. See Hash::Union
               for special merging rules for items in the hash,
               be default arrays are overridden by config files
               higher up the include tree. 

               Also, items from the include tree are added in
               post-order, so include order matters.

  Argv[1]   :  string
               uri of the config to initially load
  Argv[2]   :  HashRef (optional)
               Base config to apply the uri config file to

  Returntype: HashRef
  Exceptions: If we're unable to parse a json chunk,
              if a uri scheme type is unsupported

=cut

sub _apply_config {
    my ($uri, $config) = @_;

    my $config_delta = _fetch_config($uri);
    my $json_delta = {};
    eval {
	$json_delta = from_json($config_delta);
    };
    if($@) {
	# The JSON module can throw some nasty errors
	throw("Unable to decode uri $uri: " . $@);
    }

    # We're going to recurse first so we apply all the
    # leaf nodes as the base, but yes order of includes
    # can influence final outcome of the config, so
    # we shouldn't go too crazy with our nesting
    if($json_delta->{include}) {
	# For each include tag, recurse down and apply it to
	# the base config
	foreach my $inc_uri (@{$json_delta->{include}}) {
	    $config = _apply_config($inc_uri, $config);
	}

	# Since this is a merged config we don't want
	# to keep the include around, should we save
	# this out and reload it later
	delete $json_delta->{include};
    }

    # Only apply the delta if we have a base config,
    # otherwise if we're at the first leaf, the delta
    # is our base
    if($config) {
	# Now we apply the current level config to 
	$config = union([ $config, $json_delta ]);
    } else {
	$config = $json_delta;
    }

    return $config;
}

=head2 _fetch_config()

  Description: Fetches a config file based on a given uri,
    we currently support file://, http:// and ftp://
    
  Returntype: HashRef
  Exceptions: If we're unable to parse a json chunk,
              if a uri scheme type is unsupported

=cut

sub _fetch_config {
    my ($uri) = @_;

    # Break the uri down so we can fetch it
    my $parsed_uri = parse_uri($uri);
    my $contents;

    if($parsed_uri->{scheme} eq 'http') {
	$contents = do_GET($uri);
    } elsif($parsed_uri->{scheme} eq 'ftp') {
	$contents = do_FTP($uri);
    } elsif($parsed_uri->{scheme} eq 'file') {
	$contents = slurp($parsed_uri->{path});
    } else {
	throw("Unsupported scheme type: " . $parsed_uri->{scheme});
    }

    # Return the file contents if we successfully retrieved values
    return $contents if defined $contents;

    throw("Unable to retrieve contents of config $uri");
}

