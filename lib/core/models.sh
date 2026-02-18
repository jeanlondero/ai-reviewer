#!/usr/bin/env bash
# lib/core/models.sh — Curated model catalog with optional dynamic fetch.
# Hardcoded catalog + API-based discovery for OpenAI and Gemini.
# Lazy-loaded — not sourced at startup.

[[ -n "${_AIR_MODELS_LOADED:-}" ]] && return 0
_AIR_MODELS_LOADED=1

# --- Hardcoded catalog ---
# Format: _AIR_MODELS_<PROVIDER>[model_id]="description"
# Default models: _AIR_MODEL_DEFAULT_<PROVIDER>

declare -gA _AIR_MODELS_CLAUDE=(
  [claude-sonnet-4-20250514]="Fast, balanced"
  [claude-opus-4-20250514]="Most capable"
  [claude-haiku-4-5-20251001]="Fastest, cheapest"
)
_AIR_MODEL_DEFAULT_CLAUDE="claude-sonnet-4-20250514"

declare -gA _AIR_MODELS_OPENAI=(
  [gpt-4o]="Flagship multimodal"
  [gpt-4o-mini]="Small and fast"
  [o1]="Advanced reasoning"
  [o3-mini]="Fast reasoning"
)
_AIR_MODEL_DEFAULT_OPENAI="gpt-4o"

declare -gA _AIR_MODELS_GEMINI=(
  [gemini-2.0-flash]="Fast multimodal"
  [gemini-2.5-pro]="Most capable"
  [gemini-2.5-flash]="Best value, fast"
)
_AIR_MODEL_DEFAULT_GEMINI="gemini-2.0-flash"

# --- Dynamic models fetched at runtime ---
declare -gA _AIR_MODELS_DYNAMIC=()

# --- Public API ---

# List model IDs for a provider (one per line on stdout)
models_list_for_provider() {
  local provider="$1"
  local catalog_var="_AIR_MODELS_${provider^^}"

  # Check if the catalog associative array exists
  if ! declare -p "$catalog_var" &>/dev/null; then
    return 1
  fi

  local -n catalog="$catalog_var"

  # Output hardcoded models
  local model
  for model in $(printf '%s\n' "${!catalog[@]}" | sort); do
    printf '%s\n' "$model"
  done

  # Append dynamic models not already in catalog
  for model in $(printf '%s\n' "${!_AIR_MODELS_DYNAMIC[@]}" | sort); do
    if [[ "$model" == "${provider}:"* ]]; then
      local model_id="${model#*:}"
      if [[ -z "${catalog[$model_id]:-}" ]]; then
        printf '%s\n' "$model_id"
      fi
    fi
  done
}

# Get default model for a provider
models_get_default() {
  local provider="$1"
  local varname="_AIR_MODEL_DEFAULT_${provider^^}"
  printf '%s' "${!varname:-}"
}

# Get description for a specific model
models_get_description() {
  local provider="$1" model="$2"
  local -n catalog="_AIR_MODELS_${provider^^}" 2>/dev/null || return 1

  if [[ -n "${catalog[$model]:-}" ]]; then
    printf '%s' "${catalog[$model]}"
    return 0
  fi

  # Check dynamic models
  if [[ -n "${_AIR_MODELS_DYNAMIC[${provider}:${model}]:-}" ]]; then
    printf '%s' "${_AIR_MODELS_DYNAMIC[${provider}:${model}]}"
    return 0
  fi

  return 1
}

# Get formatted display list for air_menu (value:Label format)
models_get_display_list() {
  local provider="$1"
  local default
  default="$(models_get_default "$provider")"

  local model desc suffix
  while IFS= read -r model; do
    [[ -z "$model" ]] && continue
    desc="$(models_get_description "$provider" "$model" 2>/dev/null || true)"
    suffix=""
    if [[ "$model" == "$default" ]]; then
      suffix=" (recommended)"
    fi
    if [[ -n "$desc" ]]; then
      printf '%s:%s — %s%s\n' "$model" "$model" "$desc" "$suffix"
    else
      printf '%s:%s%s\n' "$model" "$model" "$suffix"
    fi
  done < <(models_list_for_provider "$provider")
}

# Fetch models dynamically from provider API
# Returns: 0=ok, 1=fail
models_fetch_dynamic() {
  local provider="$1" api_key="$2"

  case "$provider" in
    openai)  _models_fetch_openai "$api_key" ;;
    gemini)  _models_fetch_gemini "$api_key" ;;
    claude)  return 1 ;;  # No public listing endpoint
    *)       return 1 ;;
  esac
}

# --- Private fetch implementations ---

_models_fetch_openai() {
  local api_key="$1"
  local response

  response="$(curl -sS --max-time 10 \
    -H "Authorization: Bearer ${api_key}" \
    "https://api.openai.com/v1/models" 2>/dev/null)" || return 1

  if ! command -v jq &>/dev/null; then
    # Fallback: grep for model IDs
    local model
    while IFS= read -r model; do
      model="${model//\"/}"
      model="${model//,/}"
      model="${model// /}"
      [[ -z "$model" ]] && continue
      _AIR_MODELS_DYNAMIC["openai:${model}"]="(from API)"
    done < <(printf '%s' "$response" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | grep -E '^(gpt-|o1|o3)')
    return 0
  fi

  local model
  while IFS= read -r model; do
    [[ -z "$model" ]] && continue
    _AIR_MODELS_DYNAMIC["openai:${model}"]="(from API)"
  done < <(printf '%s' "$response" | jq -r '.data[].id // empty' 2>/dev/null | grep -E '^(gpt-|o1|o3)')

  return 0
}

_models_fetch_gemini() {
  local api_key="$1"
  local response

  response="$(curl -sS --max-time 10 \
    "https://generativelanguage.googleapis.com/v1beta/models?key=${api_key}" 2>/dev/null)" || return 1

  if ! command -v jq &>/dev/null; then
    local model
    while IFS= read -r model; do
      model="${model//\"/}"
      model="${model//,/}"
      model="${model// /}"
      # Strip "models/" prefix
      model="${model#models/}"
      [[ -z "$model" ]] && continue
      _AIR_MODELS_DYNAMIC["gemini:${model}"]="(from API)"
    done < <(printf '%s' "$response" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | grep -i 'gemini')
    return 0
  fi

  local model
  while IFS= read -r model; do
    [[ -z "$model" ]] && continue
    # Strip "models/" prefix
    model="${model#models/}"
    _AIR_MODELS_DYNAMIC["gemini:${model}"]="(from API)"
  done < <(printf '%s' "$response" | jq -r '.models[] | select(.supportedGenerationMethods | index("generateContent")) | .name // empty' 2>/dev/null | grep -i 'gemini')

  return 0
}
