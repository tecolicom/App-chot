[![Actions Status](https://github.com/kaz-utashiro/App-lms/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kaz-utashiro/App-lms/actions?workflow=test)
# NAME

lms - Let Me See command

# VERSION

Version 0.99

# SYNOPSIS

      lms [options] command/library

    OPTIONS
       -1   --one           Stop at the first match
       -d   --debug         Show debug output
       -n   --dryrun        Show command without executing
       -h   --help          Print this message
       -l   --list          Print file path (-ll for ls -l)
       -m   --man           Show documentation
       -N   --[no-]number   Line number display (default: off)
       -r   --raw           Don't resolve Homebrew wrappers
       -v   --version       Print version
       -p   --pager=#       Specify pager command
       -t   --type=#        Specify handler (Command:Perl:Python:Ruby:Node)
            --py            Shortcut for --type Python
            --pl            Shortcut for --type Perl
            --rb            Shortcut for --type Ruby
            --nd            Shortcut for --type Node
            --bat-theme     Set bat theme per mode (light=X dark=X)

    EXAMPLES
      lms greple              # Look at a script command
      lms Getopt::Long        # Look at a Perl module
      lms --py json           # Look at a Python module
      lms --rb json           # Look at a Ruby library
      lms --nd express        # Look at a Node.js module
      lms -l greple           # Show file path only
      lms --py -m json        # Show documentation

# DESCRIPTION

**lms** (Let Me See) is a utility to locate and display command or library files.

It is convenient to see a command file written in shell or any other
script language.

For library files, Perl modules are fully supported, and support
for Python, Ruby, and Node.js libraries is included.

The program searches through all file type handlers (Command, Perl, Python,
Ruby, Node by default) and displays all matches found using a pager.

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
    \- Ruby: `ri`
    \- Node.js: `npm docs`
    \- Command: `man`

- **-N**, **--number**, **--no-number**

    Enable or disable line number display in the pager.  Default is
    `--no-number`.

    For `bat`, `--number` uses `--style=full` and `--no-number`
    uses `--style=header,grid,snip`.  For `less`, `--number` adds
    `-N` option.

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

    Default: `Command:Perl:Python:Ruby:Node`

    Available handlers:
    \- `Command`: Search for executable commands in `$PATH`
    \- `Perl`: Search for Perl modules in `@INC`
    \- `Python`: Search for Python libraries using Python's inspect module
    \- `Ruby`: Search for Ruby libraries using `$LOADED_FEATURES`
    \- `Node`: Search for Node.js modules using `require.resolve`

    Examples:
        lms --type Perl Getopt::Long       # Only search Perl modules
        lms --type python json             # Only search Python modules
        lms --type ruby yaml               # Only search Ruby libraries
        lms --type node express            # Only search Node.js modules

- **--py**

    Shortcut for `--type Python`. Search only Python modules.

- **--pl**

    Shortcut for `--type Perl`. Search only Perl modules.

- **--rb**

    Shortcut for `--type Ruby`. Search only Ruby libraries.

- **--nd**

    Shortcut for `--type Node`. Search only Node.js modules.

- **--bat-theme** _mode_=_theme_

    Specify the default bat theme for light or dark terminal backgrounds.
    Can be used multiple times.

        --bat-theme light=GitHub --bat-theme dark=Monokai

    If `bat` is used as the pager and `BAT_THEME` is not set, the
    terminal background luminance is detected and the appropriate theme
    is applied.  Built-in defaults are `Coldark-Cold` for light and
    `Coldark-Dark` for dark backgrounds.

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

- **App::lms::Ruby**

    Handler for Ruby libraries. Loads the specified library with `require`
    and inspects `$LOADED_FEATURES` to find the actual file path.
    Documentation is displayed using `ri`.

- **App::lms::Node**

    Handler for Node.js modules. Uses `require.resolve` with global paths
    to locate module entry points.
    Documentation is opened via `npm docs`.

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

    # Show documentation (perldoc for Perl, pydoc for Python, ri for Ruby, etc.)
    lms -m List::Util
    lms --py -m json
    lms --rb -m json
    lms -m ls

    # Only search for Perl modules
    lms --pl Data::Dumper

    # Only search for Python modules
    lms --py os.path

    # Display a Ruby library
    lms --rb yaml

    # Display a Node.js module
    lms --nd express

    # Use a custom pager
    lms --pager "vim -R" List::Util

    # Pass options to the pager (use -- to separate)
    lms -- +10 List::Util  # Open at line 10

# INSTALLATION

    # Homebrew
    brew tap tecolicom/tap
    brew install app-lms

    # From CPAN
    cpanm App::lms

    # From GitHub
    cpanm https://github.com/kaz-utashiro/App-lms.git

# ENVIRONMENT

- **LMS\_PAGER**

    Default pager command to use when displaying files.
    If not set, `bat` is used if available, otherwise `less`.

- **BAT\_THEME**

    Theme for `bat` pager.  If set, takes precedence over `--bat-theme`
    option and automatic detection.  See `bat --list-themes` for available
    themes.

- **OPTEX\_BINDIR**

    If set, overrides the default skip pattern for the `--skip` option.

# SEE ALSO

[App::lms](https://metacpan.org/pod/App%3A%3Alms), [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX), [Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed)

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 1992-2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
