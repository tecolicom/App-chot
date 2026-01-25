package App::lms::Python;

use v5.14;
use warnings;
use Command::Run;

my $PYTHON;
my $DEBUG;

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
        return $path;
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
