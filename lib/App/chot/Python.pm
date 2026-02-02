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

    # Validate module name (only allow word chars and dots)
    return if $name =~ /[^\w\.]/;

    my $code = <<"END";
import inspect
try:
    exec('import $name')
    path = inspect.getsourcefile(eval('$name'))
    if path:
        print(path)
except:
    pass
END

    my $path = Command::Run->new->command($python, '-c', $code)->update->data // return;
    chomp $path;
    if ($path && -f $path) {
        warn "  Found: $path\n" if $DEBUG;
        # If __init__.py is empty, look for alternative files
        if ($path =~ m{/__init__\.py$} && -z $path) {
            warn "  Empty __init__.py, searching alternatives\n" if $DEBUG;
            if (my $alt = _find_alternative($path, $name)) {
                warn "  Alternative: $alt\n" if $DEBUG;
                return $alt;
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

    # Search order: same-name module, __main__.py, other .py files
    my @candidates = (
        "$dir/$base.py",
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
