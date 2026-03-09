#!/usr/bin/env bash
set -euo pipefail

TARGET_KEYS=(
  zshrc
  zshenv
  zprofile
  gitconfig
  gitignore
  tmux
  starship
  ghostty
  sshconfig
)
BACKUP_RESULTS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/backups.sh <command> [args]

Commands:
  list
      List available backups for managed symlink targets.

  prune [keep_count]
      Keep newest N backups per target (default: 5), delete older ones.

  restore <target> [latest|timestamp|full_backup_path]
      Restore a backup for a target. Current target is saved first.

Targets:
  zshrc, zshenv, zprofile, gitconfig, gitignore, tmux, starship, ghostty, sshconfig
EOF
}

target_path() {
  case "$1" in
    zshrc) echo "${HOME}/.zshrc" ;;
    zshenv) echo "${HOME}/.zshenv" ;;
    zprofile) echo "${HOME}/.zprofile" ;;
    gitconfig) echo "${HOME}/.gitconfig" ;;
    gitignore) echo "${HOME}/.gitignore_global" ;;
    tmux) echo "${HOME}/.tmux.conf" ;;
    starship) echo "${HOME}/.config/starship.toml" ;;
    ghostty) echo "${HOME}/.config/ghostty/config" ;;
    sshconfig) echo "${HOME}/.ssh/config" ;;
    *)
      return 1
      ;;
  esac
}

emit_sorted_backups() {
  local target="$1"
  local backups=()

  shopt -s nullglob
  backups=( "${target}.backup."* )
  shopt -u nullglob

  if (( ${#backups[@]} == 0 )); then
    return 0
  fi

  printf '%s\n' "${backups[@]}" | sort -r
}

collect_backups() {
  local target="$1"
  BACKUP_RESULTS=()

  while IFS= read -r backup; do
    [[ -z "${backup}" ]] && continue
    BACKUP_RESULTS+=("${backup}")
  done < <(emit_sorted_backups "${target}")
}

list_backups() {
  local key
  local target
  local found

  for key in "${TARGET_KEYS[@]}"; do
    target="$(target_path "${key}")"
    found=0

    echo "${key}: ${target}"
    while IFS= read -r backup; do
      [[ -z "${backup}" ]] && continue
      echo "  ${backup}"
      found=1
    done < <(emit_sorted_backups "${target}")

    if (( found == 0 )); then
      echo "  (none)"
    fi
  done
}

prune_backups() {
  local keep_count="$1"
  local key
  local target
  local backups=()
  local i

  if ! [[ "${keep_count}" =~ ^[0-9]+$ ]] || (( keep_count < 1 )); then
    echo "keep_count must be an integer >= 1"
    exit 1
  fi

  for key in "${TARGET_KEYS[@]}"; do
    target="$(target_path "${key}")"
    collect_backups "${target}"
    backups=( "${BACKUP_RESULTS[@]}" )

    if (( ${#backups[@]} <= keep_count )); then
      continue
    fi

    for (( i = keep_count; i < ${#backups[@]}; i++ )); do
      rm -f "${backups[$i]}"
      echo "Removed ${backups[$i]}"
    done
  done
}

restore_backup() {
  local key="$1"
  local selector="${2:-latest}"
  local target
  local backups=()
  local selected_backup
  local current_backup

  if ! target="$(target_path "${key}")"; then
    echo "Unknown target: ${key}"
    usage
    exit 1
  fi

  collect_backups "${target}"
  backups=( "${BACKUP_RESULTS[@]}" )

  if (( ${#backups[@]} == 0 )); then
    echo "No backups found for target: ${key}"
    exit 1
  fi

  if [[ "${selector}" == "latest" ]]; then
    selected_backup="${backups[0]}"
  elif [[ -e "${selector}" || -L "${selector}" ]]; then
    selected_backup="${selector}"
  elif [[ -e "${target}.backup.${selector}" || -L "${target}.backup.${selector}" ]]; then
    selected_backup="${target}.backup.${selector}"
  else
    echo "Backup not found for selector: ${selector}"
    exit 1
  fi

  if [[ -e "${target}" || -L "${target}" ]]; then
    current_backup="${target}.backup.$(date +%Y%m%d%H%M%S).restore-current"
    mv "${target}" "${current_backup}"
    echo "Saved current target to ${current_backup}"
  fi

  mv "${selected_backup}" "${target}"
  echo "Restored ${selected_backup} -> ${target}"
}

main() {
  local cmd="${1:-list}"

  case "${cmd}" in
    list)
      list_backups
      ;;
    prune)
      prune_backups "${2:-5}"
      ;;
    restore)
      if [[ $# -lt 2 ]]; then
        echo "restore requires a target argument."
        usage
        exit 1
      fi
      restore_backup "$2" "${3:-latest}"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "Unknown command: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
