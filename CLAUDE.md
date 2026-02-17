# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**chot** (Command Heuristic Omni-Tracer) is a Perl utility that locates and displays command and library source files. It traces the execution chain of commands through optex symlinks, Homebrew wrappers, pyenv shims, and aliases, then displays the source using a pager.

Supported finders: Command, Perl, Python, Ruby, Node.

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
   - Loads finder classes and instantiates finder objects once per `run()`
   - All finders share a `Found` object for cross-finder data passing
   - Three output modes: pager display (default), `-l` (list paths), `-i` (info/trace)
   - Filters optex symlinks from pager display via `detect_optex()`
   - `-m` mode tries each finder's `man_cmd` in order; finders return empty list to skip
   - `-C` option wraps the pager with `nup -e` for multi-column display; optional column count. Uses `nup -e` (command mode) because passing files directly to nup triggers parallel mode.

3. **Finder Base Class** (`lib/App/chot/Finder.pm`):
   - Base class for all finder modules, providing `new()` and lvalue accessors (`app`, `name`, `found`)
   - `debug` shortcut delegates to `$self->app->debug`
   - Defines finder contract: `get_path()` (required), `get_info()` (optional), `man_cmd()` (optional)
   - Default `get_path()` returns empty list

4. **Found Object** (`lib/App/chot/Found.pm`):
   - Accumulates paths found by each finder during a single `run()` invocation
   - `add($type, @paths)` records results as finders discover paths
   - `paths` / `types` provide aggregated data across all finders
   - `paths_for($type)` returns a specific finder's results (e.g., Perl finder's `man_cmd` uses `paths_for('Perl')` to get its own paths)

5. **Finder Modules** (each subclasses `App::chot::Finder`):
   - `App::chot::Command` - Searches `$PATH`, resolves optex/Homebrew/pyenv
   - `App::chot::Perl` - Searches `@INC` for .pm/.pl files
   - `App::chot::Python` - Uses `inspect.getsourcefile()` via python3; normalizes hyphens to underscores; traces `__init__.py` to `main.py` etc. Falls back to shebang-discovered interpreters via Found object.
   - `App::chot::Ruby` - Uses `$LOADED_FEATURES` inspection
   - `App::chot::Node` - Uses `require.resolve` with global paths

6. **App::chot::Optex** (`lib/App/chot/Optex.pm`):
   - `detect_optex($path)` - Checks if path is a symlink to the optex binary
   - `resolve_optex($app, $name, $path)` - Resolves optex commands:
     - Loads aliases from `~/.optex.d/config.toml` (via TOML module, with simple fallback parser)
     - Finds real commands in PATH (skipping optex symlinks)
     - Locates `~/.optex.d/NAME.rc` files
   - Prints optex/config/alias info to stderr for visibility

7. **App::chot::Command** resolution pipeline (`get_path`):
   ```
   PATH search -> resolve_optex_command -> detect_pyenv_shim -> resolve_homebrew_wrapper -> _uniq
   ```
   `detect_pyenv_shim` resolves shims via `pyenv which` and returns both the shim and the real path.
   Also provides `get_info()` for `-i` mode with labeled output per path.
   `man_cmd` pre-checks with `man -w` and returns empty list if no man page exists.

8. **Utilities** (`lib/App/chot/Util.pm`): `is_binary()` for binary file detection.

### Key Design Decisions

- **Finder objects**: Each finder is instantiated once per `run()` with `$app`, `$name`, `$found`. Finder methods access these via `$self->app`, `$self->name`, `$self->found` (lvalue accessors). No module-level state variables (`$DEBUG`, `$RAW`, etc.).
- **Found over globals**: Inter-finder data sharing uses `App::chot::Found` instead of package globals. `paths_for($type)` provides per-finder results, fixing the former `$found[0]` context bug in `man_cmd`.
- **Interpreter caching**: Language runtimes (`python3`, `ruby`, `node`) are cached per finder instance (`$self->{_python}` etc.) rather than in module-level variables.
- **Pure functions preserved**: Stateless utility functions (`_uniq`, `_file_type`, `_import_source`, `homebrew_prefix`, etc.) remain as plain subs, not methods.
- `--skip` default is empty (was `.optex.d/bin`). Optex symlinks are now resolved rather than skipped.
- Optex symlinks are included in `-l` output but filtered before pager display.
- Alias resolution skips wrapper commands (`bash`, `sh`, `env`, `exec`, `expr`) as they don't represent real command targets.
- The `_aliases` cache is loaded once (lazy) from config.toml.
- `get_info()` is independent of `get_path()` to avoid stderr side effects from `resolve_optex`.
- `-m` uses `exec` (not `system`) to preserve terminal handling. Finders' `man_cmd` returns empty list to indicate unavailability, allowing fallback to the next finder.

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
perl -Ilib script/chot -l pandoc-embedz  # Test Homebrew venv Python tracing
perl -Ilib script/chot -nm speedtest-z   # Test -m fallback (man → pydoc)
perl -Ilib script/chot -n -C greple     # Test -C (nup pager)
perl -Ilib script/chot -n -C2 greple    # Test -C with column count
```

CI runs on Perl versions: 5.24, 5.28, 5.30, 5.40. Minimum Perl version: v5.14.

## Development Notes

### optex command tracing (v1.00)

Implemented optex symlink detection and resolution in the Command finder.

**Problem**: Commands in `~/.optex.d/bin/` are symlinks to the `optex` binary. Previously these were skipped entirely via the `--skip` default. Users couldn't trace the execution chain of optex-wrapped commands.

**Solution**:

1. Changed `skip` default from `[".optex.d/bin"]` to `[]` so optex paths are found in PATH.
2. Created `App::chot::Optex` module to detect and resolve optex symlinks.
3. Added resolution to the Command finder's `get_path` pipeline.
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

### Homebrew venv Python source tracing and -m fallback (2026-02-16)

**Problem 1**: `chot -l pandoc-embedz` showed the Homebrew wrapper's resolved path (`libexec/venv/bin/pandoc-embedz`) but not the Python source files. The Python finder uses `python3` to import the module, but Homebrew venv packages are not visible to the system python3.

**Problem 2**: `chot -m speedtest-z` failed with "No manual entry" because the Command finder's `man` ran first via `exec`, with no fallback to Python's `pydoc`.

**Problem 3**: Python's `man_cmd` used hardcoded `python3` and didn't normalize hyphens to underscores.

**Solution**:

1. **Shebang fallback** (`Python.pm`): Extracted `_import_source()` from `get_path()`. When the default python3 fails to import a module, iterates over `$self->found->paths` (accumulated by the main loop), reads shebang lines to find Python interpreters, and retries import with each. Also handles `#!/usr/bin/env python3` shebangs via `which` resolution.
2. **Found path accumulation** (`chot.pm`): The main finder loop stores found paths in the shared `Found` object after each finder, making them available to subsequent finders.
3. **`-m` fallback** (`chot.pm`): Changed from single `exec` to a loop over found types. Each finder's `man_cmd` returns empty list to skip (allowing fallback) or a command to `exec`. Uses `exec` (not `system`) to preserve terminal/signal handling.
4. **`man -w` pre-check** (`Command.pm`): `man_cmd` checks man page existence with `man -w` before returning. Returns empty list if no man page, enabling fallback to the next handler.
5. **`man_cmd` improvements** (`Python.pm`): Normalizes hyphens to underscores. Selects Python interpreter from shebang of found paths (same as `get_path` fallback).

