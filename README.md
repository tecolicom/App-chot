[![Actions Status](https://github.com/kaz-utashiro/App-lms/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kaz-utashiro/App-lms/actions?workflow=test)
# NAME

lms - Let Me See command

# VERSION

Version 0.14

# SYNOPSIS

    lms [options] command/library

    # Look at a script command
    lms greple

    # Look at a Perl module
    lms Getopt::Long

    # Look at a Python module
    lms --py json

    # Show file path only
    lms -l greple

    # Show documentation
    lms --py -m json

# DESCRIPTION

**lms** (Let Me See) is a utility to locate and display command or library files.

It is convenient to see a command file written in shell or any other
script language.

For library files, Perl modules are fully supported, and experimental support
for Python libraries is included.

The program searches through all file type handlers (Command, Perl, Python
by default) and displays all matches found using a pager.

For Homebrew-installed commands, both the wrapper script in `bin/` and
the actual executable in `libexec/bin/` are displayed. This is useful
for understanding how wrapper scripts delegate to their implementations.

# OPTIONS

- **-1**, **--one**

    Stop at the first handler that finds a match, instead of searching
    all handlers (which is the default behavior).

- **-d**, **--debug**

    Show debug output on stderr. Displays which handlers are tried
    and how paths are resolved.

- **-n**, **--dryrun**

    Show the command that would be executed without actually running it.

- **-h**, **--help**

    Display this help message and exit.

- **-l**, **--list**

    Print module path instead of displaying the file contents.
    Use multiple times (`-ll`) to call `ls -l` for detailed file information.

- **-m**, **--man**

    Display manual/documentation using the appropriate tool for each language:
    \- Perl: `perldoc`
    \- Python: `pydoc`
    \- Command: `man`

- **-r**, **--raw**

    Show raw paths without resolving Homebrew wrapper scripts to
    their actual executables.

- **-v**, **--version**

    Display version information and exit.

- **-p**, **--pager** _command_

    Specify the pager command to use for displaying files.
    Defaults to the `$LMS_PAGER` environment variable, or `bat` if available,
    otherwise `less`.

    When multiple files are found, `bat` displays all files continuously
    with syntax highlighting. With `less`, use `:n` to navigate to the
    next file and `:p` for the previous file.

- **-t**, **--type** _handler\[:handler:...\]_

    Specify which file type handlers to use and in what order.
    Handlers are specified as colon-separated names (case-insensitive).

    Default: `Command:Perl:Python`

    Available handlers:
    \- `Command`: Search for executable commands in `$PATH`
    \- `Perl`: Search for Perl modules in `@INC`
    \- `Python`: Search for Python libraries using Python's inspect module

    Examples:
        lms --type Perl Getopt::Long       # Only search Perl modules
        lms --type python json             # Only search Python modules

- **--py**

    Shortcut for `--type Python`. Search only Python modules.

- **--pl**

    Shortcut for `--type Perl`. Search only Perl modules.

- **--suffix** _extension_

    Specify file suffix/extension to search for (mainly for Perl modules).

    Default: `.pm`

- **--skip** _pattern_

    Specify directory patterns to skip during search.
    Can be used multiple times to specify multiple patterns.

    Default: `.optex.d/bin` (or `$OPTEX_BINDIR` if set)

# HANDLER MODULES

The program uses a plugin architecture where different file type handlers
are dynamically loaded based on the `--type` option. Each handler must
implement a `get_path($app, $name)` method.

- **App::lms::Command**

    Handler for executable commands. Searches through `$PATH` environment
    variable to find executable files.

- **App::lms::Perl**

    Handler for Perl modules. Searches through `@INC` paths to find
    Perl module files (.pm and .pl files).

- **App::lms::Python**

    Handler for Python libraries. Executes Python's `inspect.getsourcefile()`
    function to locate Python module files.

# EXAMPLES

    # Display a script command (brew is a shell script)
    lms brew

    # Display a Perl module
    lms List::Util

    # Display a Python module
    lms --py json

    # Just show the file path
    lms -l brew

    # Show detailed file information
    lms -ll Getopt::Long

    # Show documentation (perldoc for Perl, pydoc for Python, man for commands)
    lms -m List::Util
    lms --py -m json
    lms -m ls

    # Only search for Perl modules
    lms --pl Data::Dumper

    # Only search for Python modules
    lms --py os.path

    # Use a custom pager
    lms --pager "vim -R" List::Util

    # Pass options to the pager (use -- to separate)
    lms -- +10 List::Util  # Open at line 10

# INSTALLATION

    # From CPAN
    cpanm App::lms

    # From GitHub
    cpanm https://github.com/kaz-utashiro/App-lms.git

    # From source
    git clone https://github.com/kaz-utashiro/App-lms.git
    cd App-lms
    cpanm --installdeps .
    cpanm .

# ENVIRONMENT

- **LMS\_PAGER**

    Default pager command to use when displaying files.
    If not set, `bat` is used if available, otherwise `less`.

- **OPTEX\_BINDIR**

    If set, overrides the default skip pattern for the `--skip` option.

# SEE ALSO

[App::lms](https://metacpan.org/pod/App%3A%3Alms), [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX), [Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed)

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 1992- Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
