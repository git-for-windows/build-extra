# Resolve Git for Windows stack frames

From the root of a `build-extra` checkout, run the cache-first helper in
Windows PowerShell 5.1 or newer:

```powershell
& .\resolve-git-stacktrace.ps1 'git_exe!start_command+0x8fc'
```

Pass multiple Git frames, or an image-relative address, as an array:

```powershell
& .\resolve-git-stacktrace.ps1 -Frame `
    'git.exe+0x29113c', 'git_exe!launch_specified_editor+0x198'
```

The helper finds the installed native Git through its installation registry
entry, falling back to `C:\Program Files\Git`. It deliberately does not use
the Git SDK executable found first on `PATH`, or the `cmd\git.exe` wrapper.
For a different installation, pass the actual image explicitly:

```powershell
& .\resolve-git-stacktrace.ps1 `
    -GitExecutable 'C:\Program Files\Git\ucrt64\bin\git.exe' `
    -Frame 'git_exe!start_command+0x8fc'
```

## Portable CDB: download once

The default debugger directory is `$HOME\windbg`; override it with
`-DebuggerDirectory`. The script checks `amd64\cdb.exe` there first and
verifies its Microsoft Authenticode signature. Existing CDB is reused
without package discovery, installation, or update checks.

Only when CDB is absent does it fetch
<https://aka.ms/windbg/download>. That XML app-installer manifest provides
the current official MSIX bundle URL in `MainBundle.Uri`. The script caches
the manifest and bundle under `$HOME\windbg\downloads`, reads the embedded
`AppxMetadata/AppxBundleManifest.xml`, and extracts the x64 application
package before unpacking it into `$HOME\windbg`. It does not register an
app, change debugger registrations, or modify `PATH`.

The bundle can be large. Cached downloads and the extracted x64 MSIX are
reused. Do not infer a direct download URL from an embedded package name
such as `windbg_win-x64.msix`. Interrupted downloads remain as `.partial`
files and cause an explicit error rather than being treated as complete.
Extraction never overwrites existing package files.

Microsoft's installation reference:
<https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/>.

## PDBs: cache the correct native image's symbols

`git version --build-options` identifies the release version and exact
source commit. The native image's directory identifies the package flavor,
for example `ucrt64`. The helper retrieves the corresponding
`v<VERSION>` release through `gh api`, selects its
`pdbs-for-git-<FLAVOR>-*.zip` asset, and verifies the published SHA-256 digest.
It extracts only `<FLAVOR>/bin/git.pdb`, not `cmd/git.pdb`.

The cache is `$HOME\windbg\symbols\<FLAVOR>\<VERSION>`. It contains
`release.json`, the downloaded PDB archive, and `git.pdb`. PDB "installation"
means extraction into this directory and passing it to CDB with `-y`;
no system-wide symbol configuration is needed. An existing PDB skips all
release queries and downloads. CDB must still accept its identity and load
private symbols with line information on every run.

For the original investigation, the official archive was:
<https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/pdbs-for-git-ucrt64-2.56.0.2-1.zip>.
Its SHA-256 was
`3e78910b6a2f7da26e0d61bcb285ae1c54e1ded245944758501869e1ec9aec69`.

To reuse that earlier download instead of fetching it again, place the
archive in `$HOME\windbg\symbols\ucrt64\2.56.0.windows.2` before the first
run. The helper will retrieve release metadata, verify the cached archive,
and extract it.

Only a missing debugger requires `curl.exe`. Missing PDBs require `gh`;
downloading a missing archive also requires `curl.exe`. No dependencies
are installed. A fully populated cache needs neither command and skips all
script-initiated downloads and release queries.

## Exact lines and reproducible debugger output

The script opens the executable with `-z`, without launching or attaching
to a Git process. It enables line information with `-lines`, strict symbol
matching with `-ses`, and ignores inherited symbol search paths with
`-sins`. It also disables `SYMOPT_LOAD_ANYTHING` and `SYMOPT_IGNORE_CVREC`.
See Microsoft's [symbol options reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbol-options).

Each run saves a unique `.commands` file and full `.log` in the PDB cache.
The command file reloads symbols, prints `!lmi git` for the image's PDB GUID,
age and load report, then evaluates each address with `?`, resolves it with
`ln`, and disassembles from that address with `u`. A successful process exit
alone is insufficient: the helper requires matching private symbols with
lines and an actual source-line result for every requested frame.

For manual analysis, use the printed cache and command-file paths:

```powershell
$cdb = "$HOME\windbg\amd64\cdb.exe"
$symbols = "$HOME\windbg\symbols\ucrt64\2.56.0.windows.2"
& $cdb -sins -ses -lines -y $symbols `
    -z 'C:\Program Files\Git\ucrt64\bin\git.exe' `
    -c '.reload /f;!lmi git;ln git!start_command+0x8fc;q'
