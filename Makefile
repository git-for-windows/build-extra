CFLAGS=-O2 -Wall

all: edit-git-bash.exe

edit-git-bash.exe: edit-git-bash.c
	gcc -DSTANDALONE_EXE $(CFLAGS) -o $@ $^
