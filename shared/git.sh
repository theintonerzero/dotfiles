# shared/git.sh: your git identity, an ssh key on github for login and signing, github's host keys, gh
# on ssh and git's https through gh, and git lfs
# shellcheck shell=bash

git_install() {
  local key=$HOME/.ssh/id_ed25519
  # with ~/.gitconfig there, git config --global writes to it, never through the linked config
  [[ -e $HOME/.gitconfig ]] || touch "$HOME/.gitconfig"
  git_identity
  if [[ ! -e $key ]]; then
    say "making an ssh key"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -q -t ed25519 -N '' -C "$USER@$(hostname)" -f "$key"
  fi
  git_signers
  if git_github_keys; then git_gh_ssh; fi
  git_known_hosts
  git_gh_https
  if [[ -z $(git config --global filter.lfs.process) ]]; then git lfs install --skip-repo >/dev/null; fi
}

# git_identity: your name and email in ~/.config/git/local, which the linked config includes
git_identity() {
  local file=$HOME/.config/git/local want
  [[ -n ${GIT_NAME:-} && -n ${GIT_EMAIL:-} ]] || return 0
  want=$(printf '[user]\n\tname = %s\n\temail = %s' "$GIT_NAME" "$GIT_EMAIL")
  [[ -f $file && $(<"$file") == "$want" ]] && return 0
  say "saving your git name and email"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$want" >"$file"
}

# git_signers: the key git checks your signatures against, under your email; other machines' keys stay
git_signers() {
  local file=$HOME/.config/git/allowed_signers email type key line
  [[ -r $HOME/.ssh/id_ed25519.pub ]] || return 0
  email=$(git config --get user.email) || return 0
  read -r type key _ <"$HOME/.ssh/id_ed25519.pub"
  line="$email $type $key"
  if [[ -f $file ]] && grep -qxF "$line" "$file"; then return 0; fi
  {
    if [[ -f $file ]]; then grep -vF " $key" "$file" || true; fi
    echo "$line"
  } >"$file.new"
  mv -f "$file.new" "$file"
}

# git_github_keys: this computer's key on github, for login and for signing; fails, leaving a todo, when
# gh can't put it there
git_github_keys() {
  local pub=$HOME/.ssh/id_ed25519.pub key list kind
  if ! have gh || ! gh auth status >/dev/null 2>&1; then
    todo "sign gh in to GitHub (gh auth login), then run dot install again, so your SSH key goes on GitHub"
    return 1
  fi
  read -r _ key _ <"$pub"
  if ! list=$(gh ssh-key list); then
    warn "couldn't list your github keys"
    return 1
  fi
  for kind in authentication signing; do
    # gh ssh-key list: title, key, added, id, type
    if ! awk -F'\t' -v k="$key" -v t="$kind" '{ split($2, a, " ") } a[2] == k && $5 == t { found = 1 } END { exit !found }' <<<"$list"; then
      say "adding this computer's ssh key to github for $kind"
      if ! gh ssh-key add "$pub" --type "$kind" --title "$(hostname)"; then
        todo "let gh add SSH keys (gh auth refresh -s admin:public_key,admin:ssh_signing_key), then run dot install again"
        return 1
      fi
    fi
  done
}

# git_gh_ssh: gh clones over ssh, now that the key is on github
git_gh_ssh() {
  [[ $(gh config get -h github.com git_protocol) == ssh ]] || gh config set -h github.com git_protocol ssh
}

# git_gh_https: git signs in to github's https remotes, like a clone made before the key, through gh
git_gh_https() {
  have gh && gh auth status >/dev/null 2>&1 || return 0
  [[ $(git config --global --get-all credential.https://github.com.helper) == *"gh auth git-credential"* ]] ||
    gh auth setup-git --hostname github.com
}

# git_known_hosts: github's host keys, from github's api, so the first ssh connection doesn't stop to ask
git_known_hosts() {
  local known=$HOME/.ssh/known_hosts keys hostkey
  have gh && gh auth status >/dev/null 2>&1 || return 0
  keys=$(gh api meta --jq '.ssh_keys[]') || return 0
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$known"
  while read -r hostkey; do
    [[ -n $hostkey ]] || continue
    grep -qF "$hostkey" "$known" || echo "github.com $hostkey" >>"$known"
  done <<<"$keys"
}
