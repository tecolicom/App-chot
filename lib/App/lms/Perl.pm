package App::lms::Perl;
use v5.14;
use warnings;

sub get_path {
    my $app  = shift;
    my $name = shift;

    grep { -f $_ and -r $_ }
    map  { s[::][/]gr }
    map  { ( "$_/$name", "$_/$name.pm", "$_/$name.pl" ) }
    grep { $app->valid($_) }
    ( @INC, homebrew_perl_libs() );
}

sub homebrew_perl_libs {
    my $prefix = $ENV{HOMEBREW_PREFIX}
              // (-d '/opt/homebrew' ? '/opt/homebrew' : undef)
              // (-d '/usr/local/Homebrew' ? '/usr/local' : undef)
              // return;

    # Search in opt/*/libexec/lib/perl5
    glob("$prefix/opt/*/libexec/lib/perl5");
}

1;
