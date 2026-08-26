# prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

autoload -Uz compinit
compinit
zinit cdreplay -q

# keys
bindkey -v
bindkey '^k' history-search-backward
bindkey '^j' history-search-forward

# history
HISTSIZE=5000
SAVEHIST=5000
HISTFILE="$HOME/.zsh_history"

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups

# completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=auto $realpath'

# shell tools
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
fi

[[ -f "$HOME/.shellrc" ]] && source "$HOME/.shellrc"

# zsh aliases
alias g='nvim ~/.zshrc'
alias s='source ~/.zshrc'

# Start a dedicated tmux workspace with a short, friendly name.
if [[ $- == *i* && -z "${TMUX:-}" && -t 0 && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -s "$(tmux_friendly_session_name)"
fi
