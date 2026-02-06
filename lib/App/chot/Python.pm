package App::chot::Python;

use v5.14;
use warnings;
use Command::Run;

my $PYTHON;
my $DEBUG;

sub man_cmd {
    my($app, $name, $path) = @_;
    return ('python3', '-m', 'pydoc', $name);
}

sub get_path {
    my($app, $name) = @_;
    $DEBUG = $app->debug;
    my $python = _find_python() or do {
        warn "  Python not found\n" if $DEBUG;
        return;
    };
    warn "  Using: $python\n" if $DEBUG;

    # Normalize: Python module names use underscores, not hyphens
    (my $module = $name) =~ s/-/_/g;

    # Validate module name (only allow word chars and dots)
    return if $module =~ /[^\w\.]/;

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
        warn "  Found: $path\n" if $DEBUG;
        # If __init__.py, look for main entry point
        if ($path =~ m{/__init__\.py$}) {
            if (my $alt = _find_alternative($path, $module)) {
                warn "  Alternative: $alt\n" if $DEBUG;
                return $alt if -z $path;  # skip empty __init__.py
                return ($path, $alt);
            }
        }
        return $path;
    }
    return;
}

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

sub _find_python {
    return $PYTHON if defined $PYTHON;

    for my $cmd (qw(python3 python)) {
        Command::Run->new->command('which', $cmd)->update->data
            and return $PYTHON = $cmd;
    }
    return $PYTHON = '';
}

1;
