CFLAGS=-O2 -Wall
DLLINKFLAGS=-Wl,--kill-at -static-libgcc -shared

all: edit-git-bash.dll

# InnoSetup always uses the DLL target, and it must always be 32-bit
# because InnoSetup is only 32-bit aware.
edit-git-bash.dll: edit-git-bash.c
	PATH=/mingw32/bin:$$PATH \
	i686-w64-mingw32-gcc -march=i686 $(CFLAGS) $(DLLINKFLAGS) -o $@ $^

edit-git-bash.exe: edit-git-bash.c
	gcc -DSTANDALONE_EXE $(CFLAGS) -o $@ $^