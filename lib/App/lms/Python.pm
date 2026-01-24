package App::lms::Python;

use v5.14;
use warnings;

my $PYTHON_AVAILABLE;

sub get_path {
    my($app, $name) = @_;
    return unless _init_python();
    getsourcefile($name);
}

sub _init_python {
    return $PYTHON_AVAILABLE if defined $PYTHON_AVAILABLE;

    my $dir = "$ENV{HOME}/.Inline";
    unless (-d $dir) {
        mkdir $dir or do {
            warn "Cannot create $dir: $!\n";
            return $PYTHON_AVAILABLE = 0;
        };
    }

    eval {
        require Inline;
        Inline->import(Config => directory => $dir);
        Inline->import(Python => <<'END');

import re
import inspect

def getsourcefile(name):
    if re.search(r'[^\w\.]', name):
        return
    try:
        exec('import ' + name)
    except:
        return
    return inspect.getsourcefile(eval(name))

import os
import sys

def find_module_file(module_name):
    for path in sys.path:
        file_path = os.path.join(path, module_name.replace('.', os.sep) + ".py")
        if os.path.isfile(file_path):
            return file_path
    return None

END
        1;
    } or do {
        # Inline::Python not available, silently disable Python support
        return $PYTHON_AVAILABLE = 0;
    };

    $PYTHON_AVAILABLE = 1;
}

1;
