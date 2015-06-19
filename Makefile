edit-git-bash.exe: installer/edit-git-bash.c
	gcc -Wall -mconsole -o $@ -DWITH_MAIN_FUNCTION $^
