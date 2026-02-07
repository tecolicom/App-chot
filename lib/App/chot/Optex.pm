package App::chot::Optex;
use v5.14;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(detect_optex resolve_optex);

use File::Basename qw(basename dirname);

my $DEBUG;

sub _optex_dir {
    $ENV{OPTEX_ROOT} || "$ENV{HOME}/.optex.d";
}

sub detect_optex {
    my $path = shift;
    return unless -l $path;
    return if basename($path) eq 'optex'; # optex itself, not managed by optex
    my $target = readlink $path // return;
    basename($target) eq 'optex';
}

sub resolve_optex {
    my($app, $name, $path) = @_;
    $DEBUG = $app->debug;

    my $orig_name = $name;
    my @result;

    # 1. optex symlink found
    warn "  optex: $path\n";
    push @result, $path;

    # 2. Check alias in config.toml
    my $alias_val = _get_alias($name);
    if (defined $alias_val) {
        my $config = _optex_dir() . "/config.toml";
        warn "  config: $config\n";
        _print_alias($orig_name, $alias_val);
        my $alias_cmd = _alias_command($alias_val);
        if (defined $alias_cmd) {
            warn "  => $alias_cmd\n" if $DEBUG;
            $name = $alias_cmd;
        }
    }

    # Search for real command in PATH, skipping optex symlinks
    my @real = _find_real_command($name);
    if (@real) {
        warn "  optex resolved '$name' => @real\n" if $DEBUG;
        push @result, @real;
    } else {
        warn "  optex: real command not found for '$name'\n" if $DEBUG;
    }

    # Check for rc file (always use original name)
    my $rc = _optex_dir() . "/$orig_name.rc";
    if (-f $rc) {
        warn "  optex rc: $rc\n" if $DEBUG;
        push @result, $rc;
    }

    @result;
}

sub _find_real_command {
    my $name = shift;
    my @path = split /:/, $ENV{PATH};
    my @found;
    for my $dir (@path) {
        my $cmd = "$dir/$name";
        next unless -x $cmd && ! -d $cmd;
        next if detect_optex($cmd);
        push @found, $cmd;
    }
    @found;
}

my $_aliases;

sub _get_alias {
    my $name = shift;
    $_aliases //= _load_aliases();
    $_aliases->{$name};
}

sub _alias_command {
    my $val = shift // return;
    my $cmd;
    if (!ref $val) {
        ($cmd) = $val =~ /^(\S+)/;
    } elsif (ref $val eq 'ARRAY' && @$val) {
        $cmd = $val->[0];
    }
    return unless defined $cmd;
    # Skip wrapper commands (bash -c, env ..., exec ..., etc.)
    return if $cmd =~ m{^(?:.*/)?(?:(?:ba)?sh|env|exec|expr)$};
    return $cmd;
}

sub _print_alias {
    my($name, $val) = @_;
    if (!ref $val) {
        warn "  alias: $name = $val\n";
    } elsif (ref $val eq 'ARRAY') {
        require JSON::PP;
        my $json = JSON::PP->new->indent->space_after->canonical->encode($val);
        $json =~ s/\n$//;
        warn "  alias: $name = $json\n";
    }
}

sub _load_aliases {
    my $config = _optex_dir() . "/config.toml";
    return {} unless -f $config;

    # Try TOML module
    my $data = eval {
        require TOML;
        open my $fh, '<', $config or die "$config: $!\n";
        local $/;
        my $text = <$fh>;
        my($hash, $err) = TOML::from_toml($text);
        die $err if $err;
        $hash;
    };
    if ($data) {
        return $data->{alias} || {};
    }
    warn "  optex: TOML parse failed: $@\n" if $DEBUG && $@;

    # Fallback: simple parser for string aliases
    _parse_aliases_simple($config);
}

sub _parse_aliases_simple {
    my $config = shift;
    my %alias;
    open my $fh, '<', $config or return {};
    my $in_alias = 0;
    while (<$fh>) {
        chomp;
        if (/^\[alias\]/) {
            $in_alias = 1;
            next;
        }
        if (/^\[/) {
            $in_alias = 0;
            next;
        }
        next unless $in_alias;
        # Match simple string assignments: key = "value"
        if (/^\s*(\w[\w-]*)\s*=\s*"([^"]*)"/) {
            $alias{$1} = $2;
        }
    }
    \%alias;
}

1;
