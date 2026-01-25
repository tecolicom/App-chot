package App::lms::Python;

use v5.14;
use warnings;
use Command::Run;

my $PYTHON;

sub get_path {
    my($app, $name) = @_;
    my $python = _find_python() or return;

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
    return $path if $path && -f $path;
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
