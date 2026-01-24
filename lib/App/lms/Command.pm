package App::lms::Command;
use v5.14;
use warnings;

my @path = split /:+/, $ENV{'PATH'};

sub get_path {
    my $app  = shift;
    my $name = shift;
    my @path = grep $app->valid($_), split /:/, $ENV{'PATH'};
    map { resolve_homebrew_wrapper($_) }
    grep { -x $_ } map { "$_/$name" } @path;
}

# Resolve Homebrew wrapper scripts to actual scripts
sub resolve_homebrew_wrapper {
    my $path = shift;

    # Check if it's in Homebrew bin directory
    return $path unless $path =~ m{^(/opt/homebrew|/usr/local)/bin/};
    my $prefix = $1;

    # Check if it's a shell script wrapper
    open my $fh, '<', $path or return $path;
    my $shebang = <$fh>;
    return $path unless $shebang && $shebang =~ /^#!.*\b(ba)?sh\b/;

    # Look for exec line pointing to libexec
    while (<$fh>) {
        if (m{exec\s+["']?(\Q$prefix\E/(?:opt|Cellar)/[^"'\s]+/libexec/bin/\S+)}) {
            my $real_path = $1;
            $real_path =~ s/["'].*//;
            return $real_path if -x $real_path;
        }
    }
    close $fh;

    return $path;
}

1;
