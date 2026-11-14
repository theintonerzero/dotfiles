# every zsh reads this first, scripts too: the xdg folders, zsh's own folder, PATH and the editor

# a shell started in a folder that's since been deleted begins at home
[[ $PWD = /* ]] || cd "$HOME"

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
export ZDOTDIR=$XDG_CONFIG_HOME/zsh

# on macos, homebrew: its programs, which come after yours, mise's and cargo's, no analytics or tips, and
# .net 10, which homebrew keeps in a folder of its own, off the path
typeset -U path
if [[ -d /opt/homebrew ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
  path=(/opt/homebrew/bin /opt/homebrew/sbin /opt/homebrew/opt/dotnet@10/bin(N/) $path)
  if [[ -d /opt/homebrew/opt/dotnet@10/libexec ]]; then export DOTNET_ROOT=/opt/homebrew/opt/dotnet@10/libexec; fi
fi

# your scripts, mise's tools and cargo's first; mason's language servers, for claude code's plugins, and
# lm studio's lms last
path=(~/.local/bin $XDG_DATA_HOME/mise/shims ~/.cargo/bin $path $XDG_DATA_HOME/nvim/mason/bin ~/.lmstudio/bin)

export EDITOR=nvim VISUAL=nvim PAGER=less LESS='-R -F -i -M'
export EZA_ICONS_AUTO=1
export FZF_DEFAULT_OPTS_FILE=$XDG_CONFIG_HOME/fzf/fzfrc
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND

# the unity cli: no usage pings, crash reports, plugin tips or update check, as dot update updates it
# (environment.d does the same for apps on fedora, and a launch agent on macos)
export UNITY_NO_CLI_INVOKED_TELEMETRY=1 UNITY_NO_CRASH_REPORT=1 UNITY_NO_AGENT_HINTS=1 UNITY_NO_UPDATE_CHECK=1
