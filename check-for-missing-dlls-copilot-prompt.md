# Prompt for Copilot CI debugging session: check-for-missing-dlls ARM64

## Context

You are running on a GitHub Actions Windows 11 ARM64 runner where the
`check-for-missing-dlls` job's "check for missing DLLs" step just failed
(exited non-zero). The earlier steps (checkout, SDK clone, build of the
`build-installers-aarch64` SDK artifact) succeeded; the failure is
downstream of that.

Your working directory is the root of the `build-extra` checkout. ALL
files you create (scripts, logs, screenshots, intermediate results) MUST
be written somewhere inside this directory tree. Files outside it will be
lost when the runner is reaped. The entire working directory will be
uploaded as a build artifact.

Your final findings MUST be written to `copilot-diagnosis.md` in the
working directory. Be specific: which file and line is the root cause,
what evidence points to it, what concrete change fixes it, what the
verification run showed. Do NOT propose changes that you have not
verified work end-to-end.

Treat the diagnosis file as a living document: update it as your
understanding evolves, so that even if the session is interrupted, the
most recent version captures everything you have learned so far.

## Operating principles (READ FIRST, mandatory)

### Verify, do not guess

Every factual claim must be backed by concrete evidence: a log line, a
source line, output of a diagnostic command. Never hallucinate.

### Predict before you test

Before running any diagnostic or applying any fix, state what you expect
to observe and why. If the result diverges, your mental model is wrong:
investigate the divergence.

### Apply and verify end-to-end before reporting

A fix is verified only after `sh -x ./check-for-missing-dlls.sh` exits
with code 0 AND `MINIMAL_GIT=1 ./check-for-missing-dlls.sh` also exits
with code 0. Do NOT write the final diagnosis until this gate has passed.

### Iterate until proven

Your session budget is approximately 90 minutes; use all of it if needed.
A failed verification is information, not defeat.

### Surgical edits only

Fix the specific failure; do not refactor. The human reviewer will read
your diff under time pressure.

### Do not commit, do not push

Apply changes directly to the working tree. The human will review the
diagnosis file and commit themselves.

## Background

On ARM64, `/usr/bin/objdump` (MSYS2, x86_64 under WoW64) cannot parse
`pei-aarch64` PE files, so the script falls back to a PowerShell-based PE
import parser (`pe-imports.ps1`). That parser reads the PE import
directory directly from the binary, which should give correct results for
any PE architecture.

The `check-for-missing-dlls.sh` script has two final checks that must
both pass:

1. No "missing" DLLs: every DLL imported by a shipped .exe/.dll must
   exist in the package (in `$MINGW_PREFIX/bin/` or `usr/bin/` or
   `system32`).
2. No "unused" DLLs: every DLL shipped in `$MINGW_PREFIX/bin/` or
   `usr/bin/` must be imported by at least one shipped .exe/.dll (with
   explicit exclusions for known false positives like GCM .NET assemblies,
   OpenSSL engines, Tcl extensions, etc.).

The previous CI run failed because certain DLLs were flagged as "unused"
despite being genuine dependencies. The suspected cause is that
`pe-imports.ps1` or `check-for-missing-dlls.sh` has a bug that prevents
some DLLs from being correctly counted as "used". The specific DLLs
flagged as unused were: `libnghttp2-14.dll`, `libunwind.dll`,
`libwinpthread-1.dll`, `msalruntime_arm64.dll`.

## Environment details

The SDK artifact is extracted into `sdk-artifact/`. The PATH has been set
to include `sdk-artifact/usr/bin`, `sdk-artifact/usr/bin/core_perl`, and
`sdk-artifact/clangarm64/bin`. The `MSYSTEM` environment variable is set
to `CLANGARM64`.

The shell running these steps is `sdk-artifact/usr/bin/bash.EXE` (MSYS2
Bash, x86_64 under WoW64 emulation on ARM64). This is important because:

- `/usr/bin/objdump` is the MSYS2 x86_64 objdump; it cannot parse
  `pei-aarch64` PE files.
- `ldd` (MSYS2) under WoW64 gives incomplete results for native ARM64
  binaries: only ntdll-loaded system DLLs show up.
- `powershell.exe` (Windows PowerShell 5.1) is always available and runs
  natively on ARM64.

## Your task

### Step 1: Read the failure

Run `sh -x ./check-for-missing-dlls.sh 2>&1 | tee check-dlls-full.log`
and examine the output. Look for:
- Lines saying "X is missing Y" (false missing-DLL reports)
- Lines saying "unused dll: X" (false unused-DLL reports)
- The exit code

### Step 2: Understand the data flow

The script works as follows:
1. `make-file-list.sh` produces a list of all shipped files
2. For each directory containing .dll/.exe files:
   a. `/usr/bin/objdump -p` tries to read PE imports
   b. Files objdump cannot parse go to `pe-imports.ps1` (PowerShell PE parser)
   c. Output is lowercased and parsed for "DLL Name:" lines
3. Each imported DLL name is checked against the shipped file list
4. At the end, shipped DLLs not seen as imports are flagged as "unused"

Trace through the script with the `-x` output to find where the four
flagged DLLs should have been recorded as "used" but were not.

### Step 3: Hypothesize and test

Likely hypotheses:
- `pe-imports.ps1` does not output for some files (maybe PowerShell path
  translation issue, or the script errors on specific PE files)
- The `tr A-Z` lowercasing or `grep` filtering drops some output lines
- An MSYS2 path-translation issue mangles arguments to `powershell.exe`
- The tab character in pe-imports.ps1 output is wrong (the grep expects
  a specific format: `<TAB>DLL Name:`)

### Step 4: Apply the fix and verify end-to-end

Apply your fix to the working tree and re-run BOTH commands:
```
sh -x ./check-for-missing-dlls.sh 2>&1 | tee check-dlls-verify.log
MINIMAL_GIT=1 ./check-for-missing-dlls.sh 2>&1 | tee check-mingit-verify.log
```

The fix is verified ONLY if BOTH exit with code 0.

### Step 5: Record the verified fix

Write to `copilot-diagnosis.md`:
1. Root cause (file:line, evidence)
2. The fix (unified diff)
3. Verification excerpt (relevant log lines showing success)
4. Alternatives considered and rejected
