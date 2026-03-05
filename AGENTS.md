# Git for Windows build-extra - Development Guide

## Background

This repository is the support and release-engineering companion to the
[Git for Windows fork](https://github.com/git-for-windows/git). While that
sibling repository holds the Git source code itself, `build-extra` contains
the definitions for building shippable artifacts (installer scripts,
portable-archive generators, MSI/MSIX/NuGet packaging), the custom Pacman
packages for bundled components, release-note management, and the
`git-extra` package that ships shell configurations and helper utilities.

Much of the release automation that historically lived in `please.sh` has
been migrated to the sibling
[git-for-windows-automation](https://github.com/git-for-windows/git-for-windows-automation)
repository, which houses GitHub workflows triggered by slash commands via
the GitForWindowsHelper GitHub App. That repository now drives the end-to-end
release flow (tagging, building artifacts across architectures, deploying
Pacman packages, publishing GitHub releases, updating the website). What
remains in `build-extra` is the artifact *definitions* (how to assemble an
installer, a portable archive, a MinGit bundle, etc.) and the packaging
recipes, while the *orchestration* of when and how those are invoked in CI
lives in `git-for-windows-automation`.

The repository lives inside a Git for Windows SDK at `/usr/src/build-extra`.
Most of its scripts assume they run in a Git SDK Bash environment (MSYS2 +
MinGW toolchain).

## Repository Structure

### Installer / Artifact Generators

Each artifact type lives in its own subdirectory and ships a `release.sh`
that produces the final output:

| Directory        | Artifact                                            |
|------------------|-----------------------------------------------------|
| `installer/`     | Inno Setup based `.exe` installer for end users     |
| `portable/`      | Self-extracting `.7z` archive ("USB drive edition") |
| `mingit/`        | MinGit, a minimal redistribution-friendly Git       |
| `msi/`           | WiX-based `.msi` installer (stale, not built)       |
| `msix/`          | MSIX / Windows Store package (stale, not built)     |
| `nuget/`         | NuGet packages for CI consumption                   |
| `sdk-installer/` | Full Git for Windows SDK installer                  |

### Custom Pacman Packages

Several bundled components are not part of upstream MSYS2 and are packaged
here using Pacman `PKGBUILD` files:

| Directory                        | Component                         |
|----------------------------------|-----------------------------------|
| `git-extra/`                     | Helpers, shell configs, shortcuts |
| `git-for-windows-keyring/`       | GPG keyring for package signing   |
| `mingw-w64-git-credential-manager/` | Git Credential Manager         |
| `mingw-w64-git-lfs/`            | Git LFS                           |
| `mingw-w64-git-sizer/`          | git-sizer                         |
| `mingw-w64-wintoast/`           | Windows toast notifications       |
| `mingw-w64-cv2pdb/`             | Convert debug info to PDB format  |

These packages are built with `makepkg-mingw -s` (MinGW packages) or
`makepkg -s` (MSYS2 packages) from within the appropriate subdirectory.

### Key Scripts

| Script                 | Purpose                                          |
|------------------------|--------------------------------------------------|
| `please.sh`            | SDK artifact creation and PDB bundling            |
| `shears.sh`            | "Git garden shears" for merging-rebases           |
| `make-file-list.sh`    | Generates file lists for installer artifacts      |
| `add-release-note.js`  | Adds entries to `ReleaseNotes.md` (Node.js)       |
| `render-release-notes.sh` | Converts `ReleaseNotes.md` to HTML             |
| `pacman-helper.sh`     | Helper for Pacman package operations              |

### Release Notes

`ReleaseNotes.md` is the single source of truth for the Git for Windows
release notes. The `add-release-note.js` script (invoked by the
`add-release-note.yml` GitHub workflow) appends entries programmatically.
`render-release-notes.sh` converts Markdown to the HTML shipped with
installers, styled by `ReleaseNotes.css`.

### CI / GitHub Workflows

| Workflow                     | Trigger    | Purpose                       |
|------------------------------|------------|-------------------------------|
| `.github/workflows/main.yml`| PR         | Builds changed packages and artifacts, runs installer validation |
| `.github/workflows/add-release-note.yml` | Dispatch | Adds a release note entry |

The PR workflow automatically determines which packages and artifacts are
affected by a pull request and builds only those. It uses a matrix strategy
covering x86_64 and aarch64 architectures.

The actual release workflows (tagging, building release artifacts, deploying
packages, publishing GitHub releases) live in the
[git-for-windows-automation](https://github.com/git-for-windows/git-for-windows-automation)
repository. That repository's workflows call into `build-extra`'s
`release.sh` scripts and `please.sh` to do the actual work, but the
orchestration and triggering logic is over there.

## `please.sh`

Historically, `please.sh` was the central automation Swiss Army knife for
all of Git for Windows release engineering. Over time, most of that
functionality has been migrated to `git-for-windows-automation` workflows
(and some was simply retired). What remains is a smaller set of SDK-related
utilities. Run it without arguments for a usage summary. Subcommands are
shell functions whose arguments are documented in a comment on the function
definition line. Key remaining subcommands:

- `create-sdk-artifact` -- Extracts a subset of the full SDK for CI use
  (e.g. `build-installers`, `minimal`, `makepkg-git`, `full`). This is
  heavily used by CI workflows both here and in
  `git-for-windows-automation`.
- `bundle-pdbs` -- Collects PDB debug symbol files for a release.

## Building and Testing

### Building a Pacman Package

```bash
cd mingw-w64-git-credential-manager   # or any PKGBUILD directory
MAKEFLAGS=-j8 makepkg-mingw -s --noconfirm
```

### Building an Installer Artifact

```bash
# First create the SDK artifact with the necessary tools
./please.sh create-sdk-artifact \
  --architecture=x86_64 \
  --sdk=.sdk \
  --out=sdk-artifact \
  build-installers

# Then build the installer
./installer/release.sh --output=$PWD/out/ 0-test
```

The `0-test` version argument produces a test build. Real releases use a
version like `2.47.1.windows.1`.

### Building Portable Git

```bash
./portable/release.sh --output=$PWD/out/ 0-test
```

### Building MinGit

```bash
./mingit/release.sh --output=$PWD/out/ 0-test
```

### Validating an Installer

After building, the CI runs the installer silently and then executes
`installer/run-checklist.sh` which verifies that the installed Git works
correctly (runs `git version`, checks for expected components, etc.).

### Compiling `edit-git-bash.exe`

The top-level `Makefile` builds `edit-git-bash.exe` from `edit-git-bash.c`:

```bash
make
```

## Git Workflow

This repository is a shared development environment, not a sandbox. Exercise
caution with all Git operations.

### Making Code Changes

**Minimal, surgical changes.** Make the smallest possible change to achieve
the goal. Do not rewrite entire files or functions when a targeted edit
suffices.

**No fly-by changes.** Do not make changes that were not requested, even if
they seem like improvements (renaming variables, reformatting untouched code,
"fixing" things not part of the task). If you believe a change would be
beneficial but it was not requested, ask for permission first.

**The human is the driver.** Execute what is asked. If you think something
should be done differently, ask, do not just do it.

### Avoiding AI Slop

AI-assisted contributions are welcome, but the output must meet the same
quality bar as hand-written code. Common failure modes to guard against:

- **Vague or fabricated commit messages.** Every factual claim in a commit
  message must be verifiable from the diff or the referenced context. Do
  not invent explanations like "this fixes a race condition" unless you can
  point at the actual race. If you do not know the reason for a change, say
  so or ask.
- **Cargo-culted code.** Do not copy patterns from elsewhere in the
  codebase without understanding why they exist. Shell scripts here have
  evolved over years; some patterns are intentional, others are historical
  accidents. Understand before imitating.
- **Unnecessary verbosity.** Do not pad shell scripts with comments that
  merely restate what the code does ("# loop over all files"). Do not add
  variables, functions, or abstractions that serve no purpose.
- **Unicode and smart punctuation.** Keep all source files, commit messages,
  and documentation in plain ASCII. No curly quotes, no em-dashes, no
  Unicode arrows. Use `--` instead of an em-dash, `->` instead of a
  Unicode arrow, and straight quotes throughout.
- **Overly broad changes.** A pull request that touches files unrelated to
  its stated purpose will be asked to split up. Keep the scope tight.
- **Hallucinated functionality.** Do not reference functions, options, or
  behaviors that do not exist. When calling into `please.sh`, verify the
  subcommand exists and accepts the arguments you are passing.

### Committing Changes

Never use `git add -A` or `git add .`. Always specify pathspecs explicitly:

```bash
git commit -sm "your message here" path/to/file
```

### Commit Messages

Write flowing English prose, not bullet points. Clearly state context,
intent, justification, and non-obvious implementation details. Wrap at 76
columns. Include exact error messages rather than vague descriptions.

### Pushing Changes

Never push without explicit user permission.

### Branch Structure

- `main` -- The primary development branch.
- Topic branches use descriptive names.

## Coding Conventions

### Shell Scripts

Most automation is written in Bash. Scripts assume a Git SDK Bash
environment where both MSYS2 utilities and MinGW tools are available.

- Use `#!/bin/sh` or `#!/bin/bash` as appropriate.
- Prefer POSIX shell when possible; use Bash extensions only when needed.
- Use `die()` for fatal errors with a meaningful message.
- Chain commands with `&&` to fail early.
- Disable pagers in automation: `git --no-pager`.

### Node.js Scripts

Some tooling (e.g. `add-release-note.js`, `merged-branches.js`) is written
in Node.js. Follow idiomatic, concise JavaScript. The `package.json` at the
repository root manages dependencies.

### Inno Setup Scripts

The installer is built with Inno Setup. The `.iss` files in `installer/`
use Pascal Script. `install.iss` is the main script; it includes helpers
from `*.inc.iss` files.

### PKGBUILD Files

Follow the Arch Linux / MSYS2 `PKGBUILD` conventions. Each package
directory contains a `PKGBUILD` and optionally a `.install` script for
post-install hooks. Checksums must be updated whenever source archives
change.

## Platform Considerations

### Architectures

Git for Windows supports three architectures:

| Architecture | `MINGW_PACKAGE_PREFIX`     | `MSYSTEM`   | SDK repo        |
|--------------|----------------------------|-------------|-----------------|
| x86_64       | `mingw-w64-x86_64`        | `MINGW64`   | `git-sdk-64`   |
| i686         | `mingw-w64-i686`          | `MINGW32`   | `git-sdk-32`   |
| aarch64      | `mingw-w64-clang-aarch64` | `CLANGARM64`| `git-sdk-arm64` |

The CI workflow matrix covers x86_64 and aarch64 (and i686 for selected
jobs).

### MinGW vs MSYS2

MinGW binaries are native Windows executables that do not depend on the
POSIX emulation layer. MSYS2 binaries use the msys-2.0.dll runtime for
POSIX compatibility. Git itself is built as a MinGW binary for performance;
helper tools like Bash and Perl are MSYS2 binaries.

## Relationship with Sibling Repositories

| Repository | Role |
|------------|------|
| [git-for-windows/git](https://github.com/git-for-windows/git) | The Git source code (Windows fork) |
| [git-for-windows-automation](https://github.com/git-for-windows/git-for-windows-automation) | Release orchestration workflows (slash commands, CI triggers) |
| [MINGW-packages](https://github.com/git-for-windows/MINGW-packages) | MinGW package recipes (upstream MSYS2 fork) |
| [MSYS2-packages](https://github.com/git-for-windows/MSYS2-packages) | MSYS2 package recipes (upstream MSYS2 fork) |
| git-sdk-64 / git-sdk-32 / git-sdk-arm64 | Full SDK snapshots for each architecture |

The automation repo's workflows push updates *into* `build-extra` (release
notes, package version bumps) and invoke `build-extra`'s scripts to produce
artifacts. Treat `build-extra` as the "what to build" and
`git-for-windows-automation` as the "when and how to trigger builds."

## Resources

- [Git for Windows](https://gitforwindows.org/)
- [Git for Windows SDK](https://github.com/git-for-windows/build-extra/releases/latest)
- [Git for Windows wiki](https://github.com/git-for-windows/git/wiki)
