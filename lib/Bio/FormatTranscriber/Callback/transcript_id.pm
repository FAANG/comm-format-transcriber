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

Bio::FormatTranscriber::Callback::transcript_id

=head1 SYNOPSIS

  use Bio::FormatTranscriber::Callback::transcript_id;

  $callback_obj = Bio::FormatTranscriber::Callback::Filter->new();

  $callback_obj->run({"record" => "{{record}}"});

=head1 DESCRIPTION

Some packages require the a non-standard transcript_id attribute in all records,
including gene records, in GTF files. Typically since this doesn't make much
sense in the context of a gene, as there can be multiple transcripts, the gene_id
stable id is simply repeated in the transcript_id attribute. This filter will
examine the attributes of a gene type record and add a transcript_id matching
the gene_id if one doesn't already exist.

For a GTF entry such as:
1       havana  gene    11869   14409   .       +       .       gene_id "ENSG00000223972"; gene_version "5"; gene_name "DDX11L1"; gene_source "havana"; gene_biotype "transcribed_unprocessed_pseudogene"; havana_gene "OTTHUMG00000000961"; havana_gene_version "2";

become:
1       havana  gene    11869   14409   .       +       .       gene_id "ENSG00000223972"; gene_source "havana"; gene_version "5"; gene_biotype "transcribed_unprocessed_pseudogene"; havana_gene "OTTHUMG00000000961"; havana_gene_version "2"; gene_name "DDX11L1"; transcript_id "ENSG00000223972"

a mapping entry that would match this line could look like:

  "mapping" : {
    "add_transcript_id" : {
      "_callback" : "run",
      "_module" : "Bio::FormatTranscriber::Callback::transcript_id",
      "_parameters" : {"record" : "{{record}}"}
    }
  }

and be called during a filter that acts on the whole record such as _pre or _post, ie.

  "input_filter" : { "_pre" : "add_transcript_id" },


=cut

package Bio::FormatTranscriber::Callback::transcript_id;

use base qw/Bio::FormatTranscriber::Callback/;

use strict;
use warnings;
use Carp;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub run {
    my $self = shift;
    my $params = shift;

    # If we don't have a valid filter request, throw an error
    unless((ref $params eq 'HASH') &&
	   $params->{record}) {
	throw "No record object found, this filter operates on full records";
    }

    # Current record being operated on
    my $record = $params->{record};

    # If we don't have a filter for this field, skip, say
    # we're fine with the record
    return 1
	unless($record->{type} eq 'gene');

    # If we're an Ensembl type GTF that doesn't have a mirroring transcript_id,
    # copy the gene_id over to a new transcript_id
    if( exists($record->{attributes}->{gene_id}) &&
	! exists($record->{attributes}->{transcript_id}) ) {
	$record->{attributes}->{transcript_id} = $record->{attributes}->{gene_id};
    }

}

1;
