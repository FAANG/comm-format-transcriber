# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

BEGIN {
  use FindBin qw/$Bin/;
  use lib "$Bin/../lib";
  sub binpath { return $Bin; }
}

use Test::More;
use Test::Differences;
use Test::Deep;
use JSON;

use Bio::EnsEMBL::Test::StaticHTTPD;
use Bio::EnsEMBL::Test::FTPD;
use Bio::EnsEMBL::Utils::IO qw/slurp/;

require_ok('Bio::EnsEMBL::Utils::Net');
Bio::EnsEMBL::Utils::Net->import('do_GET');
Bio::EnsEMBL::Utils::Net->import('do_FTP');
use Net::FTP;

use Bio::FormatTranscriber::Config qw/parse_config/;

my $fake_httpd = 0;
eval {
  require Test::Fake::HTTPD;
  $fake_httpd = 1;
};

my $http_test_count = 5;
my $retry_count = 0;

#All tests are done locally. DO NOT INVOLVE PROXY SERVERS
delete $ENV{HTTP_PROXY} if $ENV{HTTP_PROXY};
delete $ENV{http_proxy} if $ENV{http_proxy};

# Set up test HTTP server
my $httpd = Bio::EnsEMBL::Test::StaticHTTPD->new(binpath . '/testConfigs');

# Fetch config for comparison against using parse_config()
my $doc = from_json(do_GET($httpd->endpoint . '/basic.conf'));
my $expected = from_json(slurp(binpath . "/testConfigs/basic.conf"));

cmp_deeply($doc, $expected, "Retreived config via straight HTTP");

# Fetch config via HTTP
my $http_config = parse_config($httpd->endpoint . '/basic.conf');
cmp_deeply($expected, $http_config, "Retreived config via parse_config, HTTP");

# Set up FTP server
my $user = 'testuser';
my $pass = 'testpass';
my $ftpd = Bio::EnsEMBL::Test::FTPD->new($user, $pass, binpath . '/testConfigs');

# Test we have an FTP server
my $ftp_url = "ftp://$user:$pass\@localhost:" . $ftpd->port . '/basic.conf';
my $ftp = Net::FTP->new('localhost', Port => $ftpd->port);
ok($ftp, 'Do we have a valid ftp client');
ok($ftp->login($user, $pass), 'Login to ftp server');
ok($ftp->quit, 'Close the ftp connection');

# Fetching config via FTP
ok($doc = parse_config($ftp_url), 'Fetching via FTP');
cmp_deeply($doc, $expected, "Retreived config via FTP");

# Fetching config from the file system
ok($doc = parse_config('file:///' . binpath . "/testConfigs/basic.conf"), "Retreive via file:///");
cmp_deeply($doc, $expected, "Retreived config via file:// is correct");

done_testing();