```

The image-only session calls this module `git`, even if the reported dump
calls it `git_exe`. The helper normalizes that alias. CDB commands in the
saved file are on separate lines: `.srcpath` accepts semicolon-separated
paths and can swallow commands appended to it. If local source is needed,
pass its exact-commit directory with CDB's `-srcpath` option instead.

Offsets are specific to the compiled image. Compare the reported dump's
PDB GUID and age with `!lmi` before applying an offset from another machine;
matching version strings alone are not sufficient. Use the emitted
exact-commit source links, not the current checkout. Inlining can place the
line in a helper or header rather than the function named by the stack.
For non-faulting frames, a return address can map after the call; do not
silently subtract one from the actual exception instruction.

In [git-for-windows/git#6475](https://github.com/git-for-windows/git/issues/6475),
the installed image and reported dump had PDB GUID
`4CB9821A-11A9-46FA-9F9B-680236AB44D9`, age 1. Both
`git_exe!start_command+0x8fc` and `git.exe+0x29113c` resolved to
[`compat\mingw.h:38`](https://github.com/git-for-windows/git/blob/cc4dbf752a05efdc0e04e71fd3e8110d11bdd35c/compat/mingw.h#L38).
The instruction was `movzx edx,byte ptr [rax]` in an inlined
`convert_slashes()`, immediately after the `sh` lookup in
[`git_shell_path()`](https://github.com/git-for-windows/git/blob/cc4dbf752a05efdc0e04e71fd3e8110d11bdd35c/run-command.c#L282-L283).
That mapping identifies the dereference; it does not recover the crashed
process's editor setting or `PATH`.

## Reproducible integration self-test

```powershell
& .\resolve-git-stacktrace.ps1 -SelfTest
```

This mode tests the seven Git frames reported in the original issue and
the equivalent image-relative exception address. It requires the known
`2.56.0.windows.2` build commit, PDB GUID and age, and checks each concrete
source location rather than accepting any successful symbol lookup:

| Frame | Expected location |
|-------|-------------------|
| `git_exe!start_command+0x8fc` | `compat\mingw.h:38` |
| `git.exe+0x29113c` | `compat\mingw.h:38` |
| `git_exe!launch_specified_editor+0x198` | `editor.c:99` |
| `git_exe!cmd_commit+0x186f` | `builtin\commit.c:1124` |
| `git_exe!handle_builtin+0x1e8` | `git.c:511` |
| `git_exe!cmd_main+0x3ca` | `git.c:906` |
| `git_exe!main+0x22` | `common-main.c:12` |
| `git_exe!wmain+0x2ae` | `compat\mingw.c:4479` |

The test reuses the exact installed reference image when its SHA-256
matches the investigated binary. Otherwise it verifies and caches the
official `MinGit-2.56.0.2-64-bit.zip` release fixture under
`$HOME\windbg\tests\git-2.56.0.windows.2`, without replacing installed Git.
A cached fixture is preferred on later runs, so updating installed Git
does not change the regression case. Pass `-GitExecutable` to supply an
existing reference image explicitly; a different version or identity
fails the test.

The test uses the same CDB and PDB provisioning as ordinary resolution.
If portable CDB is not already unpacked, it downloads and extracts the
official WinDbg bundle. Missing PDBs and the reference Git fixture are
also obtained automatically; populated caches are reused. Override
`-DebuggerDirectory` to choose a different debugger and fixture cache.
No test framework or additional dependency is installed.
