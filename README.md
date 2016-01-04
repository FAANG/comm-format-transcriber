# Format Transcriber

[![Build Status](https://travis-ci.org/FAANG/faang-format-transcriber.svg?branch=master)](https://travis-ci.org/FAANG/faang-format-transcriber) [![Coverage Status](https://coveralls.io/repos/FAANG/faang-format-transcriber/badge.svg?branch=master&service=github)](https://coveralls.io/github/FAANG/faang-format-transcriber?branch=master)

## Filter and transcribe files based on filters and callbacks

The FormatTranscribe module is designed to allow easy translating of
standard formats (GTF, GFF3, Fasta), both filtering fields and mutating
them based on callback functions.  The tool is configured with a JSON
chunk specifying how to handle each column and what filters or callbacks
to apply.

For each record, a set of filters is applied, defaultly called input_filter,
processing and output_filter. However the exact filters to apply can be
specified on the command line.

Within each filter the rules for each field are applied in the order
defined for that format. Before each filter is applied a 'pre' rule is
applied and after a 'post' rule is applied. All filters and field based
rules are optional and will be skipped if not defied in the JSON
configuration file.

There are two types of rules currently, one is a simple hash based replacement,
where the lookup hash is also specified in the JSON configuration. The
second type of rule is a callback, where the user specifies the perl
module to load, the callback function name, and the parameters to
substitute when making the call (field value, field name being processed,
filter being processed, etc).

The JSON configuration file can be merged from multiple sources. The base
configuration and any included piece can have one or more "include"
fields to pull in more configuration pieces or mappings/lookups. This
allows large lookup tables to not be repeated again and again in
multiple configuration files, but be maintained in one location.

Included configuration sections are applied in the order seen in
a chunk, and nested configuration sections are added in a post-order
tree traversal. When merging sections, merge rules can be specified
as defined in the Hash::Union module.

Configuration files and included sections can be pulled via file://,
http:// and ftp:// uri format.

## Validating configurations

A command line tool also exists to validate a configuration. A given
configuration will be loaded and merged. Afterward all the specified
filters (or the default three) will be evaluated to ensure the lookup
table exists in the case of replacement type rules. And that the
callback module can be loaded, the callback function exists and
the parameters for substitution are valid.

### Configuration files

A configuration file consists of two sections, the filter rules and the
mappings for individual fields, plus any set of child configurations to
merge.

The filters are the set of rules to apply to each field in the file being
processed. Rules are either mappings (direct substitutions) or callbacks
to modules that return a value to be substituted. The configuration for a
callback and the mapping tables live in the mapping section of the
configuration.

The basic skeleton of a configuration file would look like:

```
{
   "input_filter" : {
     "field1" : "my_mapping_table",
     "field2" : "my_callback",
     "field3" : "large_lookup"
   },
   "mapping" : {
     "my_mapping_table" : { ... },
     "my_callback" : { ... }
   },
   "include" : ["http://ensembl.org/my_large_lookup.conf"]
}
```

In the above configuration, the loopup table "my_mapping_table" would be
used to do a direct substitution on values in field1. Values for field2
would be passed to the callback function defined by "my_callback" And
field3 would be replaced via a lookup table retrieved from a remote file
called my_large_lookup.conf.

### Filters

By default each record/row is run through three filters, input_filter,
processing, and output_filter. All fields are run through a particular
filter fir a record/row before the next filter is processed.

This can be useful if how a field is altered depends on a change made
to another field. Each of these filters is optional in the configuration
file, and the filters run can be overridden on the command line.

### Callbacks

Callback functions can be applied to individual fields, these consist of a
module to load, parameters to to pass during instantiation, the name of the
callback function and the parameters to pass to the callback function. A
callback function should return the value to be substituted in to the field
being processed. The basic format looks like:

```
    "callback": {
      "generic_callback" : {
        "_callback": ,
        "_module": "",
        "_init": ,
        "_parameters":
      }
    }
```

Parameters to the instantiation (_init) and callback (_parameters) can be a
scalar, array or hash. Variable substitution is done on the parameter strings
before they are passed to the callback module. ie.

```
{"field" : "{{FIELD}}", "value" : "{{Value}}", "filter" : "{{FiLTeR}}"}
```

would pass an anonymous hash to the function, substituting the name of the
field/column being processed, the value of the field, and which filter is
being run at that moment.

Allowed substitutions during module initialization are:
{{field}} - The name of the field the callback is processing
{{attr_path}} - If the field is a nested one such as attribute in GFF3, the sub-field processed
{{format}} - The format of the file being processed

Allowed substitutions when processing a value in the file are all of the above plus:
{{value}} - The value of the field being processed at that moment
{{filter}} - The filter being run
{{record}} - The full record, mapped to an anonymous hash (ie. the full row being processed for GFF3 format)

In addition for processing values [[some_mapping]] can be used to substitute a
chunk from the mapping section of the configuration. ie [[sequence_lookup|my_mapping]] would
substitute the entire contents of the sequence_lookup->my_mapping element in
the mapping section of the configuration file.

## Example configurations

A basic configuration, uses the filter from the mapping section 
chromosome->homo_sapiens_ensembl_to_ucsc, represented as a nested object (see
examples/chromosome_plus_callbacks.conf for an example of this), for the fields "source"

The field attribute in a GFF3 is split based on the ; character allowing multiple
values, in this example the sub-field ID in the attribute field is also
remapped based on the chromosome->homo_sapiens_ensembl_to_ucsc filter.

Finally, the mapping section callbacks "callback" and "seq_callback" are used for
the fields seqname and sequence respectively.

```
{
  "input_filter": { "source": "chromosome|homo_sapiens_ensembl_to_ucsc",
                    "seqname": "callback",
                    "attributes": {"ID": "chromosome|homo_sapiens_ensembl_to_ucsc"},
		    "sequence": "seq_callback" },
  "include": ["file://examples/chromosome_plus_callbacks.conf"]
}
```

A completed callback could look like:

```
     "callback" : {
        "_callback" : "run",
        "_module" : "Bio::FormatTranscriber::Callback",
        "_init" : ["{{Field}}", "{{Format}}"],
        "_parameters" : {"field" : "{{FIELD}}", "value" : "{{Value}}", "filter" : "{{FiLTeR}}"}
      }
```

## Example command lines

Read a FASTA file and run some simple transformations on it (trim sequence to 20bp in length), send results to STDOUT:

    bin/format_transcriber.pl -format fasta -c file://examples/base.conf -i t/data/data.faa

Same as above but denoise the output supressing the output from the sample callback function:

    bin/format_transcriber.pl -format fasta -c file://examples/base.conf -i t/data/data.faa 2>/dev/null

Read a GFF3 file and translate some columns:

    bin/format_transcriber.pl -format gff3 -c file://examples/base.conf -i t/data/data_with_fasta.gff3 2>/dev/null

Validate a configuration, ensuring callbacks can be loading and mappings exist:

    bin/validate_filter.pl -format gff3 -c file://examples/base.conf

Merge all the includes in a configuration file and output the unified configuration, good for testing if your merge rules work as expected:

    bin/merge_config.pl -c file://examples/merge.conf
