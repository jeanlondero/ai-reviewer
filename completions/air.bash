#!/usr/bin/env bash
# completions/air.bash — Bash completion for ai-reviewer / air.
# Source this file or place it in /etc/bash_completion.d/

_air_completions() {
  local cur prev commands config_subcommands config_keys

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="init push pr commit-lint ai-review ai-lint config doctor update help version"
  config_subcommands="set get unset list path edit init help"
  config_keys="provider api_key model strict"

  # Complete top-level commands
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "${commands} --help --version --no-color" -- "$cur")
    return 0
  fi

  # Complete config subcommands
  if [[ "${COMP_WORDS[1]}" == "config" ]]; then
    if [[ ${COMP_CWORD} -eq 2 ]]; then
      mapfile -t COMPREPLY < <(compgen -W "${config_subcommands}" -- "$cur")
      return 0
    fi

    # Complete config keys for set/get/unset
    if [[ ${COMP_CWORD} -eq 3 ]]; then
      case "$prev" in
        set|get|unset)
          mapfile -t COMPREPLY < <(compgen -W "${config_keys}" -- "$cur")
          return 0
          ;;
      esac
    fi
  fi

  return 0
}

complete -F _air_completions air
complete -F _air_completions ai-reviewer
