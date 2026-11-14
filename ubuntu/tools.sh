# ubuntu/tools.sh: the tools ubuntu's packages lack or have too old: each from apt when apt's version is
# new enough, else from the project's own release
# shellcheck shell=bash

TOOLS=${TOOLS:-$DOTFILES/ubuntu/tools.txt}

tools_install() {
  local cmd pkg min repo arm amd arch re
  arch=$(tool_arch)
  while read -r cmd pkg min repo arm amd; do
    if [[ $pkg != - ]] && version_ge "$(apt_candidate "$pkg")" "$min"; then
      tool_apt "$cmd" "$pkg" || todo "$cmd didn't install; dot install tries again"
      continue
    fi
    case $arch in
      arm64) re=$arm ;;
      amd64) re=$amd ;;
      *)
        warn "$cmd has no build for this machine ($(uname -m)), and ubuntu's package is missing or too old"
        continue
        ;;
    esac
    tool_release "$cmd" "$repo" "$re" || tool_failed "$cmd"
  done < <(list "$TOOLS")
}

# tool_failed <cmd>: what's left for you when a release didn't go in: nothing to worry about where an
# older copy still runs
tool_failed() {
  if [[ -x $HOME/.local/bin/$1 ]]; then
    todo "$1 couldn't be updated, so the one you have stays; dot update tries again"
  else
    todo "$1 didn't install; dot install tries again"
  fi
}

# dot update does the same: apt's are upgraded with the rest, and a release whose newest tag has changed
# is fetched again
tools_update() { tools_install; }

# tool_arch: this machine as the releases name it: arm64 or amd64, or nothing for any other
tool_arch() {
  case $(uname -m) in
    aarch64 | arm64) echo arm64 ;;
    x86_64 | amd64) echo amd64 ;;
  esac
}

