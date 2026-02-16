package App::chot::Python;

use v5.14;
use warnings;

use parent 'App::chot::Finder';

use Command::Run;

#
# Build pydoc command for -m mode.
# Selects Python interpreter from shebang of previously found paths
# (via context) so that venv packages are accessible.
#
sub man_cmd {
    my $self = shift;
    (my $module = $self->name) =~ s/-/_/g;
    my $python = $self->_find_python // 'python3';
    # Prefer interpreter from shebang of found paths (e.g., Homebrew venv python)
    my $found = $self->found->paths;
    for my $p (@$found) {
        next unless -f $p && -r $p;
        if (my $shebang_python = _extract_python_from_shebang($p)) {
            $python = $shebang_python;
            last;
        }
    }
    return ($python, '-m', 'pydoc', $module);
}

#
# Find Python module source file via inspect.getsourcefile().
# Normalizes hyphens to underscores (Python packaging convention).
# Falls back to shebang-discovered interpreters from context->found_paths
# when the default python3 can't import the module (e.g., venv packages).
#
sub get_path {
    my $self = shift;
    my $python = $self->_find_python or do {
        warn "  Python not found\n" if $self->debug;
        return;
    };
    warn "  Using: $python\n" if $self->debug;

    # Normalize: Python module names use underscores, not hyphens
    (my $module = $self->name) =~ s/-/_/g;

    # Validate module name (only allow word chars and dots)
    return if $module =~ /[^\w\.]/;

    # Try with default python first
    my $debug = $self->debug;
    my @result = _import_source($python, $module, $debug);
    if (@result) {
        return @result;
    }

    # Fallback: try python interpreters found in shebang of previously discovered paths
    my $found = $self->found->paths;
    for my $path (@$found) {
        next unless -f $path && -r $path;
        my $shebang_python = _extract_python_from_shebang($path) or next;
        warn "  Trying shebang python: $shebang_python (from $path)\n" if $debug;
        @result = _import_source($shebang_python, $module, $debug);
        if (@result) {
            return @result;
        }
    }

    return;
}

#
# Pure function: run Python to get source file path via inspect.getsourcefile().
# If result is __init__.py, searches for a more meaningful entry point.
#
sub _import_source {
    my($python, $module, $debug) = @_;

    my $code = <<"END";
import inspect
try:
    exec('import $module')
    path = inspect.getsourcefile(eval('$module'))
    if path:
        print(path)
except:
    pass
END

    my $path = Command::Run->new->command($python, '-c', $code)->update->data // return;
    chomp $path;
    if ($path && -f $path) {
        warn "  Found: $path\n" if $debug;
        # If __init__.py, look for main entry point
        if ($path =~ m{/__init__\.py$}) {
            if (my $alt = _find_alternative($path, $module)) {
                warn "  Alternative: $alt\n" if $debug;
                return $alt if -z $path;  # skip empty __init__.py
                return ($path, $alt);
            }
        }
        return $path;
    }
    return;
}

#
# Pure function: extract Python interpreter path from shebang line.
# Handles both direct paths (#!/path/to/python3) and
# env (#!/usr/bin/env python3).
#
sub _extract_python_from_shebang {
    my $path = shift;
    open my $fh, '<', $path or return;
    my $line = <$fh>;
    close $fh;
    return unless defined $line && $line =~ /^#!/;
    # Direct path: #!/path/to/python3
    if ($line =~ m{^#!\s*(/\S*python\S*)}) {
        my $python = $1;
        return $python if -x $python;
    }
    # env: #!/usr/bin/env python3
    if ($line =~ m{^#!\s*/\S*env\s+(python\S*)}) {
        my $cmd = $1;
        my $resolved = Command::Run->new->command('which', $cmd)->update->data // return;
        chomp $resolved;
        return $resolved if $resolved && -x $resolved;
    }
    return;
}

#
# Pure function: when __init__.py is found, search for a more meaningful
# entry point in the package directory.
# Search order: $base.py, main.py, __main__.py, first non-empty .py file.
#
sub _find_alternative {
    my($init_path, $name) = @_;
    my $dir = $init_path;
    $dir =~ s{/__init__\.py$}{};

    # Get base module name (last component)
    my $base = $name;
    $base =~ s/.*\.//;

    # Search order: same-name module, main.py, __main__.py
    my @candidates = (
        "$dir/$base.py",
        "$dir/main.py",
        "$dir/__main__.py",
    );

    for my $candidate (@candidates) {
        if (-f $candidate && -s $candidate) {
            return $candidate;
        }
    }

    # Fallback: first non-empty .py file (excluding __init__.py)
    if (opendir my $dh, $dir) {
        for my $file (sort readdir $dh) {
            next unless $file =~ /\.py$/;
            next if $file eq '__init__.py';
            my $path = "$dir/$file";
            if (-f $path && -s $path) {
                return $path;
            }
        }
    }

    return;
}

#
# Find available Python interpreter.
# Result is cached per instance in $self->{_python}.
# Returns empty string (falsy) if neither python3 nor python is available.
#
sub _find_python {
    my $self = shift;
    return $self->{_python} if defined $self->{_python};

    for my $cmd (qw(python3 python)) {
        Command::Run->new->command('which', $cmd)->update->data
            and return $self->{_python} = $cmd;
    }
    return $self->{_python} = '';
}

1;
