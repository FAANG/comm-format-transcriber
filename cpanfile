# Module requirements
requires 'Hash::Union';
requires 'JSON';

# From ensembl-test
requires 'IO::Scalar';
requires 'Archive::Zip';
requires 'BSD::Resource';
requires 'File::Sync';
requires 'Test::Fake::HTTPD';
requires 'Test::TCP';
requires 'Test::FTP::Server';

#Test requirements
test_requires 'Test::More';
test_requires 'Test::Differences';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
