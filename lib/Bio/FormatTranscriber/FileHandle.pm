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

package Bio::FormatTranscriber::FileHandle;

use strict;
use warnings;

use PerlIO::gzip;

sub open {
    my $class = shift;
    my $filename = shift;

    my $mode = '<';

    if($filename =~ /^http/i) {
	$mode = '-|';
	$filename = 'curl -vs 2>/dev/null ' . $filename;
    }

    if($filename =~ /gz/i) {
	$mode .= ':gzip';
#	$filename .= ' |zcat';
    }

    print "mode: $mode\nfile: $filename\n";

    open my $fh, $mode, $filename or
	die "Error opening file $filename: $!";

    return $fh;
}

1;
