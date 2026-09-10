#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '


# Run script only when inside a kitty terminal
if [[ "$TERM" == "xterm-kitty" ]]; then
    /home/nosil/.config/kitty/launch.sh
fi
