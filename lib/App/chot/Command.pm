package App::chot::Command;
use v5.14;
use warnings;

use App::chot::Optex qw(detect_optex resolve_optex);
use File::Basename qw(basename dirname);

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
    my @resolved =
    map { resolve_homebrew_wrapper($_) }
    map { detect_pyenv_shim($_) }
    map { resolve_optex_command($app, $name, $_) }
    @found;
    _uniq(@resolved);
}

sub _uniq {
    my %seen;
    grep { !$seen{$_}++ } @_;
}

sub get_info {
    my $app  = shift;
    my $name = shift;
    $DEBUG = $app->debug;
    my @path = grep $app->valid($_), split /:/, $ENV{'PATH'};
    my @found = grep { -x $_ } map { "$_/$name" } @path;
    my %shown;
    for my $path (@found) {
        next if $shown{$path}++;
        if (detect_optex($path)) {
            _info_optex($app, $name, $path, \%shown);
        } elsif ($path =~ m{/\.pyenv/shims/}) {
            _info_pyenv($name, $path, \%shown);
        } elsif (my $prefix = homebrew_prefix($path)) {
            _info_homebrew($path, $prefix);
        } else {
            printf "  %-12s %s (%s)\n", "command:", $path, _file_type($path);
        }
    }
    return;
}

sub _info_optex {
    my($app, $name, $path, $shown) = @_;
    my $target = readlink($path) // '';
    printf "  %-12s %s -> %s\n", "optex:", $path, $target;

    # alias
    require App::chot::Optex;
    my $alias_val = App::chot::Optex::_get_alias($name);
    if (defined $alias_val) {
        App::chot::Optex::_print_alias($name, $alias_val);
    }

    # real command
    my $resolved_name = App::chot::Optex::_alias_command($alias_val) // $name;
    my @real = App::chot::Optex::_find_real_command($resolved_name);
    for my $r (@real) {
        $shown->{$r}++;
        if (my $prefix = homebrew_prefix($r)) {
            _info_homebrew($r, $prefix);
        } else {
            printf "  %-12s %s (%s)\n", "command:", $r, _file_type($r);
        }
    }

    # rc file
    my $optex_dir = App::chot::Optex::_optex_dir();
    my $rc = "$optex_dir/$name.rc";
    if (-f $rc) {
        printf "  %-12s %s\n", "rc:", $rc;
    }
}

sub _info_pyenv {
    my($name, $path, $shown) = @_;
    printf "  %-12s %s\n", "pyenv shim:", $path;
    my $real = `pyenv which \Q$name\E 2>/dev/null`;
    chomp $real;
    if ($real && -x $real) {
        $shown->{$real}++;
        printf "  %-12s %s (%s)\n", "->", $real, _file_type($real);
    }
}

sub _info_homebrew {
    my($path, $prefix) = @_;
    # Check if it's a wrapper
    open my $fh, '<', $path or do {
        printf "  %-12s %s (%s)\n", "homebrew:", $path, _file_type($path);
        return;
    };
    my $shebang = <$fh>;
    if ($shebang && $shebang =~ /^#!.*\b(ba)?sh\b/) {
        while (<$fh>) {
            if (m{exec\s+["']?(\Q$prefix\E/(?:opt|Cellar)/[^"'\s]+/libexec/bin/\S+)}) {
                my $real_path = $1;
                $real_path =~ s/["'].*//;
                if (-x $real_path) {
                    printf "  %-12s %s (wrapper)\n", "homebrew:", $path;
                    printf "  %-12s %s (%s)\n", "->", $real_path, _file_type($real_path);
                    close $fh;
                    return;
                }
            }
        }
    }
    close $fh;
    printf "  %-12s %s (%s)\n", "homebrew:", $path, _file_type($path);
}

sub _file_type {
    my $path = shift;
    use File::Spec;
    while (-l $path) {
        my $link = readlink($path) // last;
        $path = File::Spec->rel2abs($link, dirname($path));
    }
    open my $fh, '<', $path or return '?';
    my $shebang = <$fh>;
    close $fh;
    return 'binary' if !$shebang || $shebang =~ /[\0\377]/;
    return $1 if $shebang =~ /^#!.*\b(perl|python\d?|ruby|bash|sh|zsh|node)\b/;
    return 'shell script' if $shebang =~ /^#!/;
    return 'text';
}

sub resolve_optex_command {
    my($app, $name, $path) = @_;
    return $path unless detect_optex($path);
    resolve_optex($app, $name, $path);
}

# pyenv shim を検出して実体を解決
sub detect_pyenv_shim {
    my $path = shift;
    return $path unless $path =~ m{/\.pyenv/shims/(.+)};
    my $name = $1;
    warn "  Found pyenv shim: $path\n" if $DEBUG;
    return $path if $RAW;
    my $real = `pyenv which \Q$name\E 2>/dev/null`;
    chomp $real;
    if ($real && -x $real) {
	warn "  Resolved pyenv shim: $real\n" if $DEBUG;
	return ($path, $real);
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
