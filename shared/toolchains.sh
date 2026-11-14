# shared/toolchains.sh: the languages mise manages, and rust through rustup
# shellcheck shell=bash

toolchains_install() {
  if [[ -n $(mise ls --current --missing 2>/dev/null) ]]; then
    say "installing node, bun, go, java, kotlin, zig and sesh with mise"
    mise install
  fi
  toolchains_rust
}

# toolchains_rust: rustup's stable toolchain, with rust-analyzer and the std sources it reads; fedora
# packages rustup-init, and on macos, where homebrew has none, it's rustup's own installer
toolchains_rust() {
  local rustup=${CARGO_HOME:-$HOME/.cargo}/bin/rustup installed c tmp
  local -a init=(rustup-init)
  if [[ ! -x $rustup ]]; then
    say "installing rust's stable toolchain"
    if [[ $(os_id) == macos ]]; then
      tmp=$(mktemp -d)
      if ! fetch https://sh.rustup.rs "$tmp/rustup-init.sh"; then
        rm -rf "$tmp"
        todo "rust didn't install, as rustup's installer didn't download: run dot install again"
        return 0
      fi
      init=(sh "$tmp/rustup-init.sh")
    fi
    RUSTUP_INIT_SKIP_PATH_CHECK=yes "${init[@]}" -y --no-modify-path --default-toolchain stable -c rust-analyzer -c rust-src
    if [[ -n ${tmp:-} ]]; then rm -rf "$tmp"; fi
    return
  fi
  "$rustup" show active-toolchain >/dev/null 2>&1 || "$rustup" default stable
  installed=$("$rustup" component list --installed)
  for c in rust-analyzer rust-src; do
    grep -qE "^$c(-|$)" <<<"$installed" || "$rustup" component add "$c"
  done
}

toolchains_update() {
  mise upgrade || warn "mise couldn't upgrade the languages"
  "${CARGO_HOME:-$HOME/.cargo}/bin/rustup" update || warn "rustup couldn't update rust"
  uv tool upgrade --all || warn "uv couldn't upgrade its tools"
}
