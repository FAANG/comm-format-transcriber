# Module requirements
requires 'Hash::Union';
requires 'JSON';

requires 'Test::Fake::HTTPD';
requires 'Test::TCP';
requires 'Test::FTP::Server';
requires 'Archive::Zip';
requires 'Authen::PAM';
requires 'BSD::Resource';
requires 'File::Sync';

#Test requirements
test_requires 'Test::More';
test_requires 'Test::Differences';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
