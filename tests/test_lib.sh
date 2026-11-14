# tests/test_lib.sh: lib.sh's helpers and shared/platform.sh
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
lib
# shellcheck source=../shared/platform.sh
source "$REPO/shared/platform.sh"

eq "os override" macos "$(DOT_OS=macos os_id)"

mkdir -p "$T/root/pkg/.config/my app"
touch "$T/root/pkg/.config/my app/a file"
ln -s "a file" "$T/root/pkg/.config/my app/l"
eq "package_files" "$(printf '%s\n' '.config/my app/a file' '.config/my app/l')" "$(package_files "$T/root" pkg | sort)"
eq "package_dirs" "$(printf '%s\n' .config '.config/my app')" "$(package_dirs "$T/root" pkg | sort)"

mkdir -p "$T/a/b"
ln -s ../../gone/x/y "$T/a/b/rel"
ln -s /nowhere/z "$T/a/b/abs"
eq "link_dest relative" "$T/gone/x/y" "$(link_dest "$T/a/b/rel")"
eq "link_dest absolute" /nowhere/z "$(link_dest "$T/a/b/abs")"

stub pgrep '[[ $2 == Godot ]]'
ok "running finds the mac name" running godot Godot
no "running misses" running blender Blender

eq "app_dir fedora" "$HOME/.config/godot" "$(DOT_OS=fedora app_dir godot Godot)"
eq "app_dir macos" "$HOME/Library/Application Support/Godot" "$(DOT_OS=macos app_dir godot Godot)"

# an update begun by an older lib.sh starts again
cat >"$T/old.sh" <<EOF
#!/usr/bin/env bash
if [[ -n \${DOT_RESTARTED:-} ]]; then echo restarted; exit 0; fi
unset DOT_LIB
source "$REPO/shared/platform.sh"
echo "not restarted"
EOF
chmod +x "$T/old.sh"
eq "stale lib restarts" restarted "$("$T/old.sh")"
