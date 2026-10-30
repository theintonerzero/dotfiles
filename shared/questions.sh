# shared/questions.sh: what install asks, all first, so the rest runs on its own, and the computer's name
# shellcheck shell=bash

# ask_questions: the computer's name, then one sign-in to github, over https, which gives the rest;
# git's name and email come from ~/.config/git/local, or else your github profile; with no terminal,
# each takes its default
# shellcheck disable=SC2034 # the git step reads them
ask_questions() {
  local local_git=$HOME/.config/git/local status profile name email id login
  ask NEW_HOSTNAME "Computer name" "$(current_hostname)"

  if have gh && tty_ok; then
    status=$(gh auth status --hostname github.com 2>&1) || status=""
    if [[ -z $status ]]; then
      say "signing gh in to github"
      gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key \
        --scopes admin:public_key,admin:ssh_signing_key </dev/tty || warn "gh isn't signed in"
    elif [[ $status != *admin:public_key* || $status != *admin:ssh_signing_key* ]]; then
      say "letting gh add your ssh key to github"
      gh auth refresh --hostname github.com -s admin:public_key,admin:ssh_signing_key </dev/tty ||
        warn "gh can't add ssh keys"
    fi
  fi

  GIT_NAME=$(git config --file "$local_git" user.name 2>/dev/null) || GIT_NAME=""
  GIT_EMAIL=$(git config --file "$local_git" user.email 2>/dev/null) || GIT_EMAIL=""
  if [[ -z $GIT_NAME || -z $GIT_EMAIL ]] && have gh &&
    profile=$(gh api user --jq '[(.name // ""), (.email // ""), (.id | tostring), .login] | join("\u001f")' 2>/dev/null); then
    IFS=$'\x1f' read -r name email id login <<<"$profile"
    # a private email: github's no-reply address, which github counts as yours
    if [[ -z $email && -n $login ]]; then email=$id+$login@users.noreply.github.com; fi
    GIT_NAME=${GIT_NAME:-$name} GIT_EMAIL=${GIT_EMAIL:-$email}
    if [[ -n $GIT_NAME && -n $GIT_EMAIL ]]; then
      say "git signs your commits as $GIT_NAME <$GIT_EMAIL>, from your github profile"
    fi
  fi
  [[ -n $GIT_NAME ]] || ask GIT_NAME "Your full name for git commits (first and last, e.g. Jane Smith)" "$(git config --get user.name)"
  [[ -n $GIT_EMAIL ]] || ask GIT_EMAIL "Your email for git commits (one verified on your GitHub account)" "$(git config --get user.email)"
  if [[ -z $GIT_NAME || -z $GIT_EMAIL ]]; then
    todo "git needs your name and email: run dot install again on a terminal"
  fi
}

# current_hostname: the static name, or the one the computer has now when none is set (a fresh fedora)
current_hostname() {
  local name
  name=$(hostnamectl --static 2>/dev/null) || name=""
  printf '%s\n' "${name:-$(uname -n)}"
}

# set_hostname: names the computer NEW_HOSTNAME, when that's a change
set_hostname() {
  [[ -n ${NEW_HOSTNAME:-} && $NEW_HOSTNAME != "$(current_hostname)" ]] || return 0
  say "naming this computer $NEW_HOSTNAME"
  as_root hostnamectl set-hostname "$NEW_HOSTNAME" || warn "couldn't name this computer $NEW_HOSTNAME"
}
