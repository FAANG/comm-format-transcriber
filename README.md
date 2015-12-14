# Format Transcriber

## Filter and transcribe files based filters and callbacks

The FormatTranscribe module is designed to allow easy translating of
standard formats (GTF, GFF3, Fasta), both filtering fields and mutating
them based on callback functions.  The tool is configured with a JSON
chunk specifying how to handle each column and what filters or callbacks
to apply.

For each record, a set of filters is applied, defaultly called input_filter,
processing and output_filter. However the exact filters to apply can be
specified on the command line.

Within each filter the rules for each field are applied in the order
defied for that format. Before each filter is applied a 'pre' rule is
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

## Example configurations

## Example command lines
