# add ~/.bash_profile if needed for executing ~/.bashrc
if [ -e ~/.bashrc -a ! -e ~/.bash_profile -a ! -e ~/.bash_login -a ! -e ~/.profile ]; then
  printf "\n\033[31mWARNING: Found ~/.bashrc but no ~/.bash_profile, ~/.bash_login or ~/.profile.\033[m\n\n"
  echo "This looks like an incorrect setup."
  echo "A ~/.bash_profile containing \"if [ -f ~/.bashrc ]; then . ~/.bashrc; fi\" will be created for you."
  echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" > ~/.bash_profile
fi
