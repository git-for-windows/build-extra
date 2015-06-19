edit-git-bash.exe: installer/edit-git-bash.c
	gcc -Wall -mconsole -o $@ -DWITH_MAIN_FUNCTION $^

bash-dropin.exe: /git-cmd.exe edit-git-bash.exe
	cp $< $@ &&
	./edit-git-bash.exe $@ '"@@EXEPATH@@\..\usr\bin\bash.exe" --login -i'
