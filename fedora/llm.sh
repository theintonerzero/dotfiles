# fedora/llm.sh: local llms: rocm from fedora's packages on an amd gpu, and lm studio with its rocm engine
# beside its vulkan one, which stays the default
# shellcheck shell=bash

LMSTUDIO=$HOME/.local/opt/lm-studio/LM-Studio.AppImage
LMS=$HOME/.lmstudio/bin/lms

llm_install() {
  rocm_install
  lmstudio_install || todo "LM Studio didn't install; dot update tries again"
  lmstudio_setup
}

llm_update() {
  lmstudio_install || todo "LM Studio didn't update; dot update tries again"
  lmstudio_setup update
}

# amd_gpu: true when the kernel's gpu compute driver, which only amd gpus use, lists a gpu
amd_gpu() { grep -qsE '^gfx_target_version [1-9]' /sys/class/kfd/kfd/topology/nodes/*/properties; }

# rocm_install: the packages in rocm.txt, when there's an amd gpu for them; dot update's dnf upgrade
# keeps them current
rocm_install() {
  local pkg
  local -a missing=()
  amd_gpu || return 0
  for pkg in $(list "$DOTFILES/fedora/rocm.txt"); do
    rpm -q --quiet "$pkg" || missing+=("$pkg")
  done
  if ((${#missing[@]})); then
    say "installing rocm for your amd gpu"
    if ! as_root dnf install -y "${missing[@]}"; then
      todo "ROCm didn't install; dot install tries again"
      return 0
    fi
  fi
  if have rocminfo && ! rocminfo 2>/dev/null | grep -qE '^[[:space:]]+Name:[[:space:]]+gfx[0-9]'; then
    warn "rocm is installed, but rocminfo doesn't see your gpu"
  fi
}

# lmstudio_install: lm studio's newest appimage from lmstudio.ai when it's newer than the one here (lm
# studio also updates itself), and its launcher in gnome's app grid
lmstudio_install() {
  local url want have="" tmp
  tmp=$(mktemp -d)
  if [[ -x $LMSTUDIO ]]; then have=$(lmstudio_unpack "$tmp"); fi
  url=$(curl -fsSI -o /dev/null -w '%{redirect_url}' https://lmstudio.ai/download/latest/linux/x64) || url=""
  want=${url%/*}
  want=${want##*/}
  if [[ $url != https://installers.lmstudio.ai/*.AppImage ]]; then
    warn "couldn't look up LM Studio's newest release"
  elif [[ -z $have || $(printf '%s\n' "$have" "$want" | sort -V | tail -n 1) != "$have" ]]; then
    say "installing LM Studio $want, about 1 GB"
    mkdir -p "${LMSTUDIO%/*}"
    if fetch "$url" "$LMSTUDIO"; then
      chmod +x "$LMSTUDIO"
      rm -rf "${tmp:?}/squashfs-root"
      lmstudio_unpack "$tmp" >/dev/null
    else
      warn "couldn't download LM Studio"
    fi
  fi
  if [[ -x $LMSTUDIO ]]; then lmstudio_launcher "$tmp/squashfs-root"; fi
  rm -rf "$tmp"
  [[ -x $LMSTUDIO ]]
}

# lmstudio_unpack <dir>: the appimage's package.json, desktop file and icon in <dir>/squashfs-root, and its
# version as lmstudio.ai's links write it: 0.4.28-2 where the app says 0.4.28+2
lmstudio_unpack() {
  local f v
  for f in resources/app/package.json ai.elementlabs.lmstudio.desktop lm-studio.png; do
    (cd "$1" && "$LMSTUDIO" --appimage-extract "$f") >/dev/null 2>&1
  done
  # the icon is a link to one of the sizes inside
  if [[ -L $1/squashfs-root/lm-studio.png ]]; then
    f=$(readlink "$1/squashfs-root/lm-studio.png")
    (cd "$1" && "$LMSTUDIO" --appimage-extract "$f") >/dev/null 2>&1
  fi
  v=$(jq -r '.version // empty' "$1/squashfs-root/resources/app/package.json" 2>/dev/null) || v=""
  printf '%s\n' "${v//+/-}"
}

# lmstudio_launcher <unpacked>: lm studio in gnome's app grid, from its own desktop file, so gnome still
# matches its windows to it, pointed at the appimage and the icon beside it
lmstudio_launcher() {
  local src=$1 dir=${LMSTUDIO%/*} apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications want
  local entry=$apps/ai.elementlabs.lmstudio.desktop
  if [[ ! -f $src/ai.elementlabs.lmstudio.desktop || ! -f $src/lm-studio.png ]]; then
    warn "couldn't find LM Studio's launcher in its appimage"
    return 0
  fi
  cmp -s "$src/lm-studio.png" "$dir/lm-studio.png" || cp -f "$src/lm-studio.png" "$dir/lm-studio.png"
  want=$(sed -e "s|^Exec=.*|Exec=\"$LMSTUDIO\" %U|" -e "s|^Icon=.*|Icon=$dir/lm-studio.png|" \
    -e 's|^Name=.*|Name=LM Studio|' -e '/^category=/d' -e '/^X-AppImage-Version=/d' \
    "$src/ai.elementlabs.lmstudio.desktop")
  [[ -f $entry && $(<"$entry") == "$want" ]] && return 0
  say "adding LM Studio to the app grid"
  mkdir -p "$apps"
  printf '%s\n' "$want" >"$entry"
  if have update-desktop-database; then update-desktop-database -q "$apps" || true; fi
}

# lmstudio_setup [update]: lm studio's rocm engine and settings, once lm studio has run and put lms in
# ~/.lmstudio/bin
lmstudio_setup() {
  if [[ ! -x $LMS ]]; then
    todo "open LM Studio once, then run dot install again to finish setting it up"
    return 0
  fi
  lmstudio_rocm "${1:-}"
  lmstudio_settings
}

# lmstudio_rocm [update]: lm studio's rocm engine, with its own rocm, on an amd gpu; lms runs lm studio
# in the background when it isn't open, so that one's closed again after
lmstudio_rocm() {
  local have=0 running=0
  amd_gpu || return 0
  if compgen -G "$HOME/.lmstudio/extensions/backends/llama.cpp-*-rocm-*" >/dev/null; then have=1; fi
  ((have)) && [[ ${1:-} != update ]] && return 0
  if pgrep -x lm-studio >/dev/null; then running=1; fi
  if ((have)); then
    quiet "$LMS" runtime update llama.cpp:rocm -y || warn "couldn't update LM Studio's ROCm engine"
  else
    say "adding LM Studio's ROCm engine, about 1.7 GB, beside its Vulkan one"
    quiet "$LMS" runtime get llama.cpp:rocm -y || warn "couldn't add LM Studio's ROCm engine"
  fi
  ((running)) || lmstudio_quit
}

# lmstudio_quit: lm studio's main process, the oldest, asked to quit, with 10s to do it
lmstudio_quit() {
  pkill -TERM -o -x lm-studio || return 0
  for _ in {1..20}; do
    pgrep -x lm-studio >/dev/null || return 0
    sleep 0.5
  done
  warn "LM Studio is still running"
}
