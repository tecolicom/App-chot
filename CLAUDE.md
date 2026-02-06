# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**chot** (Command Heuristic Omni-Tracer) is a Perl utility that locates and displays command and library source files. It traces the execution chain of commands through optex symlinks, Homebrew wrappers, pyenv shims, and aliases, then displays the source using a pager.

Supported handlers: Command, Perl, Python, Ruby, Node.

## Build System

This project uses **Minilla** for release management and **Module::Build::Tiny** for building.

```bash
cpanm --installdeps .   # Install dependencies
prove -lv t             # Run tests
minil build             # Build and update generated files (META.json, README.md)
minil test              # Run tests via Minilla
minil release           # Release (interactive, sets version)
```

Auto-generated files (do not edit directly):
- `Build.PL`, `README.md`, `META.json`
- Version is managed by `minil release`

## Architecture

### Plugin System

1. **Entry Point** (`script/chot`): Minimal wrapper calling `App::chot->run()`. POD documentation lives here.

2. **Core Module** (`lib/App/chot.pm`):
   - `Getopt::EX::Hashed` for option parsing with assignable accessors
   - Dynamically loads handler modules based on `--type` option
   - Three output modes: pager display (default), `-l` (list paths), `-i` (info/trace)
   - Filters optex symlinks from pager display via `detect_optex()`

3. **Handler Modules** (each implements `get_path($app, $name)`):
   - `App::chot::Command` - Searches `$PATH`, resolves optex/Homebrew/pyenv
   - `App::chot::Perl` - Searches `@INC` for .pm/.pl files
   - `App::chot::Python` - Uses `inspect.getsourcefile()` via python3; normalizes hyphens to underscores; traces `__init__.py` to `main.py` etc.
   - `App::chot::Ruby` - Uses `$LOADED_FEATURES` inspection
   - `App::chot::Node` - Uses `require.resolve` with global paths

4. **App::chot::Optex** (`lib/App/chot/Optex.pm`):
   - `detect_optex($path)` - Checks if path is a symlink to the optex binary
   - `resolve_optex($app, $name, $path)` - Resolves optex commands:
     - Loads aliases from `~/.optex.d/config.toml` (via TOML module, with simple fallback parser)
     - Finds real commands in PATH (skipping optex symlinks)
     - Locates `~/.optex.d/NAME.rc` files
   - Prints optex/config/alias info to stderr for visibility

5. **App::chot::Command** resolution pipeline (`get_path`):
   ```
   PATH search -> resolve_optex_command -> detect_pyenv_shim -> resolve_homebrew_wrapper -> _uniq
   ```
   `detect_pyenv_shim` resolves shims via `pyenv which` and returns both the shim and the real path.
   Also provides `get_info()` for `-i` mode with labeled output per path.

6. **Utilities** (`lib/App/chot/Util.pm`): `is_binary()` for binary file detection.

### Key Design Decisions

- `--skip` default is empty (was `.optex.d/bin`). Optex symlinks are now resolved rather than skipped.
- Optex symlinks are included in `-l` output but filtered before pager display.
- Alias resolution skips wrapper commands (`bash`, `sh`, `env`, `exec`, `expr`) as they don't represent real command targets.
- The `_aliases` cache is loaded once (lazy) from config.toml.
- `get_info()` is independent of `get_path()` to avoid stderr side effects from `resolve_optex`.

### Getopt::EX Integration

- `Getopt::EX::Hashed` provides the configuration object
- `Getopt::EX::Long` extends standard option parsing
- `ExConfigure BASECLASS` allows loading external option modules

## Testing

```bash
prove -l t/              # Run all tests
perl -Ilib script/chot -i greple   # Test info mode
perl -Ilib script/chot -i ping     # Test optex resolution
perl -Ilib script/chot -i 2up      # Test alias-only optex command
perl -Ilib script/chot -l grep     # Test non-optex command
```

CI runs on Perl versions: 5.24, 5.28, 5.30, 5.40. Minimum Perl version: v5.14.

## Development Notes (2026-02-02)

### optex command tracing (v1.00)

