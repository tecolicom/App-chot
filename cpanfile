requires 'Encode';
requires 'Getopt::EX::Long';
requires 'List::Util';
requires 'Getopt::EX::Hashed', '1.05';
requires 'Pod::Usage';
requires 'Getopt::EX::termcolor';
requires 'Command::Run';
requires 'perl', 'v5.24';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test::More', '0.98';
};

