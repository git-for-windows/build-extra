# Git for Windows v2.7.1 Release Notes
Latest update: February 6th 2016

## Introduction

These release notes describe issues specific to the Git for Windows release. The release notes covering the history of the core git commands can be found [in the Git project](https://github.com/git/git/tree/master/Documentation/RelNotes).

See [http://git-scm.com/](http://git-scm.com/) for further details about Git including ports to other operating systems. Git for Windows is hosted at [https://git-for-windows.github.io/](https://git-for-windows.github.io/).

# Known issues
* Special permissions (and Windows Vista or later) are required when cloning repositories with symbolic links, therefore support for symbolic links is disabled by default. Use `git clone -c core.symlinks=true <URL>` to enable it, see details [here](https://github.com/git-for-windows/git/wiki/Symbolic-Links).
* If configured to use Plink, you will have to connect with [putty](http://www.chiark.greenend.org.uk/~sgtatham/putty/) first and accept the host key.
* Some console programs interact correctly with MinTTY only when called through `winpty` (e.g. the Python console needs to be started as `winpty python` instead of just `python`).
* [cURL](http://curl.haxx.se) uses `$HOME/_netrc` instead of `$HOME/.netrc`.
* If you specify command-line options starting with a slash, POSIX-to-Windows path conversion will kick in converting e.g. "`/usr/bin/bash.exe`" to "`C:\Program Files\Git\usr\bin\bash.exe`". When that is not desired -- e.g. "`--upload-pack=/opt/git/bin/git-upload-pack`" or "`-L/regex/`" -- you need to set the environment variable `MSYS_NO_PATHCONV` temporarily, like so:

  > `MSYS_NO_PATHCONV=1 git blame -L/pathconv/ msys2_path_conv.cc`

  Alternatively, you can double the first slash to avoid POSIX-to-Windows path conversion.
* Git for Windows will not allow commits containing DOS-style truncated 8.3-format filenames ending with a tilde and digit, such as `mydocu~1.txt`. A workaround is to call `git config core.protectNTFS false`, which is not advised. Instead, add a rule to .gitignore to ignore the file(s), or rename the file(s).
* Many Windows programs (including the Windows Explorer) have problems with directory trees nested so deeply that the absolute path is longer than 260 characters. Therefore, Git for Windows refuses to check out such files by default. You can overrule this default by setting `core.longPaths`, e.g. `git clone -c core.longPaths=true ...`.
*   Some commands are not yet supported on Windows and excluded from the installation.
*   As Git for Windows is shipped without Python support, all Git commands requiring Python are not yet supported; e.g. `git p4`.
*   The Quick Launch icon will only be installed for the user running setup (typically the Administrator). This is a technical restriction and will not change.

Should you encounter other problems, please search [the bug tracker](https://github.com/git-for-windows/git/issues) and [the mailing list](http://groups.google.com/group/git-for-windows), chances are that the problem was reported already. If it has not been reported, please follow [our bug reporting guidelines](https://github.com/git-for-windows/git/wiki/Issue-reporting-guidelines) and [report the bug](https://github.com/git-for-windows/git/issues/new).

## Licenses
Git is licensed under the GNU Public License version 2.

Git for Windows also contains Embedded CAcert Root Certificates. For more information please go to [https://www.cacert.org/policy/RootDistributionLicense.php](https://www.cacert.org/policy/RootDistributionLicense.php).

This package contains software from a number of other projects including Bash, zlib, curl, msmtp, tcl/tk, perl, MSys2 and a number of libraries and utilities from the GNU project, licensed under the GNU Public License. Likewise, it contains Perl which is dual licensed under the GNU Public License and the Artistic License.

## Changes since Git for Windows v2.7.1 (February 6th 2016)

### New Features

* The context menu items in the explorer [now show icons](https://github.com/git-for-windows/build-extra/pull/97).

### Bug Fixes

* A bug [was fixed](https://github.com/git-for-windows/git/commit/4abc31070f683e555de95331da0990052f55caa5) where worktrees would forget their location e.g. after an interactive rebase.
* Thanks to Eric Lawrence and Martijn Laan, [our installer sports a better way to look for system files now](https://github.com/git-for-windows/build-extra/tree/master/installer/InnoSetup).

## Changes since Git for Windows v2.7.0(2) (February 2nd 2016)

### New Features

* Comes with [Git 2.7.1](http://article.gmane.org/gmane.comp.version-control.git/285657).

### Bug Fixes

* Git GUI now [starts properly even when the working directory contains non-ASCII characters](https://github.com/git-for-windows/git/issues/410).
* We forgot to enable Address Space Layout Randomization and Data Execution Prevention on our Git wrapper, and this is [now fixed](//github.com/git-for-windows/git/issues/644).
* A bug in one of the DLLs used by Git for Windows [was fixed](https://github.com/Alexpux/MINGW-packages/pull/1051) that prevented Git from working properly in 64-bit setups where [the `FLG_LDR_TOP_DOWN` global flag](https://technet.microsoft.com/en-us/library/cc779664%28v=ws.10%29.aspx) is set.

## Changes since Git for Windows v2.7.0 (January 5th 2016)

### New Features

* To stave off exploits, Git for Windows [now uses Address Space Layout Randomization (ASLR) and Data Execution Prevention (DEP)](https://github.com/git-for-windows/git/pull/612).
* Git for Windows' support for `git pull --rebase=interactive` that was dropped when the `pull` command was rewritten in C, [was resurrected](https://github.com/git/git/commit/f9219c0b3).
* The installers are now [dual signed](https://github.com/git-for-windows/git/issues/592) with SHA-2 and SHA-1 certificates.
* The uninstaller [is signed now, too](https://github.com/git-for-windows/git/issues/540).

### Bug Fixes

* When installing as administrator, we [no longer offer the option to install quiicklaunch icons](https://github.com/git-for-windows/build-extra/commit/a13ffd7c3fa24e2ac1ef3561d7a7f09a0b924338) because quicklaunch icons can only be installed per-user.
* If a `~/.bashrc` is detected without a `~/.bash_profile`, the generated file will now [also source `~/.profile` if that exists](https://github.com/git-for-windows/build-extra/pull/91).
* The environment variable `HOME` can now be used to set the home directory [even when running with accounts that are part of a different domain than the current (non-domain-joined) machine](https://github.com/git-for-windows/msys2-runtime/commit/9660c5ffe82b921dd2193efa18e9721f47a6b22f) (in which case the MSys2 runtime has no way to emulate POSIX-style UIDs).
* Git [can now fetch and push via HTTPS](https://github.com/Alexpux/MINGW-packages/pull/986) even when the `http.sslCAInfo` config variable was unset.
* Git for Windows is now [handling the case gracefully where the current user has no permission to list the parent of the current directory](https://github.com/git-for-windows/git/pull/606).
* More file locking issues ("Unlink of file ... failed. Should I try again?") [were fixed](https://github.com/git-for-windows/git/issues/500).

## Changes since Git for Windows v2.6.4 (December 14th 2015)

### New Features

* Comes with [Git v2.7.0](http://article.gmane.org/gmane.linux.kernel/2118402).

## Bug Fixes

* Non-ASCII command-lines are now [passed properly](https://github.com/git-for-windows/msys2-runtime/commit/4c362726c41102173613658) to shell scripts.

## Changes since Git for Windows v2.6.3 (November 10th 2015)

### New Features

* Comes with [Git v2.6.4](http://article.gmane.org/gmane.linux.kernel/2103498).
* Also available as `.tar.bz2` packages (you need an MSys2/Cygwin-compatible unpacker to recreate the symbolic links correctly).

## Bug Fixes

* Git for Windows v2.6.3's installer [failed](https://github.com/git-for-windows/git/issues/523) to [elevate privileges automatically](https://github.com/git-for-windows/git/issues/526) (reported [three times](https://github.com/git-for-windows/git/issues/528), making it a charm), and as a consequence Git for Windows 2.6.3 was frequently [installed per-user by mistake](https://github.com/git-for-windows/build-extra/commit/23672af723da18e5bc3c679e52106de3c2dec55a)
* The bug where [`SHELL_PATH` had spaces](https://github.com/git-for-windows/git/issues/542) and that was [reported](https://github.com/git-for-windows/git/issues/498) multiple [times](https://github.com/git-for-windows/git/issues/468) has been [fixed](https://github.com/git-for-windows/msys2-runtime/commit/7f4284d245f9c736dc8ec52e12c5d67cea7e4ba9).
* An additional work-around from upstream Git for `SHELL_PATH` containing spaces (fixing [problems with interactive rebase's `exec` command](https://github.com/git-for-windows/git/issues/542) has been applied.

## Changes since Git for Windows v2.6.2 (October 19th 2015)

### New Features

* Comes with [Git v2.6.3](http://article.gmane.org/gmane.comp.version-control.git/280947).
* [Enables the stack smasher to protect against buffer overflows](https://github.com/git-for-windows/git/issues/501).

### Bug Fixes

* Git Bash [works now even when choosing Windows' default console *and* installing into a short path (e.g. `C:\Git`)](https://github.com/git-for-windows/git/issues/509).
* Notepad [can now really be used to edit commit messages](https://github.com/git-for-windows/git/issues/517).
* Git's garbage collector [now handles stale `refs/remotes/origin/HEAD` gracefully](https://github.com/git-for-windows/git/issues/423).
* The regression in Git for Windows 2.6.2 that it required administrator privileges to be installed [is now fixed](https://github.com/git-for-windows/build-extra/pull/86).
* When `notepad` is configured as default editor, we no longer do anything specially [unless editing files inside `.git/`](https://github.com/git-for-windows/git/issues/488).

## Changes since Git for Windows v2.6.1 (October 5th 2015)

### New Features

* Comes with Git v2.6.2
* Users who are part of a Windows domain [now have sensible default values](https://github.com/git-for-windows/git/pull/487) for `user.name` and `user.email`.

### Bug Fixes

* We [no longer run out of page file space](https://github.com/git-for-windows/git/pull/486) when `git fetch`ing large repositories.
* The description of Windows' default console is accurate now (the console became more powerful in Windows 10).
* *Git GUI* now respects the [terminal emulation chosen at install time](https://github.com/git-for-windows/git/issues/490) when [running the *Git Bash*](https://github.com/git-for-windows/git/pull/492).

## Changes since Git-2.6.0 (September 29th 2015)

### New Features

* Comes with Git 2.6.1
* The installer [now writes the file `/etc/install-options.txt`](https://github.com/git-for-windows/git/issues/454) to record which options were chosen at install time.
* Replaces `git flow` with [the *AVH edition*](https://github.com/petervanderdoes/gitflow-avh) which is maintained actively, in surprising and disappointing contrast to Vincent Driessen's very own project.

### Bug Fixes

* The `PATH` variable [is now really left alone](https://github.com/git-for-windows/git/issues/438) when choosing the *"Use Git from Git Bash only"* option in the installer. Note that upgrading Git for Windows will call the previous version's uninstaller, which might still have that bug.
* Git GUI's *Registry>Create Desktop Icon* [now generates correct shortcuts](https://github.com/git-for-windows/git/issues/448).
* The `antiword` utility to render Word documents for use in `git diff` [now works correctly](https://github.com/git-for-windows/git/issues/453).
* In 64-bit installations, we [no longer set a pack size limit by default](https://github.com/git-for-windows/git/issues/288).
* When installing Git for Windows as regular user, [the installer no longer tries to create privileged registry keys](https://github.com/git-for-windows/git/issues/455).

## Changes since Git-2.5.3 (September 18th 2015)

### New Features

* Comes with Git 2.6.0
* The `WhoUses.exe` tool to determine which process holds a lock on a given file (which was shipped with Git for Windows 1.x) [gets installed alongside Git for Windows again](https://github.com/git-for-windows/git/issues/408).
* The values `CurrentVersion`, `InstallPath` and `LibexecPath` are [added to the `HKEY_LOCAL_MACHINE\Software\GitForWindows` registry key](https://github.com/git-for-windows/git/issues/427) to help third-party add-ons to find us.
* When fetching or pushing with Git *without* a console, we now [fall back to Git GUI's `askpass` helper](https://github.com/git-for-windows/git/issues/428) to ask for pass phrases.
* When run through `<INSTALL_PATH>\cmd\git.exe`, Git [will find tools in `$HOME/bin`](https://github.com/git-for-windows/git/issues/429) now.

### Bug Fixes

* The portable version avoids DLL search path problems [even when installed into a FAT filesystem](https://github.com/git-for-windows/git/issues/390).
* Configuring `notepad` as editor without configuring a width for commit messages [no longer triggers an error message](https://github.com/git-for-windows/git/issues/430).
* When using Windows' default console for *Git Bash*, [the `.sh` file associations work again](https://github.com/git-for-windows/git/issues/396).
* Portable Git's `README` [is now clearer about the need to run `post-install.bat` when unpacking manually](https://github.com/git-for-windows/build-extra/pull/83).
* [We use the `winpty` trick now](https://github.com/git-for-windows/git/issues/436) to run `ipython` interactively, too.
* When the environment variable `HOME` is not set, we [now](https://github.com/git-for-windows/git/issues/414) fall back [correctly](https://github.com/git-for-windows/git/issues/434) to use `HOMEDRIVE` and `HOMEPATH`.
* The home directory is now [set correctly](https://github.com/git-for-windows/git/issues/435) when running as the `SYSTEM` user.
* The environment variable `GIT_WORK_TREE` [may now differ in lower/upper case with the Git's idea of the current working directory](https://github.com/git-for-windows/git/issues/402).
* Running `git clone --dissociate ...` [no longer locks the pack files during the repacking phase](https://github.com/git-for-windows/git/issues/446).
* Upstream cURL fixes for NTLM proxy issues ("Unknown SSL error") [were backported](https://github.com/git-for-windows/git/issues/373).
* The 64-bit version [now includes](https://github.com/git-for-windows/git/issues/449) the `astextplain` script it lacked by mistake.

## Changes since Git-2.5.2(2) (September 13th 2015)

### New Features

* Comes with Git 2.5.3.
* Includes [`git flow`](http://nvie.com/posts/a-successful-git-branching-model/).
* By configuring `git config core.editor notepad`, users [can now use `notepad.exe` as their default editor](https://github.com/git-for-windows/git/issues/381). Configuring `git config format.commitMessageColumns 72` will be picked up by the notepad wrapper and line-wrap the commit message after the user edited it.
* The Subversion bindings for use with `git svn` [were upgraded to version 1.9.1](https://github.com/git-for-windows/git/issues/374).
* Some interactive console programs, e.g. `psql.exe`, [now work in mintty thanks to pre-configured aliases](https://github.com/git-for-windows/git/issues/399).
* The mechanism to diff `.pdf`, `.doc` and `.docx` files known from Git for Windows 1.x [has been ported to Git for Windows 2.x](https://github.com/git-for-windows/git/issues/355).
* Git can now [access IPv6-only hosts via HTTP/HTTPS](https://github.com/git-for-windows/git/issues/370).

### Bug Fixes

* The `.vimrc` in the home directory [is now allowed to have DOS line endings](https://github.com/git-for-windows/git/issues/364).
* The `README.portable` file of the portable Git [mentions the need to run `post-install.bat`](https://github.com/git-for-windows/git/issues/394) when the archive was extracted manually.
* Home directories for user names [with non-ASCII characters](https://github.com/git-for-windows/git/issues/331) are [handled](https://github.com/git-for-windows/git/issues/336) correctly [now](https://github.com/git-for-windows/git/issues/383).
* The documentation [no longer shows plain-text `linkgit:...` "links"](https://github.com/git-for-windows/git/issues/404) but proper hyperlinks instead.
* The `mtab` link [is written to `/etc/mtab` again, as it should](https://github.com/git-for-windows/git/issues/405).
* When run inside the PowerShell, Git no longer gets confused when the current directory's path and what is recorded in the file system differs in case (e.g. "GIT/" vs "Git/").

## Changes since Git-2.5.2 (September 10th 2015)

### Bug Fixes

* The Git GUI [can be launched from the Start menu again](https://github.com/git-for-windows/git/issues/376).
* It [now works](https://github.com/git-for-windows/git/pull/305) to call `git add -p -- .` when there is a large number of files.
* The Arrow keys can be used in the Bash history again [when run in the Windows console](https://github.com/git-for-windows/git/issues/353).
* Tab completion in the context of a large Active Directory [is no longer slow](https://github.com/git-for-windows/git/issues/377).

## Changes since Git-2.5.1 (August 31th 2015)

### New Features

* Comes with Git 2.5.2
* Alternates [can now point to UNC paths](https://github.com/git-for-windows/git/pull/286), i.e. network drives.

### Bug Fixes

* The MSys2 runtime was taught [not to look hard for groups](https://github.com/git-for-windows/git/issues/193), speeding up *Git Bash*'s startup time.
* A [work around](https://github.com/git-for-windows/git/issues/361) was added for [issues](https://github.com/git-for-windows/git/wiki/32-bit-issues) when installing 32-bit Git for Windows on 64-bit Windows 10.
* The installer [no longer freezes](https://github.com/git-for-windows/git/issues/351) when there are interactive commands in the user's `.profile`.
* `git rebase --skip` [was speeded up again](https://github.com/git-for-windows/git/issues/365).
* The redirector in `/bin/bash.exe` now adjusts the `PATH` environment variable correctly (i.e. so that Git's executables are found) before launching the *real* Bash, even when called without `--login`.
* When installing Git for Windows to a location whose path is longer than usual, Git commands [no longer trigger occasional `Bad address` errors](https://github.com/git-for-windows/git/issues/303).
* Git [no longer asks for a DVD to be inserted again](https://github.com/git-for-windows/git/issues/329) when one has been ejected from the `D:` drive.

## Changes since Git-2.5.0 (August 18th 2015)

### New Features

* Comes with Git 2.5.1

### Bug Fixes

* Backspace [works now](https://github.com/git-for-windows/git/issues/282) with ConHost-based (`cmd.exe`) terminal.
* When there is a `~/.bashrc` but no `~/.bash_profile`, [the latter will be created automatically](https://github.com/git-for-windows/build-extra/pull/71).
* When calling a non-login shell, [the prompt now works](https://github.com/git-for-windows/build-extra/pull/72).
* The text in the installer describing the terminal emulator options [is no longer cut off](https://github.com/git-for-windows/build-extra/pull/69).
* The `connect.exe` tool to allow SSH connections via HTTP/HTTPS/SOCKS proxies [is included in Git for Windows again](https://github.com/git-for-windows/build-extra/pull/73), as it was in Git for Windows 1.x.
* The `LANG` variable is [no longer left unset](https://github.com/git-for-windows/git/issues/298) (which caused troubles with vim).
* `call start-ssh-agent` [no longer spits out bogus lines](https://github.com/git-for-windows/git/issues/314).
* It is now possible [even behind NTLM-authenticated proxies](https://github.com/git-for-windows/git/issues/309) to install [Git for Windows' SDK](https://git-for-windows.github.io/#download-sdk).
* We [can handle the situation now](https://github.com/git-for-windows/git/issues/318) when the first `$PATH` elements point outside of Git for Windows' `bin/` directories and contain `.dll` files that interfere with our own (e.g. PostgreSQL's `libintl-8.dll`).
* The `patch` tool [is now included again](https://github.com/git-for-windows/build-extra/pull/74) as it was in Git for Windows 1.x.

## Changes since Git-2.4.6 (July 18th 2015)

### New Features

* Comes with Git 2.5.0
* On Windows 7 and later, [the *Git Bash* can now correctly be pinned to the task bar](https://github.com/git-for-windows/git/issues/263).

### Bug Fixes

* The size of the installers [was reduced again](https://github.com/git-for-windows/git/issues/262), almost to the levels of Git for Windows 1.x.
* Under certain circumstances, when the Windows machine is part of a Windows domain with lots of users, the startup of the *Git Bash* [is now faster](https://github.com/git-for-windows/git/issues/193).
* Git [no longer warns about being unable to read bogus Git attributes](https://github.com/git-for-windows/git/issues/255).

## Changes since Git-2.4.5 (June 29th 2015)

### New Features

* Comes with Git 2.4.6

### Bug Fixes

* Git for Windows handles symlinks now, [even if core.symlinks does not tell Git to generate symlinks itself](https://github.com/git-for-windows/git/pull/220).
* `git svn` learned [*not* to reuse incompatible on-disk caches left over from previous Git for Windows versions](https://github.com/git-for-windows/git/pull/246).

## Changes since Git-2.4.4 (June 20th 2015)

### New Features

* Comes with Git 2.4.5

### Bug Fixes

* Git Bash [no longer crashes when called with `TERM=msys`](https://github.com/git-for-windows/git/issues/222). This reinstates compatibility with GitHub for Windows.

## Changes since Git-2.4.3 (June 12th 2015)

### New Features

* Comes with Git 2.4.4
* The POSIX-to-Windows path mangling [can now be turned off](https://github.com/git-for-windows/msys2-runtime/pull/11) by setting the `MSYS_NO_PATHCONV` environment variable. This even works for individual command lines: `MSYS_NO_PATHCONV=1 cmd /c dir /x` will list the files in the current directory along with their 8.3 versions.

### Bug Fixes

* `git-bash.exe` [no longer changes the working directory to the user's home directory](https://github.com/git-for-windows/git/issues/130).
* Git [can now clone into a drive root](https://github.com/msysgit/git/issues/359), e.g. `C:\`.
* For backwards-compatibility, redirectors are installed into `/bin/bash.exe` and `/bin/git.exe`, e.g. [to support SourceTree and TortoiseGit better](https://github.com/git-for-windows/git/issues/208).
* When using `core.symlinks = true` while cloning repositories with symbolic links pointing to directories, [`git status` no longer shows bogus modifications](https://github.com/git-for-windows/git/issues/210).

## Changes since Git-2.4.2 (May 27th 2015)

### New Features

* Comes with Git 2.4.3

### Bug Fixes

* [We include `diff.exe`](https://github.com/git-for-windows/git/issues/163) just as it was the case in Git for Windows 1.x
* The certificates for accessing remote repositories via HTTPS [are found on XP again](https://github.com/git-for-windows/git/issues/168).
* `clear.exe` and the cursor keys in vi [work again](https://github.com/git-for-windows/git/issues/169) when Git Bash is run in Windows' default console window ("ConHost").
* The ACLs of the user's temporary directory are no longer modified when mounting `/tmp/` (https://github.com/git-for-windows/git/issues/190).
* *Git Bash Here* works even from the context menu of the empty area in Windows Explorer's view of C:\, D:\, etc (https://github.com/git-for-windows/git/issues/176).

## Changes since Git-2.4.1 (May 14th 2015)

### New Features

* On Windows Vista and later, [NTFS junctions can be used to emulate symlinks now](https://github.com/git-for-windows/git/pull/156); To enable this emulation, the `MSYS` environment variable needs to be set to `winsymlinks:nativestrict`.
* The *Git Bash* learned to support [several options to support running the Bash in arbitrary terminal emulators](https://github.com/git-for-windows/git/commit/ac6b03cb4).

### Bug Fixes

* Just like Git for Windows 1.x, [pressing Shift+Tab in the Git Bash triggers tab completion](https://github.com/git-for-windows/build-extra/pull/59).
* [Auto-mount the temporary directory of the current user to `/tmp/` again](https://github.com/git-for-windows/msys2-runtime/pull/9), just like Git for Windows 1.x did (thanks to MSys1's hard-coded mount point).

## Changes since Git-2.4.0(2) (May 7th 2015)

### New Features

* Comes with Git 2.4.1

### Bug Fixes

* When selecting the standard Windows console window for `Git Bash`, a regression was fixed that triggered [an extra console window](https://github.com/git-for-windows/git/issues/148) to be opened.
* The password [can be entered interactively again](https://github.com/git-for-windows/git/issues/124) when `git push`ing to a HTTPS remote.

## Changes since Git-2.4.0 (May 5th 2015)

### Bug Fixes

* The `.sh` file association was fixed
* The installer will now remove files from a previous Git for Windows versions, particularly important for 32-bit -> 64-bit upgrades

### New Features

* The installer now offers the choice between opening the _Git Bash_ in a MinTTY (default) or a regular Windows console window (Git for Windows 1.x' setting).

## Changes since Git-2.3.7-preview20150429

### New Features
* Comes with Git 2.4.0
* Git for Windows now installs its configuration into a Windows-wide location: `%PROGRAMDATA%\Git\config` (which will be shared by libgit2-based applications with the next libgit2 version)

### Bug Fixes
* Fixed a regression where *Git Bash* would not start properly on Windows XP
* Tab completion works like on Linux and MacOSX (double-Tab required to show ambiguous completions)
* In 32-bit setups, all the MSys2 `.dll`'s address ranges are adjusted ("auto-rebased") as part of the installation process
* The post-install scripts of MSys2 are now executed as part of the installation process, too
* All files that are part of the installation will now be registered so they are deleted upon uninstall

## Changes since Git-2.3.6-preview20150425

### New Features
* Comes with Git 2.3.7

### Bug Fix
* A flawed "fix" that ignores submodules during rebases was dropped
* The home directory can be overridden using the `$HOME` environment variable again

## Changes since Git-2.3.5-preview20150402

### New Features
* Comes with Git 2.3.6

### Bug Fixes
* Fixed encoding issues in Git Bash and keept the TMP environment variable intact.
* Downgraded the `nettle` packages due to an [*MSYS2* issue](https://github.com/Alexpux/MINGW-packages/issues/549)
* A couple of fixes to the Windows-specific Git wrapper
* Git wrapper now refuses to use `$HOMEDRIVE$HOMEPATH` if it points to a non-existing directory (this can happen if it points to a network drive that just so happens to be Disconnected Right Now).
* Much smoother interaction with the `mintty` terminal emulator
* Respects the newly introduced Windows-wide `%PROGRAMDATA%\Git\config` configuration

## Changes since Git-1.9.5-preview20150402

### New Features
* Comes with Git 2.3.5 plus Windows-specific patches.
* First release based on [MSys2](https://msys2.github.io/).
* Support for 64-bit!

### Backwards-incompatible changes
* The development environment changed completely from the previous version (maybe introducing some regressions).
* No longer ships with Git Cheetah (because there are better-maintained Explorer extensions out there).

## Changes since Git-1.9.5-preview20141217

### New Features
* Comes with Git 1.9.5 plus Windows-specific patches.
* Make `vimdiff` usable with `git mergetool`.

### Security Updates
* Mingw-openssl to 0.9.8zf and msys-openssl to 1.0.1m
* Bash to 3.1.23(6)
* Curl to 7.41.0

### Bugfixes
* ssh-agent: only ask for password if not already loaded
* Reenable perl debugging ("perl -de 1" possible again)
* Set icon background color for Windows 8 tiles
* poll: honor the timeout on Win32
* For `git.exe` alone, use the same HOME directory fallback mechanism as `/etc/profile`

## Changes since Git-1.9.4-preview20140929

### New Features
* Comes with Git 1.9.5 plus Windows-specific patches.

### Bugfixes
* Safeguards against bogus file names on NTFS (CVE-2014-9390).

## Changes since Git-1.9.4-preview20140815

### New Features
* Comes with Git 1.9.4 plus Windows-specific patches.

### Bugfixes
* Update bash to patchlevel 3.1.20(4) (msysgit PR#254, msysgit issue #253).
* Fixes CVE-2014-6271, CVE-2014-7169, CVE-2014-7186 and CVE-2014-7187.
* `gitk.cmd` now works when paths contain the ampersand (&) symbol (msysgit PR #252)
* Default to automatically close and restart applications in silent mode installation type
* `git svn` is now usable again (regression in previous update, msysgit PR#245)

## Changes since Git-1.9.4-preview20140611

### New Features
* Comes with Git 1.9.4 plus Windows-specific patches
* Add vimtutor (msysgit PR #220)
* Update OpenSSH to 6.6.1p1 and its OpenSSL to 1.0.1i (msysgit PR #221, #223, #224, #226,  #229, #234, #236)
* Update mingw OpenSSL to 0.9.8zb (msysgit PR #241, #242)

### Bugfixes
* Checkout problem with directories exceeding `MAX_PATH` (PR #212, msysgit #227)
* Backport a webdav fix from _junio/maint_ (d9037e http-push.c: make CURLOPT\_IOCTLDATA a usable pointer, PR #230)

### Regressions
* `git svn` is/might be broken. Fixes welcome.

## Changes since Git-1.9.2-preview20140411

### New Features
* Comes with Git 1.9.4 plus Windows-specific patches.

### Bugfixes
* Upgrade openssl to 0.9.8za (msysgit PR #212)
* Config option to disable side-band-64k for transport (#101)
* Make `git-http-backend`, `git-http-push`, `git-http-fetch` available again (#174)

## Changes since Git-1.9.0-preview20140217

### New Features
* Comes with Git 1.9.2 plus Windows-specific patches.
* Custom installer settings can be saved and loaded, for unsupervised installation on batches of machines (msysGit PR #168).
* Comes with VIM 7.4 (msysGit PR #170).
* Comes with ZLib 1.2.8.
* Comes with xargs 4.4.2.

### Bugfixes
* Work around stack limitations when listing an insane number of tags (PR #154).
* Assorted test fixes (PRs #156, #158).
* Compile warning fix in config.c (PR #159).
* Ships with actual dos2unix and unix2dos.
* The installer no longer recommends mixing with Cygwin.
* Fixes a regression in Git-Cheetah which froze the Explorer upon calling Git Bash from the context menu (Git-Cheetah PRs #14 and #15).

## Changes since Git-1.8.5.2-preview20131230

### New Features
* Comes with Git 1.9.0 plus Windows-specific patches.
* Better work-arounds for Windows-specific path length limitations (pull request #122)
* Uses optimized TortoiseGitPLink when detected (msysGit pull request #154)
* Allow Windows users to use Linux Git on their files, using [Vagrant](http://www.vagrantup.com/) (msysGit pull request #159)
* InnoSetup 5.5.4 is now used to generate the installer (msysGit pull request #167)

### Bugfixes
* Fixed regression with interactive password prompt for remotes using the HTTPS protocol (issue #111)
* We now work around Subversion servers printing non-ISO-8601-compliant time stamps (pull request #126)
* The installer no longer sets the HOME environment variable (msysGit pull request #166)
* Perl no longer creates empty `sys$command` files when no stdin is connected (msysGit pull request #152)

## Changes since Git-1.8.4-preview20130916

### New Features
* Comes with Git 1.8.5.2 plus Windows-specific patches.
* Windows-specific patches are now grouped into pseudo-branches which should make future development robust despite slow uptake of the Windows-specific patches by upstream git.git.
* Works around more path length limitations (pull request #86)
* Has an optional `stat()` cache toggled via `core.fscache` (pull request #107)

### Bugfixes
* Lots of installer fixes
* `git-cmd`: Handle home directory on a different drive correctly (pull request #146)
* `git-cmd`: add a helper to work with the ssh agent (pull request #135)
* Git-Cheetah: prevent duplicate menu entries (pull request #7)
* No longer replaces `dos2unix` with `hd2u` (a more powerful, but slightly incompatible version of dos2unix)

## Changes since Git-1.8.3-preview20130601

### New Features
* Comes with Git 1.8.4 plus Windows specific patches.
* Enabled unicode support in bash (#42 and #79)
* Included `iconv.exe` to assist in writing encoding filters
* Updated openssl to 0.9.8y

### Bugfixes
* Avoid emitting non-printing chars to set console title.
* Various encoding fixes for the git test suite
* Ensure wincred handles empty username/password.

## Changes since Git-1.8.1.2-preview20130201

### New Features
* Comes with Git 1.8.3 plus Windows specific patches.
* Updated curl to 7.30.0 with IPv6 support enabled.
* Updated gnupg to 1.4.13
* Installer improvements for update or reinstall options.

### Bugfixes
* Avoid emitting color coded ls output to pipes.
* ccache binary updated to work on XP.
* Fixed association of .sh files setup by the installer.
* Fixed registry-based explorer menu items for XP (#95)

## Changes since Git-1.8.0-preview20121022

### New Features
* Comes with Git 1.8.1.2 plus Windows specific patches.
* Includes support for using the Windows Credential API to store access credentials securely and provide access via the control panel tool to manage git credentials.
* Rebase autosquash support is now enabled by default. See [http://goo.gl/2kwKJ](http://goo.gl/2kwKJ) for some suggestions on using this.
* All msysGit development is now done on 'master' and the devel branches are deleted.
* Tcl/Tk upgraded to 8.5.13.
* InnoSetup updated to 5.5.3 (Unicode)

### Bugfixes
* Some changes to avoid clashing with cygwin quite so often.
* The installer will attempt to handle files mirrored in the virtualstore.

## Changes since Git-1.7.11-preview20120710

### New Features
* Comes with Git 1.8.0 plus Windows specific patches.
* InnoSetup updated to 5.5.2

### Bugfixes
* Fixed icon backgrounds on low color systems
* Avoid installer warnings during writability testing.
* Fix bash prompt handling due to upstream changes.

## Changes since Git-1.7.11-preview20120704

### Bugfixes
* Propagate error codes from git wrapper (issue #43, #45)
* Include CAcert root certificates in SSL bundle (issue #37)

## Changes since Git-1.7.11-preview20120620

### New Features
* Comes with the beautiful Git logo from [http://git-scm.com/downloads/logos](http://git-scm.com/downloads/logos)
* The installer no longer asks for the directory and program group when updating
* The installer now also auto-detects TortoisePlink that comes with TortoiseGit

### Bugfixes
* Git::SVN is correctly installed again
* The default format for git help is HTML again
* Replaced the git.cmd script with an exe wrapper to fix issue #36
* Fixed executable detection to speed up help -a display.

## Changes since Git-1.7.10-preview20120409

### New Features
* Comes with Git 1.7.11 plus Windows specific patches.
* Updated curl to 7.26.0
* Updated zlib to 1.2.7
* Updated Inno Setup to 5.5.0 and avoid creating symbolic links (issue #16)
* Updated openssl to 0.9.8x and support reading certificate files from Unicode paths (issue #24)
* Version resource built into `git` executables.
* Support the Large Address Aware feature to reduce chance out-of-memory on 64 bit windows when repacking large repositories.

### Bugfixes
* Please refer to the release notes for official Git 1.7.11.
* Fix backspace/delete key handling in `rxvt` terminals.
* Fixed TERM setting to avoid a warning from `less`.
* Various fixes for handling unicode paths.

## Changes since Git-1.7.9-preview20120201

### New Features
* Comes with Git 1.7.10 plus Windows specific patches.
* UTF-8 file name support.

### Bugfixes
* Please refer to the release notes for official Git 1.7.10.
* Clarifications in the installer.
* Console output is now even thread-safer.
* Better support for foreign remotes (Mercurial remotes are disabled for now, due to lack of a Python version that can be compiled within the development environment).
* Git Cheetah no longer writes big log files directly to `C:\`.
* Development environment: enhancements in the script to make a 64-bit setup.
* Development environment: enhancements to the 64-bit Cheetah build.

## Changes since Git-1.7.8-preview20111206

### New Features
* Comes with Git 1.7.9 plus Windows specific patches.
* Improvements to the installer running application detection.

### Bugfixes
* Please refer to the release notes for official Git 1.7.9
* Fixed initialization of the git-cheetah submodule in net-installer.
* Fixed duplicated context menu items with git-cheetah on Windows 7.
* Patched gitk to display filenames when run on a subdirectory.
* Tabbed gitk preferences dialog to allow use on smaller screens.

## Changes since Git-1.7.7.1-preview20111027

### New Features
* Comes with Git 1.7.8 plus Windows specific patches.
* Updated Tcl/Tk to 8.5.11 and libiconv to 1.14
* Some changes to support building with MSVC compiler.

### Bugfixes
* Please refer to the release notes for official Git 1.7.8
* Git documentation submodule location fixed.

## Changes since Git-1.7.7-preview20111014

### New Features
* Comes with Git 1.7.7.1 plus patches.

### Bugfixes
* Please refer to the release notes for official Git 1.7.7.1
* Includes an important upstream fix for a bug that sometimes corrupts the git index file.

## Changes since Git-1.7.6-preview20110708

### New Features
* Comes with Git 1.7.7 plus patches.
* Updated gzip/gunzip and include `unzip` and `gvim`
* Primary repositories moved to [GitHub](http://github.com/msysgit/)

### Bugfixes
* Please refer to the release notes for official Git 1.7.7
* Re-enable `vim` highlighting
* Fixed issue with `libiconv`/`libiconv-2` location
* Fixed regressions in Git Bash script
* Fixed installation of mergetools for `difftool` and `mergetool` use and launching of beyond compare on windows.
* Fixed warning about mising hostname during `git fetch`

## Changes since Git-1.7.4-preview20110211

### New Features
* Comes with Git 1.7.6 plus patches.
* Updates to various supporting tools (openssl, iconv, InnoSetup)

### Bugfixes
* Please refer to the release notes for official Git 1.7.6
* Fixes to msys compat layer for directory entry handling and command line globbing.

## Changes since Git-1.7.3.2-preview20101025

### New Features
* Comes with Git 1.7.4 plus patches.
* Includes antiword to enable viewing diffs of `.doc` files
* Includes poppler to enable viewing diffs of `.pdf` files
* Removes cygwin paths from the bash shell PATH

### Bugfixes
* Please refer to the release notes for official Git 1.7.4

## Changes since Git-1.7.3.1-preview20101002

### New Features
* Comes with Git 1.7.3.2 plus patches.

## Changes since Git-1.7.2.3-preview20100911

### New Features
* Comes with Git 1.7.3.1 plus patches.
* Updated to Vim 7.3, file-5.04 and InnoSetup 5.3.11

### Bugfixes
* Issue 528 (remove uninstaller from Start Menu) was fixed
* Issue 527 (failing to find the certificate authority bundle) was fixed
* Issue 524 (remove broken and unused `sdl-config` file) was fixed
* Issue 523 (crash pushing to WebDAV remote) was fixed

## Changes since Git-1.7.1-preview20100612

### New Features
* Comes with Git 1.7.2.3 plus patches.

### Bugfixes
* Issue 519 (build problem with `compat/regex/regexec.c`) was fixed
* Issue 430 (size of panes not preserved in `git-gui`) was fixed
* Issue 411 (`git init` failing to work with CIFS paths) was fixed
* Issue 501 (failing to clone repo from root dir using relative path) was fixed

## Changes since Git-1.7.0.2-preview20100309

### New Features
* Comes with Git 1.7.1 plus patches.

### Bugfixes
* Issue 27 (`git-send-mail` not working properly) was fixed again
* Issue 433 (error while running `git svn fetch`) was fixed
* Issue 427 (Gitk reports error: "couldn't compile regular expression pattern: invalid repetition count(s)") was fixed
* Issue 192 (output truncated) was fixed again
* Issue 365 (Out of memory? mmap failed) was fixed
* Issue 387 (gitk reports "error: couldn't execute "git:" file name too long") was fixed
* Issue 409 (checkout of large files to network drive fails on XP) was fixed
* Issue 428 (The return value of `git.cmd` is not the same as `git.exe`) was fixed
* Issue 444 (Git Bash Here returns a "File not found error" in Windows 7 Professional - 64 bits) was fixed
* Issue 445 (`git help` does nothing) was fixed
* Issue 450 (`git --bare init` shouldn't set the directory to hidden.) was fixed
* Issue 456 (git script fails with error code 1) was fixed
* Issue 469 (error launch wordpad in last netinstall) was fixed
* Issue 474 (`git update-index --index-info` silently does nothing) was fixed
* Issue 482 (Add documentation to avoid "fatal: $HOME not set" error) was fixed
* Issue 489 (`git.cmd` issues warning if `%COMSPEC%` has spaces in it) was fixed
* Issue 436 (`mkdir : No such file or directory` error while using git-svn to fetch or rebase) was fixed
* Issue 440 (Uninstall does not remove cheetah.) was fixed
* Issue 441 (Git-1.7.0.2-preview20100309.exe installer fails with unwritable `msys-1.0.dll` when `ssh-agent` is running) was fixed

## Changes since Git-1.6.5.1-preview20091022

### New Features
* Comes with official Git 1.7.0.2.
* Comes with Git-Cheetah (on 32-bit Windows only, for now).
* Comes with connect.exe, a SOCKS proxy.
* Tons of improvements in the installer, thanks to Sebastian Schuberth.
* On Vista, if possible, symlinks are used for the built-ins.
* Features Hany's `dos2unix` tool, thanks to Sebastian Schuberth.
* Updated Tcl/Tk to version 8.5.8 (thanks Pat Thoyts!).
* By default, only `.git/` is hidden, to work around a bug in Eclipse (thanks to Erik Faye-Lund).

### Bugfixes
* Fixed threaded grep (thanks to Heiko Voigt).
* `git gui` was fixed for all kinds of worktree-related failures (thanks Pat Thoyts).
* `git gui` now fully supports themed widgets (thanks Pat Thoyts and Heiko Voigt).
* Git no longer complains about an unset `RUNTIME_PREFIX` (thanks Johannes Sixt).
* `git gui` can Explore Working Copy on Windows again (thanks Markus Heidelberg).
* `git gui` can create shortcuts again (fixes issue 425, thanks Heiko Voigt).
* When `git checkout` cannot overwrite files because they are in use, it will offer to try again, giving the user a chance to release the file (thanks Heiko Voigt).
* Ctrl+W will close `gitk` (thanks Jens Lehmann).
* `git gui` no longer binds Ctrl+C, which caused problems when trying to use said shortcut for the clipboard operation "Copy" (fixes issue 423, thanks Pat Thoyts).
* `gitk` does not give up when the command line length limit is reached (issue 387).
* The exit code is fixed when `Git.cmd` is called from `cmd.exe` (thanks Alexey Borzenkov).
* When launched via the (non-Cheetah) shell extension, the window icon is now correct (thanks Sebastian Schuberth).
* Uses a TrueType font for the console, to be able to render UTF-8 correctly.
* Clarified the installer's line ending options (issue 370).
* Substantially speeded up startup time from cmd unless `NO_FSTAB_THREAD` is set (thanks Johannes Sixt).
* Update `msys-1.0.dll` yet again, to handle quoted parameters better (thanks Heiko Voigt).
* Updated cURL to a version that supports SSPI.
* Updated tar to handle the pax headers generated by git archive.
* Updated sed to a version that can handle the filter-branch examples.
* `.git*` files can be associated with the default text editor (issue 397).

## Changes since Git-1.6.4-preview20090729

### New Features
* Comes with official git 1.6.5.1.
* Thanks to Johan 't Hart, files and directories starting with a single dot (such as `.git`) will now be marked hidden (you can disable this setting with core.hideDotFiles=false in your config) (Issue 288).
* Thanks to Thorvald Natvig, Git on Windows can simulate symbolic links by using reparse points when available.  For technical reasons, this only works for symbolic links pointing to files, not directories.
* A lot of work has been put into making it possible to compile Git's source code (the part written in C, of course, not the scripts) with Microsoft Visual Studio.  This work is ongoing.
* Thanks to Sebastian Schuberth, we only offer the (Tortoise)Plink option in the installer if the presence of Plink was detected and at least one Putty session was found..
* Thanks to Sebastian Schuberth, the installer has a nicer icon now.
* Some more work by Sebastian Schuberth was done on better integration of Plink (Issues 305 & 319).

### Bugfixes
* Thanks to Sebastian Schuberth, `git svn` picks up the SSH setting specified with the installer (Issue 305).

## Changes since Git-1.6.3.2-preview20090608

### New Features
* Comes with official git 1.6.4.
* Supports https:// URLs, thanks to Erik Faye-Lund.
* Supports `send-email`, thanks to Erik Faye-Lund (Issue 27).
* Updated Tcl/Tk to version 8.5.7, thanks to Pat Thoyts.

### Bugfixes
* The home directory is now discovered properly (Issues 108 & 259).
* IPv6 is supported now, thanks to Martin Martin Storsjö (Issue 182).

## Changes since Git-1.6.3-preview20090507

### New Features
* Comes with official git 1.6.3.2.
* Uses TortoisePlink instead of Plink if available.

### Bugfixes
* Plink errors out rather than hanging when the user needs to accept a host key first (Issue 96).
* The user home directory is inferred from `$HOMEDRIVE\$HOMEPATH` instead of `$HOME` (Issue 108).
* The environment setting `$CYGWIN=tty` is ignored (Issues 138, 248 and 251).
* The `ls` command shows non-ASCII filenames correctly now (Issue 188).
* Adds more syntax files for vi (Issue 250).
* `$HOME/.bashrc` is included last from `/etc/profile`, allowing `.bashrc` to override all settings in `/etc/profile` (Issue 255).
* Completion is case-insensitive again (Issue 256).
* The `start` command can handle arguments with spaces now (Issue 258).
* For some Git commands (such as `git commit`), `vi` no longer "restores" the cursor position.

## Changes since Git-1.6.2.2-preview20090408

### New Features
* Comes with official git 1.6.3.
* Thanks to Marius Storm-Olsen, Git has a substantially faster `readdir()` implementation now.
* Marius Storm-Olsen also contributed a patch to include `nedmalloc`, again speeding up Git noticably.
* Compiled with GCC 4.4.0

### Bugfixes
* Portable Git contains a `README.portable`.
* Portable Git now actually includes the builtins.
* Portable Git includes `git-cmd.bat` and `git-bash.bat`.
* Portable Git is now shipped as a `.7z`; it still is a self-extracting archive if you rename it to `.exe`.
* Git includes the Perl Encode module now.
* Git now includes the `filter-branch` tool.
* There is a workaround for a Windows 7 regression triggering a crash in the progress reporting (e.g. during a clone). This fixes issues 236 and 247.
* `gitk` tries not to crash when it is closed while reading references (Issue 125, thanks Pat Thoyts).
* In some setups, hard-linking is not as reliable as it should be, so we have a workaround which avoids hard links in some situations (Issues 222 and 229).
* `git-svn` sets `core.autocrlf` to `false` now, hopefully shutting up most of the `git-svn` reports.

## Changes since Git-1.6.2.1-preview20090322

### New Features
* Comes with official git 1.6.2.2.
* Upgraded Tcl/Tk to 8.5.5.
* TortoiseMerge is supported by mergetool now.
* Uses pthreads (faster garbage collection on multi-core machines).
* The test suite passes!

### Bugfixes
* Renaming was made more robust (due to Explorer or some virus scanners, files could not be renamed at the first try, so we have to try multiple times).
* Johannes Sixt made lots of changes to the test-suite to identify properly which tests should pass, and which ones cannot pass due to limitations of the platform.
* Support `PAGER`s with spaces in their filename.
* Quite a few changes were undone which we needed in the olden days of msysGit.
* Fall back to `/` when HOME cannot be set to the real home directory due to locale issues (works around Issue 108 for the moment).

## Changes since Git-1.6.2-preview20090308

### New Features
* Comes with official git 1.6.2.1.
* A portable application is shipped in addition to the installer (Issue 195).
* Comes with a Windows-specific `mmap()` implementation (Issue 198).

### Bugfixes
* ANSI control characters are no longer shown verbatim (Issue 124).
* Temporary files are created respecting `core.autocrlf` (Issue 177).
* The Git Bash prompt is colorful again (Issue 199).
* Fixed crash when hardlinking during a clone failed (Issue 204).
* An infinite loop was fixed in `git-gui` (Issue 205).
* The ssh protocol is always used with `plink.exe` (Issue 209).
* More vim files are shipped now, so that syntax highlighting works.

## Changes since Git-1.6.1-preview20081225

### New Features
* Comes with official git 1.6.2.
* Comes with upgraded vim 7.2.
* Compiled with GCC 4.3.3.
* The user can choose the preferred CR/LF behavior in the installer now.
* Peter Kodl contributed support for hardlinks on Windows.
* The bash prompt shows information about the current repository.

### Bugfixes
* If supported by the file system, pack files can grow larger than 2gb.
* Comes with updated `msys-1.0.dll` (should fix some Vista issues).
* Assorted fixes to support the new `libexec/git-core/` layout better.
* Read-only files can be properly replaced now.
* `git-svn` is included again (original caveats still apply).
* Obsolete programs from previous installations are cleaned up.

## Changes since Git-1.6.0.2-preview20080923

### New Features
* Comes with official git 1.6.1.
* Avoid useless console windows.
* Installer remembers how to handle PATH. 

## Changes since Git-1.6.0.2-preview20080921

### Bugfixes
* ssh works again.
* `git add -p` works again.
* Various programs that aborted with `Assertion failed: argv0_path` are fixed.

## Changes since Git-1.5.6.1-preview20080701

* Removed Features
* `git svn` is excluded from the end-user installer (see Known Issues).

### New Features
* Comes with official git 1.6.0.2.

### Bugfixes
* No Windows-specific bugfixes.

## Changes since Git-1.5.6-preview20080622

### New Features
* Comes with official git 1.5.6.1.

### Bugfixes
* Includes fixed `msys-1.0.dll` that supports Vista and Windows Server 2008 (Issue 122).
* cmd wrappers do no longer switch off echo.

## Changes since Git-1.5.5-preview20080413

### New Features
* Comes with official git 1.5.6.
* Installer supports configuring a user provided Plink (PuTTY).

### Bugfixes
* Comes with tweaked `msys-1.0.dll` to solve some command line mangling issues.
* cmd wrapper does no longer close the command window.
* Programs in the system `PATH`, for example editors, can be launched from Git without specifying their full path.
* `git stash apply stash@{1}` works.
* Comes with basic ANSI control code emulation for the Windows console to avoid wrapping of pull/merge's diffstats.
* Git correctly passes port numbers to PuTTY's Plink 

## Changes since Git-1.5.4-preview20080202

### New Features
* Comes with official git 1.5.5.
* `core.autocrlf` is enabled (`true`) by default. This means git converts to Windows line endings (CRLF) during checkout and converts to Unix line endings (LF) during commit. This is the right choice for cross-platform projects. If the conversion is not reversible, git warns the user. The installer warns about the new default before the installation starts.
* The user does no longer have to "accept" the GPL but only needs to press "continue".
* Installer deletes shell scripts that have been replaced by builtins. Upgrading should be safer.
* Supports `git svn`. Note that the performance might be below your expectation.

### Bugfixes
* Newer ssh fixes connection failures (issue 74).
* Comes with MSys-1.0.11-20071204.  This should solve some "fork: resource unavailable" issues.
* All DLLs are rebased to avoid problems with "fork" on Vista.

## Changes since Git-1.5.3.6-preview20071126

### New Features
* Comes with official git 1.5.4.
* Some commands that are not yet suppoted on Windows are no longer included (see Known Issues above).
* Release notes are displayed in separate window.
* Includes `qsort` replacement to improve performance on Windows 2000.

### Bugfixes
* Fixes invalid error message that setup.ini cannot be deleted on uninstall.
* Setup tries harder to finish the installation and reports more detailed errors.
* Vim's syntax highlighting is suitable for dark background.

## Changes since Git-1.5.3.5-preview20071114

### New Features
* Git is included in version 1.5.3.6.
* Setup displays release notes.

### Bugfixes
* `pull`/`fetch`/`push` in `git-gui` works. Note, there is no way for `ssh` to ask for a passphrase or for confirmation if you connect to an unknown host. So, you must have ssh set up to work without passphrase. Either you have a key without passphrase, or you started ssh-agent. You may also consider using PuTTY by pointing `GIT_SSH` to `plink.exe` and handle your ssh keys with Pageant. In this case you should include your login name in urls. You must also connect to an unknown host once from the command line and confirm the host key, before you can use it from `git-gui`.

## Changes since Git-1.5.3-preview20071027

### New Features
* Git is included in version 1.5.3.5.
* Setup can be installed as normal user.
* When installing as Administrator, all icons except the Quick Launch icon will be created for all users.
* `git help user-manual` displays the user manual.

### Bugfixes
* Git Bash works on Windows XP 64.

## Changes since Git-1.5.3-preview20071019

### Bugfixes
* The templates for a new repository are found.
* The global configuration `/etc/gitconfig` is found.
* Git Gui localization works. It falls back to English if a translation has errors.

## Changes since WinGit-0.2-alpha
* The history of the release notes stops here. Various new features and bugfixes are available since WinGit-0.2-alpha. Please check the git history of the msysgit project for details.
