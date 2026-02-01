package App::lms::Command;
use v5.14;
use warnings;

my $DEBUG;
my $RAW;

sub man_cmd {
    my($app, $name, $path) = @_;
    return ('man', $name);
}

sub get_path {
    my $app  = shift;
    my $name = shift;
    $DEBUG = $app->debug;
    $RAW   = $app->raw;
    my @path = grep $app->valid($_), split /:/, $ENV{'PATH'};
    my @found = grep { -x $_ } map { "$_/$name" } @path;
    return @found if $RAW;
    map { resolve_homebrew_wrapper($_) }
    map { detect_pyenv_shim($_) }
    @found;
}

# pyenv shim を検出してログ出力
sub detect_pyenv_shim {
    my $path = shift;
    if ($path =~ m{/\.pyenv/shims/}) {
	warn "  Found pyenv shim: $path\n" if $DEBUG;
    }
    return $path;
}

# Resolve Homebrew wrapper scripts to actual scripts
# Returns both wrapper and resolved path
sub resolve_homebrew_wrapper {
    my $path = shift;

    # Check if it's in Homebrew bin directory
    my $prefix = homebrew_prefix($path) // return $path;
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
                return ($path, $real_path);
            }
        }
    }
    close $fh;

    return $path;
}

sub homebrew_prefix {
    my $path = shift;
    if ($ENV{HOMEBREW_PREFIX} and $path =~ m{^\Q$ENV{HOMEBREW_PREFIX}\E/bin/}) {
        return $ENV{HOMEBREW_PREFIX};
    }
    for my $prefix ('/opt/homebrew', '/usr/local', '/home/linuxbrew/.linuxbrew') {
        return $prefix if $path =~ m{^\Q$prefix\E/bin/};
    }
    return undef;
}

1;
