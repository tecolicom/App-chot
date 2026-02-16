[![Actions Status](https://github.com/tecolicom/App-chot/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/tecolicom/App-chot/actions?workflow=test)
# NAME

chot - Command Heuristic Omni-Tracer

# VERSION

Version 1.03

# SYNOPSIS

      chot [options] command/library

    OPTIONS
       -1   --one           Stop at the first match
       -d   --debug         Show debug output
       -i   --info          Show command trace info
       -n   --dryrun        Show command without executing
       -h   --help          Print this message
       -l   --list          Print file path (-ll for ls -l)
       -L   --deref         Dereference symlinks (with -ll)
       -m   --man           Show documentation
       -N   --[no-]number   Line number display (default: off)
       -r   --raw           Don't resolve symlinks/wrappers
       -v   --version       Print version
       -p   --pager=#       Specify pager command
       -t   --type=#        Specify handler (Command:Perl:Python:Ruby:Node)
            --py            Shortcut for --type Python
            --pl            Shortcut for --type Perl
            --rb            Shortcut for --type Ruby
            --nd            Shortcut for --type Node
            --bat-theme     Set bat theme per mode (light=X dark=X)

    EXAMPLES
      chot greple              # Look at a script command
      chot Getopt::Long        # Look at a Perl module
      chot --py json           # Look at a Python module
      chot --rb json           # Look at a Ruby library
      chot --nd express        # Look at a Node.js module
      chot -l greple           # Show file path only
      chot --py -m json        # Show documentation

# DESCRIPTION

**chot** is a utility to locate and display command or library source files.

It is convenient to see a command file written in shell or any other
script language.

For library files, Perl modules are fully supported, and support
for Python, Ruby, and Node.js libraries is included.

The program searches through all file type handlers (Command, Perl, Python,
Ruby, Node by default) and displays all matches found using a pager.

For Homebrew-installed commands, both the wrapper script in `bin/` and
the actual executable (typically in `libexec/`) are displayed. This is
useful for understanding how wrapper scripts delegate to their
implementations.

For [optex](https://metacpan.org/pod/App%3A%3Aoptex) commands (symlinks in `~/.optex.d/bin/`
pointing to the `optex` binary), the actual command is resolved by
searching `$PATH`.  If an alias is defined in
`~/.optex.d/config.toml`, the alias target is followed.
Configuration files (`~/.optex.d/NAME.rc`) are also included in
the results.  Use `-i` to see the full resolution chain including
alias definitions.

# TRACING MECHANISM

**chot** traces commands and libraries through multiple layers of
indirection to find the actual source files.

## Command Tracing

The Command handler resolves commands through the following pipeline:

    PATH search → optex resolution → pyenv shim resolution → Homebrew wrapper resolution

- 1. **PATH search**

    Searches `$PATH` directories for executable files matching the given
    name.

- 2. **optex resolution**

    If the found path is a symlink to the [optex](https://metacpan.org/pod/App%3A%3Aoptex) binary
    (typically in `~/.optex.d/bin/`), resolves it to the actual command
    by searching `$PATH` (skipping other optex symlinks).  Alias
    definitions in `~/.optex.d/config.toml` and configuration files
    (`~/.optex.d/NAME.rc`) are also included.

- 3. **pyenv shim resolution**

    If the path is a pyenv shim (in `~/.pyenv/shims/`), resolves it to
    the actual executable using `pyenv which`.  Both the shim and the
    resolved path are included in the output.

- 4. **Homebrew wrapper resolution**

    If the path is in a Homebrew prefix (e.g., `/opt/homebrew/bin/`),
    checks whether it is a shell wrapper that delegates to another
    script within the same Homebrew prefix (e.g., in `libexec/bin/` or
    `libexec/venv/bin/`).  If so, both the wrapper and the actual script
    are included.

## Python Module Tracing

The Python handler performs additional resolution to locate meaningful
source files:

- **Name normalization**

    Hyphens in command names are converted to underscores for Python
    module lookup (e.g., `pandoc-embedz` is searched as `pandoc_embedz`).
    This follows the Python packaging convention where distribution names
    use hyphens but module names use underscores.

- **Interpreter fallback**

    When the default `python3` cannot import a module (e.g., packages
    installed only in a Homebrew venv or a specific virtual environment),
    the handler examines shebang lines of previously discovered paths to
    find the appropriate Python interpreter and retries the import.
    This enables tracing of Homebrew-installed Python commands whose
    packages are isolated in `libexec/venv/`.

- **Entry point resolution**

    When the Python module resolves to an `__init__.py` file, the handler
    searches for a more substantive source file in this order:

    - 1. A file matching the module name (e.g., `gpty.py` for `gpty`)
    - 2. `main.py` (common entry point for CLI tools)
    - 3. `__main__.py`
    - 4. The first non-empty `.py` file in the package directory

    If `__init__.py` is empty, only the alternative file is returned.
    If `__init__.py` has content, both files are included.

## Examples

For a Homebrew-installed Python command `pandoc-embedz`:

    $ chot -l pandoc-embedz
    /opt/homebrew/bin/pandoc-embedz               # Homebrew wrapper
    .../libexec/venv/bin/pandoc-embedz            # venv entry point
    .../pandoc_embedz/__init__.py                 # package init
    .../pandoc_embedz/main.py                     # main source

For a pyenv-installed Python command:

    $ chot -l gpty
    /Users/you/.pyenv/shims/gpty                  # pyenv shim
    /Users/you/.pyenv/versions/.../bin/gpty       # actual entry point
    .../gpty/gpty.py                              # main source

# OPTIONS

- **-1**, **--one**

    Stop at the first handler that finds a match, instead of searching
    all handlers (which is the default behavior).

- **-d**, **--debug**

    Show debug output on stderr. Displays which handlers are tried
    and how paths are resolved.

- **-i**, **--info**

    Show command trace information without displaying file contents.
    For each command found, displays its type (optex symlink, Homebrew
    wrapper, plain command, etc.), file type (perl, bash, binary, etc.),
    and resolution chain. For optex commands, also shows alias
    definitions and rc file locations.

- **-n**, **--dryrun**

    Show the command that would be executed without actually running it.

- **-h**, **--help**

    Display this help message and exit.

- **-l**, **--list**

    Print file path instead of displaying the file contents.
    Use multiple times (`-ll`) to call `ls -l` for detailed file information.

- **-L**, **--deref**

    Dereference symlinks when listing with `-ll`.
    Passes `-L` to `ls` so that the target file's information is shown
    instead of the symlink itself.

- **-m**, **--man**

    Display manual/documentation using the appropriate tool for each
    language:

        Command:  man
        Perl:     perldoc
        Python:   pydoc
        Ruby:     ri
        Node.js:  npm docs

    If the first handler's documentation is not available (e.g., no man
    page exists), the next handler is tried automatically.  For example,
    a Python command without a man page will fall back to `pydoc`.

- **-N**, **--number**, **--no-number**

    Enable or disable line number display in the pager.  Default is
    `--no-number`.

    For `bat`, `--number` uses `--style=full` and `--no-number`
    uses `--style=header,grid,snip`.  For `less`, `--number` adds
    `-N` option.

- **-r**, **--raw**

    Show raw paths without resolving optex symlinks, pyenv shims, or
    Homebrew wrapper scripts to their actual executables.

- **-v**, **--version**

    Display version information and exit.

- **-p**, **--pager** _command_

    Specify the pager command to use for displaying files.
    Defaults to the `$CHOT_PAGER` environment variable, or `bat` if available,
    otherwise `less`.

    When multiple files are found, `bat` displays all files continuously
    with syntax highlighting. With `less`, use `:n` to navigate to the
    next file and `:p` for the previous file.

- **-t**, **--type** _handler\[:handler:...\]_

    Specify which file type handlers to use and in what order.
    Handlers are specified as colon-separated names (case-insensitive).

    Default: `Command:Perl:Python:Ruby:Node`

    Available handlers:

        Command   Search for executable commands in $PATH
        Perl      Search for Perl modules in @INC
        Python    Search for Python libraries using inspect module
        Ruby      Search for Ruby libraries using $LOADED_FEATURES
        Node      Search for Node.js modules using require.resolve

    Examples:

        chot --type Perl Getopt::Long       # Only search Perl modules
        chot --type python json             # Only search Python modules
        chot --type ruby yaml               # Only search Ruby libraries
        chot --type node express            # Only search Node.js modules

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

    Default: none (optex symlinks are resolved automatically)

# HANDLER MODULES

The program uses a plugin architecture where different file type handlers
are dynamically loaded based on the `--type` option. Each handler must
implement a `get_path($app, $name)` method.

- **App::chot::Command**

    Handler for executable commands. Searches through `$PATH` environment
    variable to find executable files.

    For [optex](https://metacpan.org/pod/App%3A%3Aoptex) symlinks (commands that are symlinks pointing
    to the `optex` binary), the handler resolves them to the actual
    command by searching `$PATH` (skipping other optex symlinks). If the
    command has an alias defined in `~/.optex.d/config.toml`, the alias
    target is used for resolution. When a `~/.optex.d/NAME.rc`
    configuration file exists, it is included in the results.

- **App::chot::Perl**

    Handler for Perl modules. Searches through `@INC` paths to find
    Perl module files (.pm and .pl files).

- **App::chot::Python**

    Handler for Python libraries. Executes Python's `inspect.getsourcefile()`
    function to locate Python module files.  When the default `python3`
    cannot find a module, falls back to interpreters discovered from
    shebang lines of previously found paths (e.g., Homebrew venv Python).

- **App::chot::Ruby**

    Handler for Ruby libraries. Loads the specified library with `require`
    and inspects `$LOADED_FEATURES` to find the actual file path.
    Documentation is displayed using `ri`.

- **App::chot::Node**

    Handler for Node.js modules. Uses `require.resolve` with global paths
    to locate module entry points.
    Documentation is opened via `npm docs`.

# EXAMPLES

    # Display a script command (brew is a shell script)
    chot brew

    # Display a Perl module
    chot List::Util

    # Display a Python module
    chot --py json

    # Just show the file path
    chot -l brew

    # Show detailed file information
    chot -ll Getopt::Long

    # Show documentation (perldoc for Perl, pydoc for Python, ri for Ruby, etc.)
    chot -m List::Util
    chot --py -m json
    chot --rb -m json
    chot -m ls

    # Only search for Perl modules
    chot --pl Data::Dumper

    # Only search for Python modules
    chot --py os.path

    # Display a Ruby library
    chot --rb yaml

    # Display a Node.js module
    chot --nd express

    # Trace a Homebrew venv Python command
    chot -l pandoc-embedz

    # Show documentation with fallback (man → pydoc)
    chot -m speedtest-z

    # Use a custom pager
    chot --pager "vim -R" List::Util

    # Pass options to the pager (use -- to separate)
    chot -- +10 List::Util  # Open at line 10

# INSTALLATION

    # Homebrew
    brew tap tecolicom/tap
    brew install app-chot

    # From CPAN
    cpanm App::chot

    # From GitHub
    cpanm https://github.com/tecolicom/App-chot.git

# ENVIRONMENT

- **CHOT\_PAGER**

    Default pager command to use when displaying files.
    If not set, `bat` is used if available, otherwise `less`.

- **BAT\_THEME**

    Theme for `bat` pager.  If set, takes precedence over `--bat-theme`
    option and automatic detection.  See `bat --list-themes` for available
    themes.

- **OPTEX\_ROOT**

    Root directory for optex configuration.  Defaults to `~/.optex.d`.
    Used to locate `config.toml` and `*.rc` files for optex command
    resolution.

# BUGS

When inspecting itself with `chot chot`, the display order of the
wrapper script and the actual executable may be reversed.  This is
because the wrapper adds `libexec/bin` to `$PATH`, causing the
raw executable to be found before the wrapper during path search.

# SEE ALSO

[App::chot](https://metacpan.org/pod/App%3A%3Achot), [App::optex](https://metacpan.org/pod/App%3A%3Aoptex), [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX), [Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed)

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 1992-2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
