# Module requirements
requires 'Hash::Union';
requires 'JSON';

requires 'Archive::Zip';
#requires 'Authen::PAM';
requires 'BSD::Resource';
requires 'File::Sync';
requires 'Test::Fake::HTTPD';
requires 'Test::TCP';
recommends 'Test::FTP::Server';

on 'configure' => sub { suggests 'Authen::PAM' };

#Test requirements
test_requires 'Test::More';
test_requires 'Test::Differences';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
