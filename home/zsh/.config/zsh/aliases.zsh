# aliases; \name runs the real command when an alias hides one (\cc is the c compiler)

# git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease --force-if-includes'
alias gpl='git pull'
alias gf='git fetch'
alias gsw='git switch'
alias gcb='git switch -c'
alias gco='git checkout'
alias gb='git branch'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -20'
alias gd='git diff'
alias gds='git diff --staged'
alias gundo='git reset HEAD~1 --mixed'
alias lg='lazygit'

# files
alias l='eza -l --git'
alias ll='eza -la --git'
alias la='eza -a'
alias lt='eza -T -L 2'

# editors
alias vi='nvim'
alias vim='nvim'
alias cc='claude'

# tmux, and sesh for its sessions
alias t='tmux'
alias ta='tmux attach'
alias th='sesh connect "$PWD"'
alias tp='sesh picker -i'
alias tk='tmux kill-session -t'

# rust, go and zig
alias cr='cargo run'
alias cb='cargo build'
alias ct='cargo test'
alias cl='cargo clippy'
alias gor='go run .'
alias gob='go build .'
alias got='go test ./...'
alias zb='zig build'
alias zr='zig build run'
alias zt='zig build test'

# npm and uv
alias ni='npm install'
alias nr='npm run'
alias nrd='npm run dev'
alias nrb='npm run build'
alias nrt='npm run test'
alias nes='npx expo start'
alias py='python3'
alias venv='uv venv'
alias uvr='uv run'
alias uva='uv add'
alias uvs='uv sync'

# system
alias update='dot update'
alias reload='exec zsh'
alias please='sudo zsh -c "$(fc -ln -1)"'
alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
alias myip='ip -brief address'
alias pubip='curl -s https://ipecho.net/plain; echo'
alias path='print -rl -- $path'
alias c='clear'
