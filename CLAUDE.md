# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

App-chot is a Perl utility that locates and displays command/library files. The `chot` command can find executable commands, Perl modules, and Python libraries, then display them using a pager.

## Build System

This project uses **Minilla** for release management and **Module::Build::Tiny** for building.

### Essential Commands

```bash
# Install dependencies
cpanm --installdeps .

# Run tests
prove -lv t

# Install from source
cpanm .

# Install directly from GitHub
cpanm https://github.com/tecolicom/App-chot.git
```

### Release Management

The project uses Dist::Zilla/Minilla. Key files are auto-generated:
- `Build.PL` - Auto-generated, do not edit directly
- `README.md` - Auto-generated from `script/chot` POD documentation
- Version numbers must be updated in both `script/chot` and `lib/App/chot.pm`

## Architecture

### Plugin System

The application uses a plugin architecture where different file type handlers are dynamically loaded:

1. **Main Entry Point** (`script/chot`): Minimal wrapper that invokes `App::chot->run()`

2. **Core Module** (`lib/App/chot.pm`):
   - Uses `Getopt::EX::Hashed` for configuration with assignable accessors
   - Dynamically loads handler modules based on `--type` option (default: `Command:Perl:Python`)
   - Each handler module must implement `get_path($app, $name)` method
   - Filters results through `valid()` method to skip directories in `--skip` option

3. **Handler Modules**:
   - `App::chot::Command` - Searches `$PATH` for executable commands
   - `App::chot::Perl` - Searches `@INC` for Perl modules (.pm/.pl files)
   - `App::chot::Python` - Uses Inline::Python to call `inspect.getsourcefile()` for Python modules

4. **Utilities** (`lib/App/chot/Util.pm`): Provides `is_binary()` to detect binary files

### Key Architecture Patterns

- Handler modules are required dynamically: `eval "require App::chot::$type"`
- Handler methods are called via symbolic reference: `&{"$_\::get_path"}($app, $name)`
- The `--type` option accepts colon-separated handler names, each tried in order
- Results are filtered to exclude paths matching `--skip` patterns (default: `.optex.d/bin`)

### Getopt::EX Integration

This project heavily uses the Getopt::EX framework:
- `Getopt::EX::Hashed` provides the configuration object with accessor methods
- `Getopt::EX::Long` extends standard option parsing
- `ExConfigure BASECLASS` allows loading external option modules from `App::chot::*` and `Getopt::EX::*`

## Testing

- Test files are in `t/` directory
- CI runs tests on Perl versions: 5.30, 5.28, 5.18, 5.14
- Minimum Perl version: v5.14.0

## Python Support

The `App::chot::Python` module is experimental and uses the `Inline::Python` module to execute Python code from Perl. It creates a `~/.Inline` directory on first use to cache compiled Python bindings.
