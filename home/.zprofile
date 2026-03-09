# ------------------------------------------------------------
# homebrew
# ------------------------------------------------------------

# Initialise Homebrew if present.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ------------------------------------------------------------
# user paths
# ------------------------------------------------------------

# Local user binaries
export PATH="$HOME/.local/bin:$PATH"

# Rust cargo binaries
export PATH="$HOME/.cargo/bin:$PATH"

# ------------------------------------------------------------
# local machine-specific overrides
# ------------------------------------------------------------

# Load optional local settings that should not be committed
# to the dotfiles repository.
[[ -f "$HOME/.zprofile.local" ]] && source "$HOME/.zprofile.local"
