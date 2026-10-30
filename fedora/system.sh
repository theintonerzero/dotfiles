# fedora/system.sh: rpm fusion, the coprs, vscodium's repo, codecs, packages and removals
# shellcheck shell=bash

system_install() {
  system_repos
  system_codecs
  system_packages
  system_drivers
  system_removals
  system_snapshots
}

system_update() {
  if [[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs ]] && as_root snapper -c root get-config >/dev/null 2>&1; then
    say "taking a snapshot of / before the update"
    as_root snapper -c root create --description "before dot update" --cleanup-algorithm number ||
      warn "couldn't take a snapshot before the update"
  fi
  say "updating the system"
  as_root dnf upgrade -y --refresh
}

# system_snapshots: snapper for / on btrfs, for the snapshot each dot update takes first; no hourly
# ones, and the last 10 kept
system_snapshots() {
  [[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs ]] || return 0
  as_root snapper -c root get-config >/dev/null 2>&1 && return 0
  say "setting up snapshots of / with snapper"
  { as_root snapper -c root create-config / &&
    as_root snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=10; } ||
    warn "couldn't set up snapper"
}

# rpm fusion (free and nonfree), fedora's openh264 repo, the coprs and vscodium's repo
system_repos() {
  local fedora copr enabled
  fedora=$(rpm -E %fedora)
  if ! rpm -q --quiet rpmfusion-free-release rpmfusion-nonfree-release; then
    say "adding rpm fusion"
    as_root dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
  fi
  if ! grep -q '^fedora-cisco-openh264' <<<"$(dnf repolist --enabled 2>/dev/null)"; then
    say "turning on fedora's openh264 repo"
    as_root dnf config-manager setopt fedora-cisco-openh264.enabled=1
  fi
  enabled=$(dnf copr list 2>/dev/null || true)
  for copr in $(list "$DOTFILES/fedora/copr.txt"); do
    if ! grep -q "/$copr$" <<<"$enabled"; then
      say "adding the $copr copr"
      as_root dnf copr enable -y "$copr"
    fi
  done
  if [[ ! -f /etc/yum.repos.d/vscodium.repo ]]; then
    say "adding vscodium's repo"
    as_root rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
    as_root tee /etc/yum.repos.d/vscodium.repo >/dev/null <<'EOF'
[gitlab.com_paulcarroty_vscodium_repo]
name=download.vscodium.com
baseurl=https://download.vscodium.com/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg
metadata_expire=1h
EOF
  fi
}

# rpm fusion's full ffmpeg in place of fedora's, then the multimedia group, as rpm fusion's guide does it
system_codecs() {
  if rpm -q --quiet ffmpeg-free; then
    say "swapping ffmpeg-free for rpm fusion's ffmpeg"
    as_root dnf swap -y ffmpeg-free ffmpeg --allowerasing
  elif rpm -q --quiet libavcodec-free; then
    say "swapping fedora's ffmpeg libraries for rpm fusion's"
    as_root dnf swap -y libavcodec-free ffmpeg-libs --allowerasing
  fi
  if ! rpm -q --quiet ffmpeg; then
    say "installing ffmpeg"
    as_root dnf install -y ffmpeg
  fi
  if ! grep -qE '^Installed[[:space:]]*: yes' <<<"$(dnf group info multimedia 2>/dev/null)"; then
    say "installing the multimedia codecs"
    as_root dnf install -y @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin
  fi
}

# the packages in packages.txt that aren't installed yet
system_packages() {
  local pkg
  local -a missing=()
  for pkg in $(list "$DOTFILES/fedora/packages.txt"); do
    rpm -q --quiet "$pkg" || missing+=("$pkg")
  done
  ((${#missing[@]})) || return 0
  say "installing ${#missing[@]} packages"
  as_root dnf install -y "${missing[@]}"
}

# rpm fusion's video drivers, 64 and 32 bit for steam; runs after the packages, as steam pulls in fedora's
system_drivers() {
  if ! rpm -q --quiet mesa-va-drivers-freeworld.x86_64 mesa-va-drivers-freeworld.i686; then
    say "installing rpm fusion's video decoding drivers"
    as_root dnf install -y mesa-va-drivers-freeworld.x86_64 mesa-va-drivers-freeworld.i686
  fi
  # the swap removes both of fedora's builds but brings back only the 64-bit one, so the 32-bit one follows
  if rpm -q --quiet mesa-vulkan-drivers; then
    say "swapping fedora's vulkan drivers for rpm fusion's"
    as_root dnf swap -y mesa-vulkan-drivers mesa-vulkan-drivers-freeworld
  fi
  if ! rpm -q --quiet mesa-vulkan-drivers-freeworld.i686; then
    say "installing rpm fusion's 32-bit vulkan driver for steam"
    as_root dnf install -y mesa-vulkan-drivers-freeworld.i686
  fi
}

# the installed packages from remove.txt, except any that something you keep still needs
system_removals() {
  local pkg needer
  local -a wanted installed remove=()
  mapfile -t wanted < <(list "$DOTFILES/fedora/remove.txt")
  ((${#wanted[@]})) || return 0
  mapfile -t installed < <(rpm -qa --qf '%{NAME}\n' "${wanted[@]}" | sort -u)
  ((${#installed[@]})) || return 0
  # dnf takes whatever needs a removed package with it, so a package is removed only while everything
  # that needs it goes too; keeping one can keep another, so this repeats until nothing changes
  remove=("${installed[@]}")
  local -a left
  local kept=1
  while ((kept && ${#remove[@]})); do
    kept=0 left=()
    for pkg in "${remove[@]}"; do
      needer=$(dnf repoquery --installed --whatrequires "$pkg" --qf '%{name}\n' 2>/dev/null |
        grep -vxF -f <(printf '%s\n' "${remove[@]}") | head -n 1 || true)
      if [[ -n $needer ]]; then
        warn "keeping $pkg: $needer needs it"
        kept=1
      else
        left+=("$pkg")
      fi
    done
    remove=("${left[@]}")
  done
  ((${#remove[@]})) || return 0
  say "removing ${remove[*]}"
  as_root dnf remove -y "${remove[@]}"
}
