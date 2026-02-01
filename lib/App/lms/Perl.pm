package App::lms::Perl;
use v5.14;
use warnings;
use Digest::MD5;

my $DEBUG;

sub man_cmd {
    my($app, $name, $path) = @_;
    return ('perldoc', '-F', $path);
}

sub get_path {
    my $app  = shift;
    my $name = shift;
    $DEBUG = $app->debug;

    my @libs = grep { $app->valid($_) } ( @INC, homebrew_perl_libs() );
    warn "  Searching in " . scalar(@libs) . " directories\n" if $DEBUG;

    my @found =
    grep { -f $_ and -r $_ }
    map  { s[::][/]gr }
    map  { ( "$_/$name", "$_/$name.pm", "$_/$name.pl" ) }
    @libs;

    warn "  Found: @found\n" if $DEBUG && @found;

    # Deduplicate files with identical content
    my %seen;
    @found = grep {
        open my $fh, '<', $_ or return 1;
        my $hash = Digest::MD5->new->addfile($fh)->hexdigest;
        !$seen{$hash}++;
    } @found;

    return @found;
}

sub homebrew_perl_libs {
    my $prefix = $ENV{HOMEBREW_PREFIX}
              // (-d '/opt/homebrew' ? '/opt/homebrew' : undef)
              // (-d '/usr/local/Homebrew' ? '/usr/local' : undef)
              // (-d '/home/linuxbrew/.linuxbrew' ? '/home/linuxbrew/.linuxbrew' : undef)
              // return;

    # Search in opt/*/libexec/lib/perl5
    glob("$prefix/opt/*/libexec/lib/perl5");
}

1;