Implemented optex symlink detection and resolution in the Command handler.

**Problem**: Commands in `~/.optex.d/bin/` are symlinks to the `optex` binary. Previously these were skipped entirely via the `--skip` default. Users couldn't trace the execution chain of optex-wrapped commands.

**Solution**:

1. Changed `skip` default from `[".optex.d/bin"]` to `[]` so optex paths are found in PATH.
2. Created `App::chot::Optex` module to detect and resolve optex symlinks.
3. Added resolution to the Command handler's `get_path` pipeline.
4. Optex symlinks are filtered before pager (showing optex source is not useful) but kept in `-l` output.

**optex alias handling**:
- String aliases (`git-stat = "git status -uno"`) resolve first word as command name.
- Array aliases with shell wrappers (`fortune = ["bash", "-c", ...]`) skip resolution since `bash`/`env`/`expr` are not meaningful targets.
- Alias content is printed to stderr for visibility (optex path, config.toml location, alias definition).

**`-i` (info) option**:
- Shows labeled trace of command resolution without opening source in pager.
- Each path annotated with type (optex, homebrew, pyenv shim, command) and file type (perl, bash, binary, etc.).
- Homebrew wrapper resolution shows wrapper -> libexec chain.
- pyenv shims resolved via `pyenv which`.
- Deduplication via `%shown` hash prevents repeated entries from optex + direct PATH discovery.

**Example output**:
```
$ chot -i greple
  command:     /Users/utashiro/perl5/bin/greple (perl)
  homebrew:    /opt/homebrew/bin/greple (wrapper)
  ->           /opt/homebrew/opt/app-greple/libexec/bin/greple (perl)

$ chot -i ping
  optex:       ~/.optex.d/bin/ping -> .../optex
  command:     /sbin/ping (binary)
  rc:          ~/.optex.d/ping.rc

$ chot -i 2up
  alias: 2up = env LESSOPEN="| ansicolumn -DPC2 %s " less +Gg
  optex:       ~/.optex.d/bin/2up -> .../optex
```

### pyenv shim resolution and Python tracing improvements (2026-02-06)

**Problem 1**: `chot pandoc-embedz` failed to find the Python source because the module name contains a hyphen. Python's `import` requires underscores (`pandoc_embedz`), but the validation `$name =~ /[^\w\.]/` rejected the hyphen before import was attempted.

**Problem 2**: `detect_pyenv_shim` in Command.pm only logged the shim path but did not resolve it. The actual executable (e.g., `/Users/.../.pyenv/versions/.../bin/pandoc-embedz`) was not shown.

**Problem 3**: When Python's `inspect.getsourcefile()` returned `__init__.py` with actual content (not empty), `_find_alternative` was not called, so the real entry point (`main.py`) was not discovered.

**Solution**:

1. **Hyphen normalization** (`Python.pm`): Convert hyphens to underscores before validation and import (`pandoc-embedz` → `pandoc_embedz`). This follows Python packaging convention.
2. **pyenv shim resolution** (`Command.pm`): `detect_pyenv_shim` now calls `pyenv which` to resolve the actual executable and returns both the shim and the real path.
3. **`__init__.py` entry point search** (`Python.pm`): Always search for alternative files when `__init__.py` is found, not just when empty. Added `main.py` to the candidate list. Empty `__init__.py` returns only the alternative; non-empty returns both.

**`_find_alternative` search order**:
1. `$base.py` (module-name matching file, e.g., `gpty.py`)
2. `main.py` (CLI entry point)
3. `__main__.py`
4. First non-empty `.py` file (fallback)

**Example output**:
```
$ chot -l pandoc-embedz
/Users/utashiro/.pyenv/shims/pandoc-embedz
/Users/utashiro/.pyenv/versions/3.10.2/bin/pandoc-embedz
.../pandoc_embedz/__init__.py
.../pandoc_embedz/main.py

$ chot -l gpty
/Users/utashiro/.pyenv/shims/gpty
/Users/utashiro/.pyenv/versions/3.10.2/bin/gpty
.../gpty/gpty.py
```
