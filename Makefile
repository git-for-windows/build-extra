CFLAGS=-O2 -Wall

all: edit-git-bash.exe proxy-lookup.exe

edit-git-bash.exe: edit-git-bash.c
	gcc -DSTANDALONE_EXE $(CFLAGS) -o $@ $^

proxy-lookup.exe: proxy-lookup.c
	gcc $(CFLAGS) -Werror -o $@ $^ -lshell32 -lwinhttp
