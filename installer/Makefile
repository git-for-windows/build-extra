CFLAGS=-O2 -Wall
DLLINKFLAGS=-Wl,--kill-at -static-libgcc -shared

all: edit-git-bash.dll

edit-git-bash.dll: edit-git-bash.c
	gcc $(CFLAGS) $(DLLINKFLAGS) -o $@ $^
