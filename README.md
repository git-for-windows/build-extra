# Build environment for Git for Windows

This is Git for Windows SDK, the build environment for [Git for Windows](http://git-for-windows.github.io/).

The easiest way to install Git for Windows SDK is via the [Git SDK installer](https://github.com/git-for-windows/build-extra/releases/latest). This installer will clone our [repositories](http://github.com/git-for-windows/), including all the necessary components to build Git for Windows, and perform an initial build. It will also install a shortcut to the Git SDK Bash on the desktop.

To check out the `build-extra` project in the Git SDK, issue the following commands in the Git SDK Bash:

```sh
cd /usr/src/build-extra
git fetch
git checkout master
```

# Components of the Git for Windows SDK

The build environment brings all the necessary parts required to build a Git for Windows installer, or a portable Git for Windows ("portable" == "USB drive edition", i.e. you can run it without installing, from wherever it was unpacked).

## Git for Windows

The most important part of Git for Windows is [Git](https://git-scm.com/), obviously. The Git for Windows project maintains [a friendly fork](https://github.com/git-for-windows/git) of the "upstream" [Git project](https://github.com/git/git). The idea is that the Git for Windows repository serves as a test bed to develop patches and patch series that are specific to the Windows port, and once the patches stabilized, they are [submitted upstream](https://github.com/git-for-windows/git/tree/master/Documentation/SubmittingPatches).

## MSYS2

Git is not a monolithic executable, but consists of a couple of executables written in C, a couple of Bash scripts, a couple of Perl scripts, and a couple of Tcl/Tk scripts. Some parts (not supported by Git for Windows yet) are written in other script languages, still.

To support those scripts, Git for Windows uses [MSYS2](https://msys2.github.io/), a project providing a minimal POSIX emulation layer (based on [Cygwin](https://cygwin.com)), a package management system (named "Pacman", borrowed from Arch Linux) and a number of packages that are kept up-to-date by an active team of maintainers, including Bash, Perl, Subversion, etc.

### The difference between MSYS2 and MinGW

MSYS2 refers to the libraries and programs that use the POSIX emulation layer ("msys2 runtime", derived from Cygwin's `cygwin1.dll`). It is very easy to port libraries and programs from Unix/Linux because most of the POSIX semantics is emulated reasonably well, for example [the `fork()` function](http://pubs.opengroup.org/onlinepubs/000095399/functions/fork.html). Bash and Perl are examples of MSYS2 programs.

MinGW refers to libraries and programs that are compiled using GNU tools but do not require any POSIX semantics, instead relying on the standard Win32 API and the C runtime library. MinGW stands for "Minimal GNU for Windows". Examples: cURL (a library to talk to remote servers via HTTP(S), (S)FTP, etc), emacs, Inkscape, etc

The POSIX emulation layer of MSYS2 binaries is convenient, but comes at a cost: Typically, MSYS2 programs are noticably slower than their MinGW counterparts (if there are such counterparts). As a consequence, the Git for Windows project tries to provide as many components as possible as MinGW binaries.

### MinGW packages

The MinGW packages are built from the `MINGW-packages` repository which can be initialized in the Git SDK Bash via

```sh
cd /usr/src/MINGW-packages
git fetch
git checkout master
```

The packages inside the `/usr/src/MINGW-packages/` directory can then be built by executing `makepkg-mingw -s` in the appropriate subdirectory.

MinGW packages can be built for both `i686` and `x86_64` architectures at the same time by making sure that both toolchains are installed (`pacman -Sy mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain`) before running `makepkg-mingw`.

### MSYS2 packages

The MSYS2 packages are built from the `MSYS2-packages` repository which can be initialized in the Git SDK Bash via

```sh
cd /usr/src/MSYS2-packages
git fetch
git checkout master
```

To build the packages inside the `/usr/src/MSYS2-packages/` directory, the user has to launch a special shell by double-clicking the `msys2_shell.bat` script in the top-level directory of the Git SDK, switch the working directory to the appropriate subdirectory of `/usr/src/MSYS2-packages/` and then execute `makepkg -s`. Before the first MSYS2 package is built, the prerequisite development packages have to be installed by executing `pacman -Sy base-devel binutils`.

## Installer generators

The Git for Windows project aims to provide three different types of installers:

- _Git for Windows_ for end users. The subdirectory `installer/` contains the files to generate this installer.
- _Portable Git for Windows_ for end users ("USB drive edition"). This installer is actually a self-extracting `.7z` archive, and can be generated using the files in `portable/`.
- The _Git for Windows SDK_ for Git for Windows contributors. This is a complete development environment to build Git for Windows, including Git, Bash, cURL, etc (including these three installers, of course). The files to generate this installer live in `sdk-installer/`.

## Support scripts/files

The `build-extra` repository is also the home of other resources necessary to develop and maintain Git for Windows. For example, it contains the [Git garden shears](https://github.com/git-for-windows/build-extra/blob/master/shears.sh) that help with updating Git for Windows' source code whenever new upstream Git versions are released ("merging rebase").
