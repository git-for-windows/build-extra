# Git for Windows v2.21.0 Release Notes
Latest update: February 26th 2019

## Introduction

These release notes describe issues specific to the Git for Windows release. The release notes covering the history of the core git commands can be found [in the Git project](https://github.com/git/git/tree/master/Documentation/RelNotes).

See [http://git-scm.com/](http://git-scm.com/) for further details about Git including ports to other operating systems. Git for Windows is hosted at [https://gitforwindows.org/](https://gitforwindows.org/).

# Known issues
* Special permissions (and Windows Vista or later) are required when cloning repositories with symbolic links, therefore support for symbolic links is disabled by default. Use `git clone -c core.symlinks=true <URL>` to enable it, see details [here](https://github.com/git-for-windows/git/wiki/Symbolic-Links).
* If configured to use Plink, you will have to connect with [putty](http://www.chiark.greenend.org.uk/~sgtatham/putty/) first and accept the host key.
* Some console programs, most notably non-MSYS2 Python, PHP, Node and OpenSSL, interact correctly with MinTTY only when called through `winpty` (e.g. the Python console needs to be started as `winpty python` instead of just `python`).
* [cURL](http://curl.haxx.se) uses `$HOME/_netrc` instead of `$HOME/.netrc`.
* If you specify command-line options starting with a slash, POSIX-to-Windows path conversion will kick in converting e.g. "`/usr/bin/bash.exe`" to "`C:\Program Files\Git\usr\bin\bash.exe`". When that is not desired -- e.g. "`--upload-pack=/opt/git/bin/git-upload-pack`" or "`-L/regex/`" -- you need to set the environment variable `MSYS_NO_PATHCONV` temporarily, like so:

  > `MSYS_NO_PATHCONV=1 git blame -L/pathconv/ msys2_path_conv.cc`

  Alternatively, you can double the first slash to avoid POSIX-to-Windows path conversion, e.g. "`//usr/bin/bash.exe`".
* Windows drives are normally recognised within the POSIX path as `/c/path/to/dir/` where `/c/` (or appropriate drive letter) is equivalent to the `C:\` Windows prefix to the `\path\to\dir`. If this is not recognised, revert to the `C:\path\to\dir` Windows style.
* Git for Windows will not allow commits containing DOS-style truncated 8.3-format filenames ending with a tilde and digit, such as `mydocu~1.txt`. A workaround is to call `git config core.protectNTFS false`, which is not advised. Instead, add a rule to .gitignore to ignore the file(s), or rename the file(s).
* Many Windows programs (including the Windows Explorer) have problems with directory trees nested so deeply that the absolute path is longer than 260 characters. Therefore, Git for Windows refuses to check out such files by default. You can overrule this default by setting `core.longPaths`, e.g. `git clone -c core.longPaths=true ...`.
*   Some commands are not yet supported on Windows and excluded from the installation.
*   As Git for Windows is shipped without Python support, all Git commands requiring Python are not yet supported; e.g. `git p4`.
*   The Quick Launch icon will only be installed for the user running setup (typically the Administrator). This is a technical restriction and will not change.
*   The git-core executable file(s) are typically double-counted by Windows Explorer. In fact, repeated files are hard linked, so do not take up the space indicated (#1977).

Should you encounter other problems, please search [the bug tracker](https://github.com/git-for-windows/git/issues) and [the mailing list](http://groups.google.com/group/git-for-windows), chances are that the problem was reported already. If it has not been reported, please follow [our bug reporting guidelines](https://github.com/git-for-windows/git/wiki/Issue-reporting-guidelines) and [report the bug](https://github.com/git-for-windows/git/issues/new).

## Licenses
Git is licensed under the GNU General Public License version 2.

Git for Windows also contains Embedded CAcert Root Certificates. For more information please go to [https://www.cacert.org/policy/RootDistributionLicense.php](https://www.cacert.org/policy/RootDistributionLicense.php).

This package contains software from a number of other projects including Bash, zlib, curl, tcl/tk, perl, MSYS2 and a number of libraries and utilities from the GNU project, licensed under the GNU General Public License. Likewise, it contains Perl which is dual licensed under the GNU General Public License and the Artistic License.

## Changes since Git for Windows v2.21.0 (February 26th 2019)

### New Features

* The `awk` included in Git for Windows [now includes extensions](https://github.com/git-for-windows/build-extra/pull/232) such as `inplace`.
* The file/product version stored in the installer's `.exe` file [now matches the version of the included `git.exe` file's](https://github.com/git-for-windows/build-extra/pull/235).
* Comes with [git-flow v1.12.2](https://github.com/petervanderdoes/gitflow-avh/releases/tag/1.12.2).
* Comes with [Git Credential Manager v1.18.5](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/1.18.5).
* Comes with [cURL v7.64.1](https://curl.haxx.se/changes.html#7_64_1).
* Comes with [GNU Privacy Guard vv2.2.15](https://lists.gnupg.org/pipermail/gnupg-announce/2019q1/000436.html), specifically [patched to handle Windows paths](https://github.com/git-for-windows/MSYS2-packages/pull/33).
* Comes with [OpenSSL v1.1.1b](https://www.openssl.org/news/openssl-1.1.1-notes.html).
* Comes with [patch level 2](https://github.com/git-for-windows/msys2-runtime/commit/1c8b1f5d16a54d50d872a01b76351e5e4656d7d9) of the MSYS2 runtime (Git for Windows flavor) based on [Cygwin 3.0.6](https://cygwin.com/ml/cygwin-announce/2019-04/msg00012.html).

### Bug Fixes

* Git for Windows' updater [is now accessible](https://github.com/git-for-windows/build-extra/pull/234), i.e. it can be read by a screen reader.
* `git update-git-for-windows` (i.e. the auto updater of Git for Windows) now [reports correctly when it failed to access the GitHub API](https://github.com/git-for-windows/build-extra/pull/239).
* Git for Windows' updater [no longer runs into GitHub API rate limits](https://github.com/git-for-windows/build-extra/pull/242) (this used to be quite common in enterprise scenarios, where many users would share one IP as far as GitHub is concerned).

## Changes since Git for Windows v2.20.1 (December 15th 2018)

### New Features

* Comes with [Git v2.21.0](https://github.com/git/git/blob/v2.21.0/Documentation/RelNotes/2.21.0.txt).
* The custom editor setting in the installer [has been improved substantially](https://github.com/git-for-windows/build-extra/pull/221).
* Comes with [Git Credential Manager v1.18.4.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/1.18.4.0).
* Comes with [cURL v7.64.0](https://curl.haxx.se/changes.html#7_64_0).
* Comes with [git-flow v1.12.0](https://github.com/petervanderdoes/gitflow-avh/releases/tag/1.12.0).
* `git archive` [no longer requires `gzip` to generate `.tgz` archives](https://github.com/git-for-windows/git/pull/2077) (this means in particular that it works in MinGit).
* System-wide Sublime Text installations [are now detected](https://github.com/git-for-windows/build-extra/commit/396b283cc6231589b0b034d4ca4b241b25163e9a) and offered on the editor wizard page.
* Comes with [Git LFS v2.7.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.7.1).

### Bug Fixes

* The `Git CMD` deprecation [was further clarified](https://github.com/git-for-windows/build-extra/pull/222) to mention that the *Start Menu item* is deprecated, not using Git from CMD.
* Certain drivers/anti-malware caused `git.exe` to hang, which [has been fixed](https://github.com/git-for-windows/MINGW-packages/pull/32).
* `git stash` [now works](https://github.com/git-for-windows/git/issues/2006) after staging files with `git add -N`.
* A problem with `difftool` and more than a handful modified files [has been fixed](https://github.com/git-for-windows/git/pull/2026).
* The regression where `git-cmd <command>` would not execute the command [was fixed](https://github.com/git-for-windows/git/issues/2039).
* Portable Git [can be launched via network paths again](https://github.com/git-for-windows/git/issues/2036).
* FSCache works again [on network drives](https://github.com/git-for-windows/git/issues/2022), in particular [when Windows 8.1 or older](https://github.com/git-for-windows/git/issues/1989) are involved.
* Partially hidden text in the `Path` options page in the installer [is no longer hidden](https://github.com/git-for-windows/git/issues/2049).
* Fixes [an obscure `git svn` hang](https://github.com/git-for-windows/git/issues/1993).
* The installer [now configures editors so that the built-in rebase can use them](https://github.com/git-for-windows/git/issues/2011).

## Changes since Git for Windows v2.20.0 (December 10th 2018)

### New Features

* Comes with [Git v2.20.1](https://github.com/git/git/blob/v2.20.1/Documentation/RelNotes/2.20.1.txt).
* Comes with [cURL v7.63.0](https://curl.haxx.se/changes.html#7_63_0).

### Bug Fixes

* [Fixes](https://github.com/git-for-windows/git/pull/1983) a speed regression in the built-in rebase.

## Changes since Git for Windows v2.19.2 (November 21st 2018)

Please note that Git for Windows v2.19.2 was offered as a full release only for about a week, and then demoted to "pre-release" status, as it had two rather big regressions: 32-bit Git Bash crashed, and git:// was broken.

### New Features

* Comes with [Git v2.20.0](https://github.com/git/git/blob/v2.20.0/Documentation/RelNotes/2.20.0.txt).
* Comes with [OpenSSL v1.1.1a](https://www.openssl.org/news/openssl-1.1.1-notes.html). The OpenSSH, cURL and Heimdal packages were rebuilt to make use of OpenSSL v1.1.1a.
* The FSCache feature [was further optimized in particular for very large repositories](https://github.com/git-for-windows/git/pull/1937).
* To appease certain anti-malware, MinTTY was recompiled with a patch to avoid [GCC trampolines](https://github.com/git-for-windows/MSYS2-packages/commit/63f68558c9c6a6c7765c18dacbbcac328748eb30).
* Comes with [Git LFS v2.6.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.6.1).
* Comes with [Bash v4.4 patchlevel 023 ](https://tiswww.case.edu/php/chet/bash/NEWS).
* Commands to interact with CVS repositories were considered obsolete [and have been removed](https://github.com/git-for-windows/build-extra/commit/59b521a3b).
* The desired HTTP version (HTTP/2 or HTTP/1.1) [can now be configured via the `http.version` setting](https://github.com/git-for-windows/git/pull/1968).

### Bug Fixes

* Git CMD [no longer picks up `git.exe` from the current directory (if any)](https://github.com/git-for-windows/git/issues/1945).
* Git Bash [works again in 32-bit Git for Windows](https://github.com/git-for-windows/MINGW-packages/commit/deb0395d031401ffe55024fb066267e2ea8d032b).
* Git can now [access `git://` remotes again](https://github.com/git-for-windows/git/issues/1949).
* The confusing descriptions of the PATH options in the installer [were clarified](https://github.com/git-for-windows/build-extra/pull/216).
* A bug in the `notepad` support in conjunction with line wrapping [was fixed](https://github.com/git-for-windows/build-extra/pull/218).
* Comes two backported fixes to [allow NTLM/Kerberos authentication to fall back to HTTP/1.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/issues/812).
* It is [now possible to call `cmd\git.exe` via a symbolic link](https://github.com/git-for-windows/git/issues/1650).

## Changes since Git for Windows v2.19.1 (Oct 5th 2018)

* The _Git CMD_ start menu shortcut is deprecated and will be dropped in future version. Note that the deprecation only affects the shortcut; `git-cmd.exe` will continue to be distributed and installed.

### New Features

* Comes with [Git v2.19.2](https://github.com/git/git/blob/v2.19.2/Documentation/RelNotes/2.19.2.txt).
* Comes with [OpenSSH v7.9p1](https://www.openssh.com/txt/release-7.9).
* The description of the editor option to choose Vim [has been clarified](https://github.com/git-for-windows/build-extra/pull/207) to state that this *unsets* `core.editor`.
* Comes with [cURL v7.62.0](https://curl.haxx.se/changes.html#7_62_0).
* The type of symlinks to create (directory or file) [can now be specified via the `.gitattributes`](https://github.com/git-for-windows/git/pull/1897).
* The FSCache feature [now uses a faster method to enumerate files](https://github.com/git-for-windows/git/pull/1908), making e.g. `git status` faster in large repositories.
* Comes with [Git Credential Manager v1.18.3](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/1.18.3).
* Comes with [Git LFS v2.6.0](https://github.com/git-lfs/git-lfs/releases/tag/v2.6.0).
* Comes with MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.11.2](https://cygwin.com/ml/cygwin-announce/2018-11/msg00007.html).
* The FSCache feature [was optimized to become faster](https://github.com/git-for-windows/git/pull/1926).

### Bug Fixes

* The 64-bit Portable Git [no longer sets `pack.packSizeLimit`](https://github.com/git-for-windows/build-extra/pull/212).

## Changes since Git for Windows v2.19.0 (September 11th 2018)

### New Features

* Comes with [Git v2.19.1](https://github.com/git/git/blob/v2.19.1/Documentation/RelNotes/2.19.1.txt).
* Comes with [Git LFS v2.5.2](https://github.com/git-lfs/git-lfs/releases/tag/v2.5.2).
* When FSCache is enabled, commands such as `add`, `commit`, and `reset` [are now much faster](https://github.com/git-for-windows/git/pull/1827).
* Sublime Text, Atom, and even the new user-specific VS Code installations [can now be used as Git's default editor](https://github.com/git-for-windows/build-extra/pull/200).
* Comes with [Git Credential Manager v1.18.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.18.0).

### Bug Fixes

* Several corner case bugs [were fixed](https://github.com/git-for-windows/git/pull/1852) in the built-in `rebase`/`stash` commands.
* An [occasional crash in `git gc`](https://github.com/git-for-windows/git/issues/1839) (which had been introduced into v2.19.0) has been fixed.

## Changes since Git for Windows v2.18.0 (June 22nd 2018)

### New Features

* Comes with [Git v2.19.0](https://github.com/git/git/blob/v2.19.0/Documentation/RelNotes/2.19.0.txt).
* There are now *fast*, built-in versions of `git stash` and `git rebase`, [available as experimental options](https://github.com/git-for-windows/build-extra/pull/203).
* The included OpenSSH client [now enables modern ciphers](https://github.com/git-for-windows/build-extra/pull/192).
* The `gitweb` component was removed because it is highly unlikely to be used on Windows.
* The `git archimport` tool (which was probably used by exactly 0 users) is [no longer included in Git for Windows](https://github.com/git-for-windows/build-extra/pull/202).
* Comes with [tig v2.4.0](https://github.com/jonas/tig/releases/tag/tig-2.4.0).
* Comes with [Git LFS v2.5.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.5.1).
* Comes with [Git Credential Manager v1.17.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.17.1).
* Comes with [OpenSSL v1.0.2p](https://www.openssl.org/news/openssl-1.0.2-notes.html).
* Comes with [cURL v7.61.1](https://curl.haxx.se/changes.html#7_61_1).
* Comes with [mingw-w64-nodejs v8.12.0](https://nodejs.org/en/blog/release/v8.12.0/).

### Bug Fixes

* The `http.schannel.checkRevoke` setting (which never worked) [was renamed to `http.schannelCheckRevoke`](https://github.com/git-for-windows/git/pull/1747). In the same run, `http.schannel.useSSLCAInfo` (which also did not work, for the same reason) was renamed to `http.schannelUseSSLCAInfo`.
* [Avoids](https://github.com/git-for-windows/msys2-runtime/commit/f02cd2463d2c7e03fe97b8a1ce35ecffd0714f7e) a stack overflow with recent Windows Insider versions.
* Git GUI [now handles hooks correctly](https://github.com/git-for-windows/git/issues/1755) in worktrees other than the main one.
* When using `core.autocrlf`, the bogus "LF will be replaced by CRLF" warning [is now suppressed](https://github.com/git-for-windows/git/issues/1242).
* The funny [`fatal error -cmalloc would have returned NULL` problems](https://github.com/git-for-windows/git/issues/356) should be gone.

## Changes since Git for Windows v2.17.1(2) (May 29th 2018)

### New Features

* Comes with [Git v2.18.0](https://github.com/git/git/blob/v2.18.0/Documentation/RelNotes/2.18.0.txt).
* Comes with [Git Credential Manager v1.16.2](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.16.2).

### Bug Fixes

* The diff filter for `.pdf` files [was fixed](https://github.com/git-for-windows/build-extra/pull/189).
* The `start-ssh-agent.cmd` script [no longer overrides the `HOME` variable](https://github.com/git-for-windows/MINGW-packages/pull/26).
* Fixes an issue where passing an argument with a trailing slash from Git Bash to `git.exe` [was dropping that trailing slash](https://github.com/git-for-windows/git/issues/1695).
* The `http.schannel.checkRevoke` setting [now really works](https://github.com/git-for-windows/git/issues/1531).

## Changes since Git for Windows v2.17.1 (May 29th 2018)

### New Features

* Comes with [Git Credential Manager v1.16.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.16.1).
* Comes with [Git LFS v2.4.2](https://github.com/git-lfs/git-lfs/releases/tag/v2.4.2).

### Bug Fixes

* This release *really* contains Git v2.17.1.

## Changes since Git for Windows v2.17.0 (April 3rd 2018)

### New Features

* Comes with [Git v2.17.1](https://github.com/git/git/blob/v2.17.1/Documentation/RelNotes/2.17.1.txt).
* Comes with [Perl v5.26.2](http://search.cpan.org/dist/perl-5.26.2/pod/perldelta.pod).
* The installer [now offers VS Code Insiders as option for Git's default editor](https://github.com/git-for-windows/build-extra/pull/181) if it is installed.
* The vim configuration [was modernized](https://github.com/git-for-windows/build-extra/pull/186).
* Comes with [cURL v7.60.0](https://curl.haxx.se/changes.html#7_60_0).
* Certain errors, e.g. when pushing failed due to a non-fast-forwarding change, [are now colorful](https://github.com/git-for-windows/git/pull/1429).
* Comes with [Git LFS v2.4.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.4.1).

### Bug Fixes

* Fixed an issue with recursive clone ([CVE 2018-11235](https://aka.ms/cve-2018-11235)).
* Aliases that expand to shell commands [can now take arguments containing curly brackets](https://github.com/git-for-windows/git/pull/1637).
* Ctrl+C is now handled in Git Bash [in a sophisticated way](https://github.com/git-for-windows/msys2-runtime/commit/78e2deea8ec1db4aea1e78432ae98dac7198f6a5): it emulates the way Ctrl+C is handled in Git CMD, but in a fine-grained way.
* Based on the [the new Ctrl+C handling in Git Bash](https://github.com/git-for-windows/msys2-runtime/commit/78e2deea8ec1db4aea1e78432ae98dac7198f6a5), pressing Ctrl+C while `git log` is running will only stop Git from traversing the commit history, [but keep the pager running](https://github.com/git-for-windows/git/commit/df8884cbc5c39073848ddf2058bafeea1188312b).
* Git was [fixed](https://github.com/git-for-windows/git/pull/1645) to work correctly in Docker volumes inside Windows containers.
* Tab completion of `git status -- <partial-path>` [is now a lot faster](https://github.com/git-for-windows/git/issues/1533).
* Git for Windows [now creates directory symlinks correctly](https://github.com/git-for-windows/git/pull/1651) when asked to.
* The option to disable revocation checks with Secure Channel which was introduced in v2.16.1(2) [now really works](https://github.com/git-for-windows/git/issues/1531).
* Git [no longer enters an infinite loop](https://github.com/git-for-windows/git/issues/1496) when misspelling `git status` as, say, `git Status`.

## Changes since Git for Windows v2.16.3 (March 23rd 2018)

### New Features

* Comes with [Git v2.17.0](https://github.com/git/git/blob/v2.17.0/Documentation/RelNotes/2.17.0.txt).
* Comes with [OpenSSL v1.0.2o](https://www.openssl.org/news/openssl-1.0.2-notes.html).
* Comes with [Git Credential Manager v1.15.2](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.15.2).
* Comes with [OpenSSH v7.7p1](https://www.openssh.com/txt/release-7.7).

### Bug Fixes

* When `git.exe` is called with an invalid subcommand,  [it no longer complains about file handles](https://github.com/git-for-windows/git/issues/1591).

## Changes since Git for Windows v2.16.2 (February 20th 2018)

### New Features

* Comes with [Git v2.16.3](https://github.com/git/git/blob/v2.16.3/Documentation/RelNotes/2.16.3.txt).
* When choosing to "Use Git from the Windows Command Prompt" (i.e. add only the minimal set of Git executables to the `PATH`), and when choosing the Git LFS component, Git LFS [is now included in that minimal set](https://github.com/git-for-windows/git/issues/1503). This makes it possible to reuse Git for Windows' Git LFS, say, from Visual Studio.
* Comes with [gawk v4.2.1](http://git.savannah.gnu.org/cgit/gawk.git/plain/NEWS?h=gawk-4.2.1).
* In conjunction with the FSCache feature, `git checkout` [is now a lot faster when checking out a *lot* of files](https://github.com/git-for-windows/git/pull/1468).
* Comes with [Git LFS v2.4.0](https://github.com/git-lfs/git-lfs/releases/tag/v2.4.0).
* Comes with [Git Credential Manager v1.15.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.15.0).
* Comes with [cURL v7.59.0](https://curl.haxx.se/changes.html#7_59_0).
* The Git for Windows SDK [can now be "installed" via `git clone --depth=1 https://github.com/git-for-windows/git-sdk-64`](https://github.com/git-for-windows/git/issues/1357).
* The `tar` utility (included as a courtesy, not because Git needs it) [can now unpack `.tar.xz` archives](https://github.com/git-for-windows/build-extra/pull/177).

### Bug Fixes

* When a `TERM` is configured that Git for Windows does not know about, [Bash no longer crashes](https://github.com/git-for-windows/git/issues/1473).
* The regression where `gawk` stopped treating Carriage Returns as part of the line endings [was fixed](https://github.com/git-for-windows/git/issues/1524).
* When Git asks for credentials via the terminal in a Powershell window, [it no longer fails to do so](https://github.com/git-for-windows/git/pull/1514).
* The installer [is now more robust when encountering files that are in use](https://github.com/git-for-windows/build-extra/commit/d33ee8606bfbc0e9b801df0a5257721e20f8dd4a) (and can therefore not be overwritten right away).
* The included `find` and `rm` utilities [no longer have problems with deeply nested directories on FAT drives](https://github.com/git-for-windows/git/issues/1497).
* The `cygpath` utility included in Git for Windows now strips trailing slashes when normalizing paths (just like the Cygwin version of the utility; this is *different* from how MSYS2 chooses to do things).
* The certificates of HTTPS proxies configured via `http.proxy` [are now validated against the `ca-bundle.crt` correctly](https://github.com/git-for-windows/git/issues/1493).

## Changes since Git for Windows v2.16.1(4) (February 7th 2018)

### New Features

* Comes with [Git v2.16.2](https://github.com/git/git/blob/v2.16.2/Documentation/RelNotes/2.16.2.txt).
* For every new Git for Windows version, `.zip` archives containing `.pdb` files for some of Git for Windows' components [are now published alongside the new version](https://github.com/git-for-windows/build-extra/commit/0af1701ba3329151ae8b21fa43d4f4abca11cc26).
* Comes with MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.10.0](https://cygwin.com/ml/cygwin-announce/2018-02/msg00002.html); This required rebuilding OpenSSH, Perl (and some Perl modules) and Subversion.
* Comes with [Bash v4.4 patchlevel 019 ](https://tiswww.case.edu/php/chet/bash/NEWS).

### Bug Fixes

* The Perl upgrade in Git for Windows v2.16.1(4) [broke interactive authentication of `git svn`](https://github.com/git-for-windows/git/issues/1488), which was fixed.
* When configuring HTTPS transport to use Secure Channel, [we now refrain from configuring `http.sslCAInfo`](https://github.com/git-for-windows/build-extra/pull/172). This also helps Git LFS (which uses Git for Windows' private `http.sslCAInfo` setting) to use the same credentials as `git fetch` and `git push`.

## Changes since Git for Windows v2.16.1(3) (February 6th 2018)

### Bug Fixes

* When called from TortoiseGit, `git.exe` [can now spawn processes again](https://github.com/git-for-windows/git/issues/1481).

## Changes since Git for Windows v2.16.1(2) (February 2nd 2018)

### New Features

* Git for Windows' SDK packages [are now hosted on Azure Blobs](https://github.com/git-for-windows/build-extra/commit/53695c41ec95f49c191b7792eee6fc8d91846ed8), fixing part of [issue #1479](https://github.com/git-for-windows/git/issues/1479).
* Comes with [perl-Net-SSLeay v1.84](https://metacpan.org/source/MIKEM/Net-SSLeay-1.84/Changes).

### Bug Fixes

* When `http.sslBackend` is not configured (e.g. in portable Git or MinGit), fetch/push operations [no longer crash](https://github.com/git-for-windows/git/issues/1474).
* On Windows 7 and older, Git for Windows v2.16.1(2) was no longer able to spawn any processes (e.g. during fetch/clone). This regression [has been fixed](https://github.com/git-for-windows/git/issues/1475).
* The Perl upgrade in v2.16.1(2) broke `git send-email`; This [has been fixed](https://github.com/git-for-windows/git/issues/1480) by updating the Net-SSLeay Perl module.

## Changes since Git for Windows v2.16.1 (January 22nd 2018)

### New Features

* Comes with [Heimdal v7.5.0](http://h5l.org/releases.html).
* Comes with [cURL v7.58.0](https://curl.haxx.se/changes.html#7_58_0).
* Comes with [Perl v5.26.1](http://search.cpan.org/dist/perl-5.26.1/pod/perldelta.pod).
* When using GNU nano as Git's default editor, [it is now colorful (shows syntax-highlighting)](https://github.com/git-for-windows/build-extra/pull/169).
* Comes with [tig v2.3.3](https://github.com/jonas/tig/releases/tag/tig-2.3.3).
* When using Secure Channel as HTTPS transport behind a proxy, it may be necessary to disable revocation checks, [which is now possible](https://github.com/git-for-windows/git/pull/1450).
* Comes with [BusyBox v1.28.0pre.16550.0b3cdd76c](https://github.com/git-for-windows/busybox-w32/commit/0b3cdd76c).

### Bug Fixes

* When Git spawns processes, [now only the necessary file handles are inherited from the parent process](https://github.com/git-for-windows/git/commit/576ff26eeca22526b7ba11444da24d31daf0b369), possibly preventing file locking issues.
* The `git update` command [has been renamed to `git update-git-for-windows`](https://github.com/git-for-windows/build-extra/pull/167) to avoid confusion where users may think that `git update` updates their local repository or worktree.

## Changes since Git for Windows v2.16.0(2) (January 18th 2018)

This is a hotfix release, based on upstream Git's hotfix to address a possible segmentation fault associated with case-insensitive file systems.

Note: another hotfix might be coming the day after tomorrow, as cURL announced a new version addressing security advisories that *might* affect how Git talks via HTTP/HTTPS, too.

### New Features

* Comes with [Git v2.16.1](https://github.com/git/git/blob/v2.16.1/Documentation/RelNotes/2.16.1.txt).


### Bug Fixes

* A set of regressions introduced by patches intended to speed up `reset` and `checkout` was fixed (issues [#1437](https://github.com/git-for-windows/git/issues/1437), [#1438](https://github.com/git-for-windows/git/issues/1438), [#1440](https://github.com/git-for-windows/git/issues/1440) and [#1442](https://github.com/git-for-windows/git/issues/1442)).

## Changes since Git for Windows v2.15.1(2) (November 30th 2017)

Git for Windows now has a new homepage: [https://gitforwindows.org/](https://gitforwindows.org/) (it is still graciously hosted by GitHub, but now much quicker to type).

### New Features

* Comes with [Git v2.16.0](https://github.com/git/git/blob/v2.16.0/Documentation/RelNotes/2.16.0.txt).
* Comes with [Git Credential Manager v1.14.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.14.0).
* The Git for Windows installer [now offers to configure Visual Studio Code as default editor for Git](https://github.com/git-for-windows/git/issues/1356).
* Comes with [OpenSSL v1.0.2n](https://www.openssl.org/news/openssl-1.0.2-notes.html).
* `git checkout` [is now a lot faster when checking out a *lot* of files](https://github.com/git-for-windows/git/pull/1419).
* The `core.excludesfile` [can now reference a symbolic link](https://github.com/git-for-windows/git/issues/1392).
* Comes with [patch level 7](https://github.com/git-for-windows/msys2-runtime/commit/c967bd8e37af7fa86f8ed1ded2625071612b808a) of the MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.9.0](https://cygwin.com/ml/cygwin-announce/2017-09/msg00056.html).
* With lots of files, `git reset --hard` [is now a lot faster](https://github.com/git-for-windows/git/pull/1427) when the FSCache feature is in effect.

### Bug Fixes

* When cloning into an existing (empty) directory fails, [Git no longer removes said directory](https://github.com/git-for-windows/git/pull/1421).
* Interrupting processes (and their children) using Control+C [is now a lot more robust](https://github.com/git-for-windows/msys2-runtime/pull/16).

## Changes since Git for Windows v2.15.1 (November 29th 2017)

### Bug Fixes

* The bug introduced into Git for Windows v2.15.1 where `vim` would show an ugly warning upon startup [was fixed](https://github.com/git-for-windows/git/issues/1382).

## Changes since Git for Windows v2.15.0 (October 30th 2017)

### New Features

* Comes with [Git v2.15.1](https://github.com/git/git/blob/v2.15.1/Documentation/RelNotes/2.15.1.txt).
* Operations in massively-sparse worktrees [are now much faster if `core.fscache = true`](https://github.com/git-for-windows/git/pull/1344).
* It is [now possible to configure `nano`](https://github.com/git-for-windows/build-extra/pull/161) or [Notepad++](https://github.com/git-for-windows/git/issues/291) as Git's default editor [instead of `vim`](https://www.xkcd.com/378/).
* Comes with [OpenSSL v1.0.2m](https://www.openssl.org/news/cl102.txt).
* Git for Windows' updater [now uses non-intrusive toast notifications on Windows 8, 8.1 and 10](https://github.com/git-for-windows/build-extra/commit/master).
* Running `git fetch` in a repository with lots of refs [is now considerably faster](https://github.com/git-for-windows/git/pull/1379).
* Comes with [cURL v7.57.0](https://curl.haxx.se/changes.html#7_57_0).

### Bug Fixes

* The experimental `--show-ignored-directory` option of `git status` which was removed in Git for Windows v2.15.0 without warning [has been reintroduced as a deprecated option](https://github.com/git-for-windows/git/pull/1354).
* The `git update` command (to auto-update Git for Windows) will [now also work behind proxies](https://github.com/git-for-windows/git/issues/1363).

## Changes since Git for Windows v2.14.3 (October 23rd 2017)

### New Features

* Comes with [Git v2.15.0](https://github.com/git/git/blob/v2.15.0/Documentation/RelNotes/2.15.0.txt).


### Bug Fixes

* The auto-updater tried to run at a precise time, and did not run when the computer was switched off at that time. [Now it runs as soon after the scheduled time as possible](https://github.com/git-for-windows/build-extra/commit/459b6e85c).
* The auto-updater [no longer suggests to downgrade from Release Candidates](https://github.com/git-for-windows/build-extra/commit/1418ee7e8).
* When the auto-updater asked the user whether they want to upgrade to a certain version, and the user declined, [the auto-updater will not bother the user about said version again](https://github.com/git-for-windows/build-extra/commit/c0f7634af).
* The installer, when run with /SKIPIFINUSE=1, [now detects whether *any* executable in Git for Windows' installation is run](https://github.com/git-for-windows/build-extra/commit/db3521c140154b3923e304e4271176958da1f048)
* Git for Windows [no longer includes (non-working) `xmlcatalog.exe` and `xmllint.exe`](https://github.com/git-for-windows/build-extra/commit/c86d164f2c9d5c79cd95f1fda881f9e80ca9dc3a).

## Changes since Git for Windows v2.14.2(3) (October 12th 2017)

### New Features

* Comes with [Git v2.14.3](https://github.com/git/git/blob/v2.14.3/Documentation/RelNotes/2.14.3.txt).
* Git for Windows [now ships with a diff helper for OpenOffice documents](https://github.com/git-for-windows/build-extra/pull/148).
* Comes with [Git LFS v2.3.4](https://github.com/git-lfs/git-lfs/releases/tag/v2.3.4).
* Comes with [cURL v7.56.1](https://curl.haxx.se/changes.html#7_56_1).

### Bug Fixes

* Git for Windows [now handles worktrees at the top-level of a UNC share correctly](https://github.com/git-for-windows/git/issues/1320).

## Changes since Git for Windows v2.14.2(2) (October 5th 2017)

### New Features

* Comes with [Git LFS v2.3.3](https://github.com/git-lfs/git-lfs/releases/tag/v2.3.3).

### Bug Fixes

* [Re-enabled some SSHv1 ciphers](https://github.com/git-for-windows/build-extra/commit/b46fba6f44b3680210b19ef5fc9ce22ca1dcda55) since some sites (e.g. Visual Studio Team Services) rely on them for the time being.

## Changes since Git for Windows v2.14.2 (September 26th 2017)

### New Features

* Comes with [BusyBox v1.28.0pre.16467.b4c390e17](https://github.com/git-for-windows/busybox-w32/commit/b4c390e17).
* Comes with [Git LFS v2.3.2](https://github.com/git-lfs/git-lfs/releases/tag/v2.3.2).
* Comes with [cURL v7.56.0](https://curl.haxx.se/changes.html#7_56_0).
* Comes with [OpenSSH v7.6p1](https://www.openssh.com/txt/release-7.6).
* Comes with [patch level 4](https://github.com/git-for-windows/MSYS2-packages/commit/f2caef90d2e6ba13dc16e38152003958f4db710b) of the MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.9.0](https://cygwin.com/ml/cygwin-announce/2017-09/msg00056.html).

### Bug Fixes

* A [bug](https://github.com/git-for-windows/git/issues/1312) which caused the console window to be closed when executing certain Bash scripts [was fixed](https://github.com/git-for-windows/MSYS2-packages/commit/e9d0a2be2720007c2a734866ebbb4c15e503003c).
* A crash when calling `kill <pid>` for a non-existing process [was fixed](https://github.com/git-for-windows/git/issues/1316).

## Changes since Git for Windows v2.14.1 (August 10th 2017)

### New Features

* Comes with [Git v2.14.2](https://github.com/git/git/blob/v2.14.2/Documentation/RelNotes/2.14.2.txt).
* Comes with [cURL v7.55.1](https://curl.haxx.se/changes.html#7_55_1).
* The XP-compatibility layer emulating pthreads (which is [no longer needed](https://git-for-windows.github.io/requirements.html)) [was dropped in favor of modern Windows threading APIs](https://github.com/git-for-windows/git/pull/1214); This should make threaded operations slightly faster and more robust.
* On Windows, UNC paths can [now be accessed via `file://host/share/repo.git`-style paths](https://github.com/git-for-windows/git/commit/a352941117bc8d00dfddd7a594adf095d084d844).
* Comes with [a new custom Git command `git update`](https://github.com/git-for-windows/build-extra/pull/151) to help keeping Git up-to-date on your machine.
* The Git installer now offers [an option to keep Git up-to-date](https://github.com/git-for-windows/build-extra/pull/155) by calling `git update` regularly.
* Comes with [BusyBox v1.28.0pre.16353.2739df917](https://github.com/git-for-windows/busybox-w32/commit/2739df917).
* As is common elsewhere, Ctrl+Left and Ctrl+Right [now move word-wise in Git Bash](https://github.com/git-for-windows/build-extra/pull/156), too.
* Comes with [patch level 2](https://github.com/git-for-windows/msys2-runtime/commit/874e2c8efeed9084cd065cf9ea5c0951f5afca02) of the MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.9.0](https://cygwin.com/ml/cygwin-announce/2017-09/msg00056.html).
* Comes with [Git LFS v2.3.0](https://github.com/git-lfs/git-lfs/releases/tag/v2.3.0).
* The `vs/master` branch [can now be built in Visual Studio 2017](https://github.com/git-for-windows/git/pull/1302), too
* As [requested](https://github.com/git-for-windows/git/issues/1294) by the same user who implemented [the change](https://github.com/git-for-windows/build-extra/pull/157), Git for Windows now comes with [`tig`](https://github.com/jonas/tig), a text-mode interface for Git.

### Bug Fixes

* It is [now possible to override `http.sslBackend` on the command-line](https://github.com/git-for-windows/git/commit/70c1ff8b0ef66321d630fe49d61ee1a9b6be6a4c).
* The installer [now detects correctly whether symbolic links can be created by regular users](https://github.com/git-for-windows/build-extra/commit/5e438f707027eb99da1b1b381672e6d7dbc063a8).
* Git Bash [now renders non-ASCII directories nicely](https://github.com/git-for-windows/build-extra/pull/152).
* A regression that caused the fetch operation with lots of refs to be a lot slower than before [was fixed](https://github.com/git-for-windows/git/issues/1233).
* The `git-gui.exe` and `gitk.exe` wrappers intended to be used in Git CMD [now handle command-line parameters correctly](https://github.com/git-for-windows/git/issues/1284).
* The `core.longPaths` setting [is now heeded when packing refs](https://github.com/git-for-windows/git/issues/1218), and other previously forgotten Git commands.
* Pressing Ctrl+Z in Git Bash [no longer kills Win32 processes (e.g. `git.exe`) anymore](https://github.com/git-for-windows/git/issues/1083), because POSIX job control is only available with MSYS2 processes.
* Git for Windows [now sets `core.fsyncObjectFiles = true` by default](https://github.com/git-for-windows/git/commit/b5915c6ae881518927b9fa0b3c4df4d3edd37f23) which makes it a lot more fault-tolerant, say, when power is lost.
* A bug has been fixed where Git for Windows [could run into an infinite loop trying to rename a file](https://github.com/git-for-windows/git/issues/1299).
* Before installing Git for Windows, we already verified that no Git Bash instance is active (which would prevent files from being overwritten). We [now also verify that no `git.exe` processes are active, either](https://github.com/git-for-windows/build-extra/commit/1b93b50cf08c6cbd3200a66603d28fbd269c2f6a).

## Changes since Git for Windows v2.14.0(2) (August 7th 2017)

Note: there have been MinGit-only releases v2.12.2(3) and v2.13.1(3) with backports of the important bug fix in v2.14.1 as well as the experimental `--show-ignored-directory` option of `git status`.

### New Features

* Comes with [Git v2.14.1](https://github.com/git/git/blob/v2.14.1/Documentation/RelNotes/2.14.1.txt).
* Comes with [cURL v7.55.0](https://curl.haxx.se/changes.html#7_55_0).
* The *Git Bash Here* context menu item [is now also available](https://github.com/git-for-windows/build-extra/pull/150) in the special [Libraries folders](https://msdn.microsoft.com/en-us/library/windows/desktop/dd758096.aspx).

## Changes since Git for Windows v2.14.0 (August 6th 2017)

### Bug Fixes

* A regression introduced in v2.14.0 that prevented fetching via SSH [was fixed](https://github.com/git-for-windows/git/issues/1258).

## Changes since Git for Windows v2.13.3 (July 13th 2017)

### New Features

* Comes with [Git v2.14.0](https://github.com/git/git/blob/v2.14.0/Documentation/RelNotes/2.14.0.txt).
* Comes with [BusyBox v1.28.0pre.15857.9480dca7c](https://github.com/git-for-windows/busybox-w32/commit/9480dca7c).
* Comes with [Git Credential Manager v1.12.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.12.0).
* It is now possible to switch between Secure Channel and OpenSSL for Git's HTTPS transport by [setting the `http.sslBackend` config variable to "openssl" or "schannel"](https://github.com/git-for-windows/git/commit/d81216ee4dd46ae59a388044d1266d6fa9030c19); This [is now also the method used by the installer](https://github.com/git-for-windows/build-extra/commit/7c5a23970126e3cff1e1a7a763216b2a67005593) (rather than copying `libcurl-4.dll` files around).
* The experimental option [`--show-ignored-directory` was added to `git status`](https://github.com/git-for-windows/git/pull/1243) to show only the name of ignored directories when the option `--untracked=all` is used.
* Git for Windows releases now also include an experimental [BusyBox-based MinGit](https://github.com/git-for-windows/git/wiki/MinGit#experimental-busybox-based-mingit).

### Bug Fixes

* Repository-local aliases [are now resolved again in worktrees](https://github.com/git-for-windows/git/commit/6ba04141d88).
* CamelCased aliases were broken in v2.13.3; This [has been fixed again](https://github.com/git-for-windows/git/commit/af0c2223da0).
* The 32-bit Git binaries are now built against the same dependencies that are shipped with Git for Windows.

## Changes since Git for Windows v2.13.2 (June 26th 2017)

### New Features

* Comes with [Git v2.13.3](https://github.com/git/git/blob/v2.13.3/Documentation/RelNotes/2.13.3.txt).
* Comes with [Git LFS v2.2.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.2.1).
* Comes with MSYS2 runtime (Git for Windows flavor) based on [Cygwin 2.8.2](https://cygwin.com/ml/cygwin-announce/2017-07/msg00044.html).

### Bug Fixes

* Git Bash [no longer tries to use the `getent` tool](https://github.com/git-for-windows/git/issues/1226) which was never shipped with Git for Windows.

## Changes since Git for Windows v2.13.1(2) (June 15th 2017)

### New Features

* Comes with [Git v2.13.2](https://github.com/git/git/blob/v2.13.2/Documentation/RelNotes/2.13.2.txt).
* Comes with [Git Credential Manager v1.10.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.10.1).
* The Git Bash prompt [can now be overridden by creating the file `.config\git\git-prompt.sh`](https://github.com/git-for-windows/build-extra/pull/145).
* Comes with [cURL v7.54.1](https://curl.haxx.se/changes.html#7_54_1).

## Changes since Git for Windows v2.13.1 (June 13th 2017)

### Bug Fixes

* `git commit` and `git status` [no longer randomly throw segmentation faults](https://github.com/git-for-windows/git/issues/1202).

## Changes since Git for Windows v2.13.0 (May 10th 2017)

### New Features

* Comes with [Git v2.13.1](https://github.com/git/git/blob/v2.13.1/Documentation/RelNotes/2.13.1.txt).
* Comes with [Git Credential Manager v1.10.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.10.0).
* Comes with [OpenSSH 7.5p1](https://www.openssh.com/releasenotes.html#7.5p1).
* Comes with [Git Flow v1.11.0](https://github.com/petervanderdoes/gitflow-avh/releases/tag/1.11.0).
* Comes with [Git LFS v2.1.1](https://github.com/git-lfs/git-lfs/releases/tag/v2.1.1).
* Git [now uses the flag introduced with Windows 10 Creators Update to create symbolic links without requiring elevated privileges](https://github.com/git-for-windows/git/pull/1188) in Developer Mode.

### Bug Fixes

* The documentation of Git for Windows' several config files [was improved](https://github.com/git-for-windows/git/pull/1165).
* When interrupting Git processes in Git Bash by pressing Ctrl+C, [Git now removes `.lock` files as designed](https://github.com/git-for-windows/msys2-runtime/pull/15) ([accompanying Git PR](https://github.com/git-for-windows/git/pull/1170); this should also fix [issue #338](https://github.com/git-for-windows/git/issues/338)).
* `git status -uno` [now treats submodules in ignored directories correctly](https://github.com/git-for-windows/git/issues/1179).
* The fscache feature [no longer slows down `git commit -m <message>` in large worktrees](https://github.com/git-for-windows/git/commit/bda7f0728ac55e55d79ed0786c1b5ce2ef7e6117).
* Executing `git.exe` in Git Bash when the current working directory is a UNC path [now works as expected](https://github.com/git-for-windows/git/issues/1181).
* Staging/unstaging multiple files in Git GUI via Ctrl+C [now works](https://github.com/git-for-windows/git/issues/1012).
* When hitting Ctrl+T in Git GUI to stage files, but the file list is empty, Git GUI [no longer shows an exception window](https://github.com/git-for-windows/git/issues/1075).

## Changes since Git for Windows v2.12.2(2) (April 5th 2017)

### New Features

* Comes with [Git v2.13.0](https://github.com/git/git/blob/v2.13.0/Documentation/RelNotes/2.13.0.txt).
* Comes with [cURL v7.54.0](https://curl.haxx.se/changes.html).
* Comes with [Git LFS v2.1.0](https://github.com/git-lfs/git-lfs/releases/tag/v2.1.0).

### Bug Fixes

* As per Git LFS' convention, [it is installed into the `bin/` directory again](https://github.com/git-for-windows/build-extra/pull/141).
* Calling `git add` with an absolute path using different upper/lower case than recorded on disk [will now work as expected](https://github.com/git-for-windows/git/issues/735) instead of claiming that the paths are outside the repository.
* Git for Windows [no longer tries to determine the default printer](https://github.com/git-for-windows/git/issues/1150).
* When writing the Git index file, Git for Windows [no longer has the wrong idea about the file's timestamp](https://github.com/git-for-windows/git/issues/1149).
* On Windows, absolute paths can start with a backslash (implicitly referring to the same drive as the current directory), and now `git clone` [can use those paths, too](https://github.com/git-for-windows/git/commit/fad23e90efc).

## Changes since Git for Windows v2.12.2 (March 27th 2017)

### New Features

* Portable Git is now using [a custom-built SFX that is based directly on 7-Zip's SFX](https://github.com/git-for-windows/7-Zip).
* Git LFS was upgraded to [v2.0.2](https://github.com/git-lfs/git-lfs/releases/tag/v2.0.2).
* Updated the MSYS2 runtime to [Cygwin 2.8.0](https://cygwin.com/ml/cygwin-announce/2017-04/msg00001.html).
* Git LFS [can now be disabled in the first installer page](https://github.com/git-for-windows/build-extra/commit/16975a72fd328130ae531ce349e4a77d9d2b8fa4) (users can still enable it manually, as before, of course).
* Comes with [Git Credential Manager](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/) v1.9.1.

### Bug Fixes

* A potential crash in `git status` with lots of files [was fixed](https://github.com/git-for-windows/git/issues/1111).
* Git LFS [now gets installed into the correct location](https://github.com/git-for-windows/build-extra/commit/5f7d44728c089694f4ef1cc3da03f15e35cd5ecc).
* Git LFS [is now configured correctly out of the box](https://github.com/git-for-windows/build-extra/commit/115b9f5b88ff60af19628262833b42cd7b6cd852) (unless disabled).
* The `http.sslCAInfo` config setting [is now private to the Git for Windows installation that owns the file](https://github.com/git-for-windows/git/issues/531).
* `git difftool -d` [no longer crashes randomly](https://github.com/git-for-windows/git/issues/1124).

## Changes since Git for Windows v2.12.1 (March 21st 2017)

### New Features

* Comes with [Git v2.12.2](https://github.com/git/git/blob/v2.12.2/Documentation/RelNotes/2.12.2.txt).
* An earlier iteration of the changes speeding up the case-insensitive cache of file names was replaced by [a new iteration](https://github.com/git-for-windows/git/commit/212247dd6345c820deeae61fcdf2f10cea10525a).

## Changes since Git for Windows v2.12.0 (February 25th 2017)

A [MinGit-only v2.12.0(2)](https://github.com/git-for-windows/git/releases/tag/v2.12.0.windows.2) was released in the meantime.

### New Features

* Comes with [Git v2.12.1](https://github.com/git/git/blob/v2.12.1/Documentation/RelNotes/2.12.1.txt).
* In addition to the GitForWindows NuGet package, we now also publish [MinGit as a NuGet package](https://www.nuget.org/packages/Git-Windows-Minimal/).
* Git for Windows now bundles [Git LFS](https://git-lfs.github.com/).
* Comes with Git Credential Manager [v1.9.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.9.0).
* Git can now be configured to use [Secure Channel](https://github.com/git-for-windows/git/issues/301) to use the Windows Credential Store when fetching/pushing via HTTPS.
* [Updates](https://github.com/git-for-windows/MSYS2-packages/pull/20) Git-Flow to [v1.10.2](https://github.com/petervanderdoes/gitflow-avh/blob/1.10.2/Changes.mdown#1102) (addressing [#1092](https://github.com/git-for-windows/git/issues/1092)).
* Git for Windows' fork of the MSYS2 runtime was [rebased](https://github.com/git-for-windows/msys2-runtime/compare/5f79e89da8...a55abf375d) to a preview of the Cygwin runtime version 2.8.0 (due soon) to fix [`fork: child <n> - forked process <pid> died unexpectedly, retry 0, exit code 0xC0000142, errno 11` problems](https://cygwin.com/ml/cygwin/2017-03/msg00113.html).

### Bug Fixes

* MinGit [no longer gets distracted](https://github.com/git-for-windows/git/issues/1086) by incompatible `libeay32.dll` versions in C:\Windows\system32.
* Long paths between 248 and 260 characters were not handled correctly since Git for Windows v2.11.1, which [is now fixed](https://github.com/git-for-windows/git/issues/1084).
* The `awk.exe` shipped with MinGit [now ships with a previously missing a dependency](https://github.com/git-for-windows/build-extra/commit/437b52cae9d73772f9582efbd45b63335c7a3fb8) (this fixes `git mergetool`).
* Git for Windows does not ship with localized messages to save on bandwidth, and the gettext initialization [can be skipped when the directory with said messages is missing](https://github.com/git-for-windows/git/commit/0a416e8f3ef5314927f687f8b2e90f68bc537d80), saving us up to 150ms on every `git.exe` startup.
* A possible crash when running `git log --pickaxe-regex -S<regex>` [was fixed](https://github.com/git-for-windows/git/commit/2c6cf4e358dd1395091e1d7f9544028e6df674a7).
* The `ORIGINAL_PATH` variable, recently introduced by the MSYS2 project to allow for special "PATH modes", [is now handled in the same manner as the `PATH` variable](https://github.com/git-for-windows/msys2-runtime/commit/476605ced959f217b3820157b8101b4529fa6a0d) when jumping the Windows<->MSYS2 boundary, fixing issues when `ORIGINAL_PATH` is converted to Windows format and back again.

## Changes since Git for Windows v2.11.1 (February 3rd 2017)

### New Features

* Comes with [Git v2.12.0](https://github.com/git/git/blob/v2.12.0/Documentation/RelNotes/2.12.0.txt).
* The builtin difftool is no longer opt-in, as it graduated to be officially adopted by the Git project.
* Comes with v2.7.0 of the POSIX emulation layer based on the [Cygwin runtime](https://cygwin.com/ml/cygwin-announce/2017-02/msg00022.html).
* Includes [cURL 7.53.1](https://curl.haxx.se/changes.html#7_53_1).
* The Portable Git now defaults to using the included Git Credential Manager.

### Bug Fixes

* The [`stderr` output is unbuffered again](https://github.com/git-for-windows/git/commit/87ad093f001e7146e5e521914255199e49c212a7), i.e. errors are displayed immediately (this was reported [on the Git mailing list](http://public-inbox.org/git/6bc02b0a-a463-1f0c-3fee-ba27dd2482e4@kdbg.org/) as well as issues [#1064](https://github.com/git-for-windows/git/issues/1062), [#1064](https://github.com/git-for-windows/git/issues/1064), [#1068](https://github.com/git-for-windows/git/issues/1068)).
* Git [can clone again](https://github.com/git-for-windows/git/issues/1036) from paths containing non-ASCII characters.
* We [no longer ship two different versions of `curl.exe`](https://github.com/git-for-windows/git/issues/1069).
* Hitting Ctrl+T in Git GUI even after all files have been (un)staged [no longer throws an exception](https://github.com/git-for-windows/git/issues/1060).
* A couple of Git GUI bugs regarding the list of recent repositories [have been fixed](https://github.com/patthoyts/git-gui/pull/10).
* The `git-bash.exe` helper [now waits again for the terminal to be closed before returning](https://github.com/git-for-windows/git/issues/946).
* Git for Windows [no longer attempts to send empty credentials to HTTP(S) servers that handle only Basic and/or Digest authentication](https://github.com/git-for-windows/git/issues/1034).

## Changes since Git for Windows v2.11.0(3) (January 14th 2017)

### New Features

* Comes with [Git v2.11.1](https://github.com/git/git/blob/v2.11.1/Documentation/RelNotes/2.11.1.txt).
* Performance [was enhanced when using fscache in a massively sparse checkout](https://github.com/git-for-windows/git/pull/994).
* Git hooks [can now be `.exe` files](https://github.com/git-for-windows/git/commit/1c6c2420ff6683d93a61fc790842ab712f2a926b).

### Bug Fixes

* Git GUI will [no longer set `GIT_DIR` when calling Git Bash after visualizing the commit history](https://github.com/git-for-windows/git/pull/1032).
* When the `PATH` contains UNC entries, Git Bash will [no longer error out with a "Bad address" error message](https://github.com/git-for-windows/git/issues/1033).

## Changes since Git for Windows v2.11.0(2) (January 13th 2017)

### Bug Fixes

* [Fixed an off-by-two bug in the POSIX emulation layer](https://github.com/git-for-windows/msys2-runtime/commit/cfaf466391f992525a66d91ebb8e33cadbc08438) that possibly affected third-party Perl scripts that load native libraries dynamically.
* A regression in `rebase -i`, introduced into v2.11.0(2), which caused commit attribution to be mishandled after resolving conflicts, [was fixed](https://github.com/git-for-windows/git/commit/e11df2efb3072fe73153442589129d2eb8d9ea02).

## Changes since Git for Windows v2.11.0 (December 1st 2016)

### New Features

* Reading a large index [has been speeded up using pthreads](https://github.com/git-for-windows/git/pull/978).
* The `checkout` operation [was speeded up](https://github.com/git-for-windows/git/pull/988) for the common cases.
* The `status` operation [was made faster](https://github.com/git-for-windows/git/pull/991) in large worktrees with many changes.
* The `diff` operation saw [performance improvements](https://github.com/git-for-windows/git/pull/996) when working on a huge number of renamed files.
* PuTTY's `plink.exe` [can now be used in `GIT_SSH_COMMAND` without jumping through hoops, too](https://github.com/git-for-windows/git/pull/1006).
* The MSYS2 runtime was [synchronized with Cygwin 2.6.1](https://github.com/git-for-windows/msys2-runtime/commit/038b376b2b02ab916eabac006ac54b1d29a4be75).

### Bug Fixes

* Non-ASCII characters are [now shown properly again](https://github.com/git-for-windows/git/issues/981) in Git Bash.
* Implicit NTLM authentication [works again](https://github.com/git-for-windows/git/issues/987) when accessing a remote repository via HTTP/HTTPS without having to specify empty user name and password.
* Our `poll()` emulation [now uses 64-bit tick counts](https://github.com/git-for-windows/git/pull/1003) to avoid the (very rare) wraparound issue where it could miscalculate time differences every 49 days.
* The `--no-lock-index` option of `git status` [is now also respected also in submodules](https://github.com/git-for-windows/git/pull/1004).
* The regression of v2.11.0 where Git could no longer push to shared folders via UNC paths [is fixed](https://github.com/git-for-windows/git/issues/979).
* A bug in the MSYS2 runtime where it performed POSIX->Windows argument conversion incorrectly [was fixed](https://github.com/git-for-windows/msys2-runtime/commit/3cf1b9c3ac4c5490bc94b00cc44682d2637d0b95).
* The MSYS2 runtime [was prepared to access the `FAST_CWD` internal data structure in upcoming Windows versions](https://github.com/git-for-windows/msys2-runtime/commit/5fe6d81012e97a348608511450f6a63750c906b6).
* [Fixed a bug](https://github.com/git-for-windows/git/commit/ecb88230d10382833dc961f83cd1092b8d0a2af2) in the experimental builtin difftool where it would not handle copied/renamed files properly.

## Changes since Git for Windows v2.10.2 (November 2nd 2016)

### New Features

* Comes with [Git v2.11.0](https://github.com/git/git/blob/v2.11.0/Documentation/RelNotes/2.11.0.txt).
* Performance of `git add` in large worktrees [was improved](https://github.com/git-for-windows/git/pull/971).
* A [new, experimental, builtin version of the difftool](https://github.com/git-for-windows/git/commit/5f3656e4b4b8ceeff40bc7fcf03aba3560bff17c) is available as [an opt-in feature](https://github.com/git-for-windows/build-extra/commit/74339bdd9fab9fbf890f079c9024ff4f1309bb6d).
* Support [has been added](https://github.com/git-for-windows/git/commit/056b41311688e9f433fe28e6b3aa6687fa36ca70) to generate project files for Visual Studio 2010 and later.

### Bug Fixes

* The preload-index feature [now behaves much better in conjunction with sparse checkouts](https://github.com/git-for-windows/git/pull/955).
* When encountering a symbolic link, Git [now always tries to read it](https://github.com/git-for-windows/git/issues/958), not only when `core.symlinks = true`.
* The regression where Git would not interpret non-ASCII characters passed from a CMD window correctly [has been fixed](https://github.com/git-for-windows/git/issues/945).
* Performance of the cache of case-insensitive file names [has been improved](https://github.com/git-for-windows/git/pull/964).
* When building with MS Visual C, [release builds are now properly optimized](https://github.com/git-for-windows/git/pull/948).
* `git cvsexportcommit` [now also works with CVSNT](https://github.com/git-for-windows/git/pull/938).
* Git's Perl [no longer gets confused by externally-set `PERL5LIB`](https://github.com/git-for-windows/git/issues/963).
* The uninstaller [no longer leaves an empty `Git\mingw64` folder behind](https://github.com/git-for-windows/git/issues/909).
* The installer [now actually records](https://github.com/git-for-windows/build-extra/commit/6da8414b8c75c76fa526bd75fec22eaefad88e09) whether the user chose to enable or disable the Git Credential Manager.
* A certain scenario that could cause a crash in cherry-pick [no longer causes that](https://github.com/git-for-windows/git/issues/952).

## Changes since Git for Windows v2.10.1(2) (October 13th 2016)

Git for windows v2.10.1(2) was a MinGit-only release (i.e. there was no Git for windows installer for that version).

### New Features

* Comes with [Git v2.10.2](https://github.com/git/git/blob/v2.10.2/Documentation/RelNotes/2.10.2.txt).
* Comes with Git Credential Manager [v1.8.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.8.1).
* Comes with cURL [v7.51.0](https://github.com/curl/curl/releases/tag/curl-7_51_0).
* Git for Windows [can now be built easily with Visual C++ 2015](https://github.com/git-for-windows/git/pull/773).
* The installer [now logs `post-install` errors more verbosely](https://github.com/git-for-windows/build-extra/commit/8332900af09116544f1bee8d20bbfd77daf3186f).
* A new option asks the installer [to skip installation if Git's files are in use](https://github.com/git-for-windows/build-extra/commit/410b4b13505a8a25b199f5cbad0f4afa1a698f34).
* A new option asks the installer [to quietly skip downgrading Git for Windows](https://github.com/git-for-windows/build-extra/commit/c7bc72a157960ee9eef644141f116060c6c31c14), without indicating failure.
* There is [now an explicit option for symbolic link support](https://github.com/git-for-windows/git/issues/921), including a link to a more verbose explanation of the issue.

### Bug Fixes

* when upgrading Git for Windows, SSH agent processes [are now auto-terminated](https://github.com/git-for-windows/git/issues/920).
* When trying to install/upgrade on a Windows version that is no longer supported, [we now refuse to do so](https://github.com/git-for-windows/git/issues/928).

## Changes since Git for Windows v2.10.1 (October 4th 2016)

### New Features

* The speed of the SHA-1 calculation was improved by [using OpenSSL's routines](https://github.com/git-for-windows/git/pull/915) which leverages features of current Intel hardware.
* The `git reset` command [learned the (still experimental) `--stdin` option](https://github.com/git-for-windows/git/commit/6a6c0e84720ab5a374b61341ba9ab645ffafd35f).

## Changes since Git for Windows v2.10.0 (September 3rd 2016)

### New Features

* Comes with [Git v2.10.1](https://github.com/git/git/blob/v2.10.1/Documentation/RelNotes/2.10.1.txt).
* Comes with Git Credential Manager [v1.7.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.7.0).
* Comes with [Git Flow v1.10.0](https://github.com/petervanderdoes/gitflow-avh/releases/tag/1.10.0).
* We [now produce nice diffs for `.docm` and `.dotm` files](https://github.com/git-for-windows/build-extra/pull/128), just as we did for `.docx` files already.

### Bug Fixes

* The icon in the Explorer integration ("Git Bash Here"), which was lost by mistake in v2.10.0, [is back](https://github.com/git-for-windows/git/issues/870).
* [Fixed a crash](https://github.com/git-for-windows/git/commit/c4f481a41de66d24f6f9943104600f2e4f24b152) when calling `git diff -G<regex>` on new-born files without configured user diff drivers.
* Interactive GPG signing of commits and tags [was fixed](https://github.com/git-for-windows/git/issues/871).
* Calling Git with `--date=format:<invalid-format>` [no longer results in an out-of-memory](https://github.com/git-for-windows/git/issues/863) but reports the problem and aborts instead.
* Git Bash [now opens properly even for Azure AD accounts](https://github.com/git-for-windows/git/issues/580).
* Git GUI [respects the `commit.gpgsign` setting again](https://github.com/git-for-windows/git/issues/850).
* Upgrades the bundled OpenSSL to [v1.0.2j](https://www.openssl.org/news/cl102.txt).

## Changes since Git for Windows v2.9.3(2) (August 25th 2016)

### New Features

* Comes with [Git v2.10.0](https://github.com/git/git/blob/v2.10.0/Documentation/RelNotes/2.10.0.txt).
* The `git rebase -i` command was made faster [by reimplementing large parts in C](https://github.com/git-for-windows/git/compare/3259f1f348b8173050c269dde7dc02346db759f3^...3259f1f348b8173050c269dde7dc02346db759f3^2).
* After helping the end-users to use the new defaults for PATH and FSCache, the installer [now respects the saved settings again](https://github.com/git-for-windows/build-extra/compare/a0a8613c54c0bd651904432f07f7b2999790b097~2...a0a8613c54c0bd651904432f07f7b2999790b097).
* `git version --build-options` now [also reports the architecture](https://github.com/git-for-windows/git/pull/866).

### Bug Fixes

* When upgrading Git for Windows, the installer [no longer opens a second window while uninstalling the previous version](https://github.com/git-for-windows/build-extra/commit/6682a86026e801d9c88c1903d5bd4dd1a0d79c4e).
* Git for Windows' SDK [can build an installer out of the box again](https://github.com/git-for-windows/build-extra/commit/955e82b25a825f005946e7e4951e29404370aa94), without requiring an extra package to be installed.

## Changes since Git for Windows v2.9.3 (August 13th 2016)

### New Features

* Comes with Git Credential Manager [v1.6.1](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.6.1).
* The feature introduced with Git for Windows v2.9.3 where `cat-file` can apply smudge filters [was renamed to `--filters` and made compatible with the `--batch` mode (the former option name `--smudge` has been deprecated and will go away in v2.10.0)](https://github.com/git-for-windows/git/compare/f080fe716^...f080fe716).
* Comes with OpenSSH [7.3p1](https://github.com/git-for-windows/MSYS2-packages/compare/da63f58~3...da63f58).
* Git's .exe files are now [code-signed](https://github.com/git-for-windows/build-extra/commit/3e9b83526), helping with performance when being run with [Windows File Protection](https://en.wikipedia.org/wiki/Windows_File_Protection).

## Changes since Git for Windows v2.9.2 (July 16th 2016)

### New Features

* Comes with [Git 2.9.3](https://github.com/git/git/blob/v2.9.3/Documentation/RelNotes/2.9.3.txt).
* Updated Git Credential Manager to [version 1.6.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v.1.6.0).
* Includes support for `git status --porcelain=v2`.
* Avoids evaluating unnecessary patch IDs when determining which commits do not need to be rebased because they are already upstream.
* Sports a new `--smudge` option for `git cat-file` that lets it pass blob contents through smudge filters configured for the specified path.

### Bug Fixes

* When offering to `Launch Git Bash` after the installation, [it now launches in the home directory](https://github.com/git-for-windows/build-extra/commit/aa0b462), consistent with the `Git Bash` Start Menu entry.
* When `~/.gitconfig` sets `core.hideDotFiles=false`, `git init` [respects that again](https://github.com/git-for-windows/git/issues/789).


## Changes since Git for Windows v2.9.0 (June 14th 2016)

### New Features

* Comes with [Git 2.9.2](https://github.com/git/git/blob/v2.9.2/Documentation/RelNotes/2.9.2.txt) (skipping the Windows release of [Git 2.9.1](https://github.com/git/git/blob/v2.9.1/Documentation/RelNotes/2.9.1.txt) due to a regression caught by the automated tests).
* Git Credential Manager was updated to [v1.5.0](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.5.0).
* The installer [will now refuse to downgrade Git for Windows, unless the user assures that it is intended](https://github.com/git-for-windows/build-extra/commit/82dc6284).
* MinGit, the portable, non-interactive Git intended for third-party tools, [is now also built as part of Git for Windows' official versions](https://github.com/git-for-windows/build-extra/commit/16a8cf5).

### Bug Fixes

* When `git bundle create` is asked to create an empty bundle, it is supposed to error out and delete the corrupt bundle file. The deletion [no longer fails due to an unreleased lock file](https://github.com/git-for-windows/git/pull/797).
* When launching `git help <command>`, the `help.browser` config setting [is now respected](https://github.com/git-for-windows/git/pull/793).
* The title bar in Git for Windows' SDK [shows the correct prefix again](https://github.com/git-for-windows/build-extra/pull/122).
* We [no longer throw an assertion](https://github.com/git-for-windows/git/commit/ac008b30ec070f459450d602c55d55816aae2915) when using the `git credential-store`.
* When configuring `notepad` as commit message editor, [UTF-8 messages are now handled correctly](https://github.com/git-for-windows/build-extra/pull/123).

## Changes since Git for Windows v2.8.4 (June 7th 2016)

### New Features

* Comes with [Git 2.9.0](https://github.com/git/git/blob/v2.9.0/Documentation/RelNotes/2.9.0.txt).

### Bug Fixes

* When running `git gc --aggressive` or `git repack -ald` in the presence of multiple pack files, the command still had open handles to the pack files it wanted to remove. This [has been fixed](https://github.com/git-for-windows/git/commit/85bc5ad9a69fa120b23471d483dc8da35d771ab7).

## Changes since Git for Windows v2.8.3 (May 20th 2016)

### New Features

* Comes with [Git 2.8.4](https://github.com/git/git/blob/v2.8.4/Documentation/RelNotes/2.8.4.txt).

### Bug Fixes

* Child processes [no longer inherit handles to temporary files](https://github.com/git-for-windows/git/pull/755), which previously could prevent `index.lock` from being deleted.
* When configuring Git Bash with Windows' default console, it [no longer loses its icon](https://github.com/git-for-windows/build-extra/pull/118).

## Changes since Git for Windows v2.8.2 (May 3rd 2016)

### New Features

* Comes with [Git v2.8.3](https://github.com/git/git/blob/v2.8.3/Documentation/RelNotes/2.8.3.txt).

## Changes since Git for Windows v2.8.1 (April 4th 2016)

### New Features

* Comes with [Git v2.8.2](https://github.com/git/git/raw/v2.8.2/Documentation/RelNotes/2.8.2.txt).
* Starting with version 2.8.2, [Git for Windows is also published as a NuGet package](https://www.nuget.org/packages/GitForWindows/).
* Comes with Git Credential Manager v1.3.0.

### Bug Fixes

* FSCache [is now enabled by default](https://github.com/git-for-windows/build-extra/commit/a1ae146) even when upgrading from previous Git for Windows versions.
* We now add `git.exe` to the `PATH` [by default](https://github.com/git-for-windows/build-extra/commit/1e2e00e) even when upgrading from previous Git for Windows versions.
* Git GUI [now sets author information correctly when amending](https://github.com/git-for-windows/git/pull/726).
* OpenSSL received a critical update to [version 1.0.2h](https://www.openssl.org/news/newslog.html).

## Changes since Git for Windows v2.8.0 (March 29th 2016)

### New Features

* Comes with [Git v2.8.1](http://article.gmane.org/gmane.linux.kernel/2189878).
* The Git for Windows project updated its contributor guidelines to the [Contributor Covenant 1.4](https://github.com/git-for-windows/git/pull/661).

### Bug Fixes

* Git's default editor (`vim`) is [no longer freezing](https://github.com/git-for-windows/msys2-runtime/commit/1ca92fa2ef89bf9d61d3911a499d8187db18427a) in CMD windows.
* GIT_SSH (and other executable paths that Git wants to spawn) [can now contain spaces](https://github.com/git-for-windows/git/issues/692).

## Changes since Git for Windows v2.7.4 (March 18th 2016)

### New Features

* Comes with [Git v2.8.0](http://article.gmane.org/gmane.linux.kernel/2185094).
* Comes with the [Git Credential Manager v1.2.2](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/releases/tag/v1.2.2).
* The FSCache feature (which was labeled experimental for quite some time) [is now enabled by default](https://github.com/git-for-windows/build-extra/pull/101).
* Git is now [added to the `PATH` by default](https://github.com/git-for-windows/build-extra/pull/102) (previously, the default was for Git to be available only from Git Bash/CMD).
* The installer [now offers to launch the Git Bash right away](https://github.com/git-for-windows/build-extra/pull/103).

### Bug Fixes

* The previous workaround for the blurred link to the Git Credential Manager [was fixed](https://github.com/git-for-windows/build-extra/commit/58d978cb84096bcc887170cbfcf44af022848ae3) so that the link is neither blurry nor overlapping.
* The installer [now changes the label of the `Next` button to `Install`](https://github.com/git-for-windows/build-extra/pull/104) on the last wizard page before installing.

## Changes since Git for Windows v2.7.3 (March 15th 2016)

### New Features

* Comes with [Git 2.7.4](http://article.gmane.org/gmane.linux.kernel/2179363).

### Bug Fixes

* The Git Credential Manager hyperlink in the installer [is no longer blurred](https://github.com/git-for-windows/build-extra/commit/28bb2a330323ba1c69f278cafa81e3e4fd3bf71c).

## Changes since Git for Windows v2.7.2 (February 23rd 2016)

### New Features

* Git for Windows [now ships with](https://github.com/git-for-windows/git/issues/466) the [Git Credential Manager for Windows](https://github.com/Microsoft/Git-Credential-Manager-for-Windows/).
* Comes with [Git v2.7.3](http://article.gmane.org/gmane.linux.kernel/2174435).

### Bug Fixes

* We [now handle UTF-8 merge and squash messages correctly in Git GUI](https://github.com/git-for-windows/git/issues/665).
* When trying to modify a repository config outside of any Git worktree, [`git config` no longer creates a `.git/` directory](https://github.com/git-for-windows/git/commit/64acc338c) but prints an appropriate error message instead.
* A new version of Git for Windows' SDK [was released](https://github.com/git-for-windows/build-extra/releases/git-sdk-1.0.3] that [works around pacman-key issues](https://github.com/git-for-windows/git/issues/670).
* We [no longer show asterisks when reading the username for credentials](https://github.com/git-for-windows/git/pull/677).

## Changes since Git for Windows v2.7.1(2) (February 12th 2016)

### New Features

* Git for Windows' SDK version 1.0.2 [has been released](https://github.com/git-for-windows/build-extra/releases/tag/git-sdk-1.0.2).
* The "list references" window of `gitk` [is now wider by default](https://github.com/git-for-windows/git/pull/620).
* Comes with [Git 2.7.2](http://article.gmane.org/gmane.linux.kernel/2158401).

### Bug Fixes

* The user is [now presented with a nice error message](https://github.com/git-for-windows/git/issues/527) when calling `node` while `node.exe` is not in the `PATH` (this bug also affected other interactive console programs such as `python` and `php`).
* The arrow keys [are respected again in gitk](https://github.com/git-for-windows/git/issues/495).
* When a too-long path is encountered, `git clean -dfx` [no longer aborts quietly](https://github.com/git-for-windows/git/issues/521).
* Git GUI learned to [stage lines appended to a single-line file](https://github.com/git-for-windows/git/issues/515).
* When launching `C:\Program Files\Git\bin\bash -l -i` in a cmd window and pressing Ctrl+C, [the console is no longer corrupted](https://github.com/git-for-windows/git/pull/205) (previously, the `bash.exe` redirector would terminate and both cmd & Bash would compete for user input).

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
* The environment variable `HOME` can now be used to set the home directory [even when running with accounts that are part of a different domain than the current (non-domain-joined) machine](https://github.com/git-for-windows/msys2-runtime/commit/9660c5ffe82b921dd2193efa18e9721f47a6b22f) (in which case the MSYS2 runtime has no way to emulate POSIX-style UIDs).
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
* Also available as `.tar.bz2` packages (you need an MSYS2/Cygwin-compatible unpacker to recreate the symbolic links correctly).

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

* The MSYS2 runtime was taught [not to look hard for groups](https://github.com/git-for-windows/git/issues/193), speeding up *Git Bash*'s startup time.
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
* In 32-bit setups, all the MSYS2 `.dll`'s address ranges are adjusted ("auto-rebased") as part of the installation process
* The post-install scripts of MSYS2 are now executed as part of the installation process, too
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
* First release based on [MSYS2](https://msys2.github.io/).
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
