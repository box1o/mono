[[ $- != *i* ]] && return

# prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  PS1='[\u@\h \W]\$ '
fi

# completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  source /etc/bash_completion
fi

# keys
set -o vi
bind '"\C-k": history-search-backward'
bind '"\C-j": history-search-forward'
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOA": history-search-backward'
bind '"\eOB": history-search-forward'
bind '"\C-p": history-search-backward'
bind '"\C-n": history-search-forward'

# history
HISTSIZE=5000
HISTFILESIZE=5000
HISTFILE="$HOME/.bash_history"
HISTCONTROL=ignorespace:erasedups
HISTIGNORE='ls:bg:fg:history:clear'

shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# completion style
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b 2>/dev/null)"
fi

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set menu-complete-display-prefix on'

# shell tools
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd bash)"
fi

[[ -f "$HOME/.shellrc" ]] && source "$HOME/.shellrc"

# bash aliases
alias g='nvim ~/.bashrc'
alias s='source ~/.bashrc'