# version_ge <have> <want>: whether a debian version is at least an upstream one; its epoch, its +ds or
# ~rc suffix and its -revision are set aside. nothing isn't at least anything
version_ge() {
  local have=$1
  [[ -n $have ]] || return 1
  if [[ $have =~ ^[0-9]+: ]]; then have=${have#*:}; fi
  have=${have%-*}
  have=${have%%[+~]*}
  [[ $(printf '%s\n%s\n' "$2" "$have" | sort -V | head -n 1) == "$2" ]]
}

# apt_candidate <pkg>: the version apt would install, or nothing when it has no such package
apt_candidate() {
  local v
  v=$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && !seen { print $2; seen = 1 }') || v=""
  if [[ $v != "(none)" ]]; then echo "$v"; fi
}

# tool_apt <cmd> <pkg>: ubuntu's package, and no release copy left in front of it on the path, as one
# would be after ubuntu itself was upgraded
tool_apt() {
  local cmd=$1 pkg=$2 opt=$HOME/.local/opt/$1 link=$HOME/.local/bin/$1
  if [[ $(dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null) != installed ]]; then
    say "installing $pkg"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get "${APT_WAIT[@]}" install -y --no-install-recommends "$pkg" </dev/null || return 1
  fi
  if [[ -L $link && $(readlink "$link") == "$opt"/* ]]; then rm -f "$link"; fi
  if [[ -d $opt ]]; then
    say "removing $cmd's release copy, now that ubuntu's package is new enough"
    rm -rf "$opt"
  fi
}

# tool_release <cmd> <repo> <asset regex>: the project's latest release, unpacked whole in
# ~/.local/opt/<cmd> with its tag beside it, and its command linked in ~/.local/bin; nothing when that tag
# is there already. the new copy is checked and unpacked next to the old one and takes its place only
# once it's whole, so a failed download leaves what you had
tool_release() {
  local cmd=$1 repo=$2 re=$3 opt=$HOME/.local/opt link=$HOME/.local/bin/$1
  local dir=$opt/$1 json tag asset name url digest tmp bin status=0
  json=$(gh_release "$repo" 2>/dev/null) || json=""
  tag=$(jq -r '.tag_name // empty' <<<"$json" 2>/dev/null) || tag=""
  if [[ -z $tag ]]; then
    # github out of reach, or over its hourly limit for lookups without a sign-in: what's there stays
    if [[ -x $link && -s $dir/.release ]]; then
      warn "couldn't check for a newer $cmd, so the one you have stays"
      return 0
    fi
    warn "couldn't look up $cmd's newest release"
    return 1
  fi
  [[ -x $link && $(cat "$dir/.release" 2>/dev/null) == "$tag" ]] && return 0
  asset=$(jq -r --arg re "$re" '[.assets[] | select(.name | test($re))][0] | select(. != null) | [.name, .browser_download_url, (.digest // "")] | @tsv' <<<"$json") || asset=""
  IFS=$'\t' read -r name url digest <<<"$asset"
  if [[ -z ${url:-} ]]; then
    warn "$cmd's release $tag has no file for this machine"
    return 1
  fi
  if [[ ${digest:-} != sha256:* ]]; then
    warn "github publishes no checksum for $cmd's $name, so it isn't installed"
    return 1
  fi
  say "installing $cmd $tag"
  mkdir -p "$opt" "$HOME/.local/bin"
  # what a run that was cut short left behind
  rm -rf "$opt/.$cmd."*
  if ! { tmp=$(mktemp -d "$opt/.$cmd.XXXXXX") && mkdir "$tmp/new"; }; then
    warn "couldn't make room for $cmd in $opt"
    return 1
  fi
  if ! fetch "$url" "$tmp/$name"; then
    warn "couldn't download $cmd"
    status=1
  elif ! release_verify "$digest" "$tmp/$name"; then
    warn "$cmd's download doesn't match the checksum github publishes for it, so it isn't installed"
    status=1
  elif ! release_unpack "$cmd" "$tmp/$name" "$tmp/new"; then
    warn "couldn't unpack $cmd"
    status=1
  else
    # the command is the file of that name in a bin folder, or else the one nearest the top
    bin=$(cd "$tmp/new" && find . -type f -name "$cmd" | awk -F/ '{ print ($(NF - 1) == "bin" ? 0 : 1), NF, $0 }' | sort -n -k1,1 -k2,2 | head -n 1 | cut -d' ' -f3-)
    if [[ -z $bin ]]; then
      warn "$cmd's release has no $cmd in it"
      status=1
    fi
  fi
  if ((status == 0)); then
    chmod +x "$tmp/new/$bin"
    echo "$tag" >"$tmp/new/.release"
    rm -rf "$dir.old"
    if [[ -e $dir ]] && ! mv "$dir" "$dir.old"; then
      warn "couldn't move the old $cmd aside"
      status=1
    elif ! mv "$tmp/new" "$dir"; then
      # the old copy goes back where it was
      if [[ -e $dir.old ]]; then mv "$dir.old" "$dir"; fi
      warn "couldn't put the new $cmd in place, so the old one stays"
      status=1
    else
      rm -rf "$dir.old"
      ln -sfn "$dir/${bin#./}" "$link"
    fi
  fi
  rm -rf "$tmp"
  return "$status"
}

# release_verify <sha256:digest> <file>: whether the file is the one github's api describes; one it gives
# no checksum for is not
release_verify() {
  [[ $1 == sha256:* ]] || return 1
  [[ $(sha256sum "$2" | awk '{ print $1 }') == "${1#sha256:}" ]]
}

# release_unpack <cmd> <file> <dir>: a tar.gz as it is, or a single gzipped command under its name
release_unpack() {
  case $2 in
    *.tar.gz | *.tgz) tar -xzf "$2" -C "$3" 2>/dev/null ;;
    *.gz) gunzip -c "$2" >"$3/$1" 2>/dev/null ;;
    *) return 1 ;;
  esac
}