**Design note**: `system` was initially used for the `-m` loop but caused terminal issues — `system` sets SIGINT/SIGQUIT to IGNORE in the parent, breaking Ctrl-C in pagers. The `man -w` pre-check + `exec` approach avoids this entirely.

**Example output**:
```
$ chot -l pandoc-embedz
/opt/homebrew/bin/pandoc-embedz
/opt/homebrew/Cellar/pandoc-embedz/.../libexec/venv/bin/pandoc-embedz
.../pandoc_embedz/__init__.py
.../pandoc_embedz/main.py

$ chot -nm speedtest-z
/Users/utashiro/.pyenv/versions/3.10.2/bin/python3.10 -m pydoc speedtest_z

$ chot -nm pandoc-embedz
/opt/homebrew/Cellar/pandoc-embedz/.../libexec/venv/bin/python3.12 -m pydoc pandoc_embedz
```

### Finder architecture refactoring (2026-02-16)

**Problem**: The finder system had several structural issues that would make adding new finders difficult:

1. **Implicit interface**: No base class or documentation. Finders were called via `no strict 'refs'` + symbolic references (`&{"$handler\::get_path"}`).
2. **Three dispatch loops**: `-i` mode, main loop, and `-m` mode each had separate iteration with `no strict 'refs'`, requiring 3 changes for any new optional method.
3. **Global state for inter-finder data**: `$App::chot::_found_paths` was an undeclared package global read only by Python.pm.
4. **Module-level state**: All finders stored `$DEBUG` in `my` variables, initialized at `get_path` entry. Other methods (`man_cmd`, `get_info`) had no guarantee of initialization.
5. **`man_cmd` context bug**: `-m` mode passed `$found[0]` (first path across all finders) to `man_cmd`, but this could be another finder's path.

**Solution**:

1. **`App::chot::Finder` base class**: Provides `new()`, lvalue accessors (`app`, `name`, `found`), `debug` shortcut. Defines finder contract: `get_path` (required), `get_info`/`man_cmd` (optional).
2. **`App::chot::Found` object**: Replaces `$_found_paths` global. Accumulates results via `add()`, provides `paths`/`types` (aggregate) and `paths_for($type)` (per-finder).
3. **Unified dispatch** (`chot.pm`): Finders are loaded and instantiated once, then reused across all three modes. `$h->can('method')` replaces `defined &{"$handler\::method"}`. All `no strict 'refs'` eliminated.
4. **Finder methods**: `get_path`, `get_info`, `man_cmd` receive `$self` instead of `($app, $name)`. State accessed via `$self->debug`, `$self->app->raw`, etc.
5. **Instance-level caching**: `$PYTHON`/`$RUBY`/`$NODE` module variables replaced with `$self->{_python}`/`$self->{_ruby}`/`$self->{_node}`.
6. **`man_cmd` context fix**: Perl.pm uses `$self->found->paths_for('Perl')` to reliably get its own paths.

**Design decisions**:
- Pure utility functions (`_uniq`, `_file_type`, `_import_source`, `homebrew_prefix`, etc.) remain as plain subs, not methods. Only functions that need `$self` (for debug/raw/found) are methods.
- `_detect_pyenv_shim` and `_resolve_homebrew_wrapper` in Command.pm became methods because they need `$self->debug` and `$self->app->raw`.
- `_import_source` in Python.pm takes `$debug` as a parameter rather than becoming a method, since it's a stateless function apart from debug output.
- No external dependencies added — only `parent` pragma (core module).

### `-C` option: nup multi-column display (2026-02-18)

Added `-C` option to display source files with syntax highlighting in multi-column pages using `nup`. Equivalent to `nup chot <name>`. Optional column count: `-C2` for 2-column layout.

**Implementation notes**:
- Uses `nup -e` to wrap the pager command. Passing files directly to nup would show each file in a separate column (parallel mode) instead of paginating them together.
- Strips `--force-colorization` from bat options. nup's built-in bat alias adds `--color=always`, which conflicts with `--force-colorization` in bat.
