package App::lms::Command;
use v5.14;
use warnings;

my $DEBUG;
my $RAW;

sub get_path {
    my $app  = shift;
    my $name = shift;
    $DEBUG = $app->debug;
    $RAW   = $app->raw || $app->all;
    my @path = grep $app->valid($_), split /:/, $ENV{'PATH'};
    my @found = grep { -x $_ } map { "$_/$name" } @path;
    return @found if $RAW;
    map { resolve_homebrew_wrapper($_) }
    grep { defined }
    map { reject_pyenv_shim($_) }
    @found;
}

# pyenv shim は拒否して Python ハンドラに任せる
sub reject_pyenv_shim {
    my $path = shift;
    if ($path =~ m{/\.pyenv/shims/}) {
	warn "  Reject pyenv shim: $path\n" if $DEBUG;
	return;
    }
    return $path;
}

# Resolve Homebrew wrapper scripts to actual scripts
sub resolve_homebrew_wrapper {
    my $path = shift;

    # Check if it's in Homebrew bin directory
    return $path unless $path =~ m{^(/opt/homebrew|/usr/local)/bin/};
    my $prefix = $1;
    warn "  Check Homebrew wrapper: $path\n" if $DEBUG;

    # Check if it's a shell script wrapper
    open my $fh, '<', $path or return $path;
    my $shebang = <$fh>;
    return $path unless $shebang && $shebang =~ /^#!.*\b(ba)?sh\b/;

    # Look for exec line pointing to libexec
    while (<$fh>) {
        if (m{exec\s+["']?(\Q$prefix\E/(?:opt|Cellar)/[^"'\s]+/libexec/bin/\S+)}) {
            my $real_path = $1;
            $real_path =~ s/["'].*//;
            if (-x $real_path) {
                warn "  Resolved to: $real_path\n" if $DEBUG;
                return $real_path;
            }
        }
    }
    close $fh;

    return $path;
}

1;
