#!/usr/bin/env bash
# lib/core/ai_client.sh — Multi-provider AI client (Claude, OpenAI, Gemini).
# Public API: ai_call <prompt> [system_prompt]
# Returns response text on stdout, errors on stderr.

[[ -n "${_AIR_AI_CLIENT_LOADED:-}" ]] && return 0
_AIR_AI_CLIENT_LOADED=1

# Default timeout for API calls (seconds)
_AIR_AI_TIMEOUT="${AIR_AI_TIMEOUT:-60}"

ai_call() {
  local prompt="$1"
  local system_prompt="${2:-}"

  if [[ -z "$prompt" ]]; then
    error "ai_call: prompt is required"
    return 1
  fi

  # Resolve provider, model, api_key via config cascade
  local provider model api_key
  provider="$(config_get 'provider')"
  model="$(config_get 'model')"
  api_key="$(config_get 'api_key')"

  if [[ -z "$provider" ]]; then
    error "No AI provider configured"
    info "Run: air config init"
    return 1
  fi
  if [[ -z "$api_key" ]]; then
    error "No API key configured for provider '${provider}'"
    info "Run: air config set api_key <your-key>"
    return 1
  fi
  if [[ -z "$model" ]]; then
    # Default models per provider
    case "$provider" in
      claude)  model="claude-sonnet-4-20250514" ;;
      openai)  model="gpt-4o" ;;
      gemini)  model="gemini-2.0-flash" ;;
      *)       error "Unknown provider '${provider}' and no model set"; return 1 ;;
    esac
  fi

  # Dispatch to provider-specific handler
  case "$provider" in
    claude)  _ai_call_claude  "$prompt" "$system_prompt" "$model" "$api_key" ;;
    openai)  _ai_call_openai  "$prompt" "$system_prompt" "$model" "$api_key" ;;
    gemini)  _ai_call_gemini  "$prompt" "$system_prompt" "$model" "$api_key" ;;
    *)
      error "Unknown AI provider: ${provider}"
      info "Supported: claude, openai, gemini"
      return 1
      ;;
  esac
}

# --- Claude (Anthropic) ---
_ai_call_claude() {
  local prompt="$1" system_prompt="$2" model="$3" api_key="$4"
  local url="https://api.anthropic.com/v1/messages"

  local system_field=""
  if [[ -n "$system_prompt" ]]; then
    system_field="$(printf '"system": %s,' "$(_ai_json_escape "$system_prompt")")"
  fi

  local body
  body="$(printf '{%s "model": %s, "max_tokens": 4096, "messages": [{"role": "user", "content": %s}]}' \
    "$system_field" \
    "$(_ai_json_escape "$model")" \
    "$(_ai_json_escape "$prompt")")"

  local response http_code
  response="$(_ai_http_request "$url" "$body" \
    -H "x-api-key: ${api_key}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json")"
  http_code=$?

  if [[ $http_code -ne 0 ]]; then
    return 1
  fi

  _ai_extract_text_claude "$response"
}

# --- OpenAI ---
_ai_call_openai() {
  local prompt="$1" system_prompt="$2" model="$3" api_key="$4"
  local url="https://api.openai.com/v1/chat/completions"

  local messages=""
  if [[ -n "$system_prompt" ]]; then
    messages="$(printf '{"role": "system", "content": %s}, ' "$(_ai_json_escape "$system_prompt")")"
  fi
  messages="${messages}$(printf '{"role": "user", "content": %s}' "$(_ai_json_escape "$prompt")")"

  local body
  body="$(printf '{"model": %s, "messages": [%s]}' \
    "$(_ai_json_escape "$model")" \
    "$messages")"

  local response
  if ! response="$(_ai_http_request "$url" "$body" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json")"; then
    return 1
  fi

  _ai_extract_text_openai "$response"
}

# --- Gemini (Google) ---
_ai_call_gemini() {
  local prompt="$1" system_prompt="$2" model="$3" api_key="$4"
  local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${api_key}"

  local system_field=""
  if [[ -n "$system_prompt" ]]; then
    system_field="$(printf '"system_instruction": {"parts": [{"text": %s}]}, ' "$(_ai_json_escape "$system_prompt")")"
  fi

  local body
  body="$(printf '{%s "contents": [{"parts": [{"text": %s}]}]}' \
    "$system_field" \
    "$(_ai_json_escape "$prompt")")"

  local response
  if ! response="$(_ai_http_request "$url" "$body" \
    -H "Content-Type: application/json")"; then
    return 1
  fi

  _ai_extract_text_gemini "$response"
}

# --- HTTP request wrapper ---
_ai_http_request() {
  local url="$1"
  shift
  local body="$1"
  shift

  local http_response http_code body_file header_file
  body_file="$(mktemp)"
  header_file="$(mktemp)"
  trap 'rm -f "$body_file" "$header_file"' RETURN

  http_code="$(curl -sS -w '%{http_code}' \
    --max-time "$_AIR_AI_TIMEOUT" \
    -o "$body_file" \
    -D "$header_file" \
    -X POST \
    "$@" \
    -d "$body" \
    "$url" 2>/dev/null)" || {
    error "Network error: could not reach ${url%%\?*}"
    return 1
  }

  http_response="$(cat "$body_file")"

  case "$http_code" in
    200) printf '%s' "$http_response"; return 0 ;;
    401|403)
      error "Authentication failed (HTTP ${http_code})"
      info "Check your API key: air config get api_key"
      return 1
      ;;
    429)
      error "Rate limited (HTTP 429)"
      info "Wait a moment and try again"
      return 1
      ;;
    5[0-9][0-9])
      error "Server error (HTTP ${http_code})"
      info "The provider may be experiencing issues — try again later"
      return 1
      ;;
    *)
      error "API request failed (HTTP ${http_code})"
      # Try to extract error message
      local err_msg
      err_msg="$(_ai_extract_error "$http_response")"
      if [[ -n "$err_msg" ]]; then
        info "Error: ${err_msg}"
      fi
      return 1
      ;;
  esac
}

# --- JSON escape (pure bash) ---
_ai_json_escape() {
  local s="$1"
  # Escape backslashes first, then quotes, then control chars
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# --- Response text extraction ---

_ai_extract_text_claude() {
  local response="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$response" | jq -r '.content[0].text // empty' 2>/dev/null && return 0
  fi
  # Fallback: grep/sed
  printf '%s' "$response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1
}

_ai_extract_text_openai() {
  local response="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null && return 0
  fi
  # Fallback
  printf '%s' "$response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1
}

_ai_extract_text_gemini() {
  local response="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null && return 0
  fi
  # Fallback
  printf '%s' "$response" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1
}

# --- API key validation ---
# Usage: ai_validate_key <provider> <api_key> [model]
# Returns: 0=valid, 1=auth fail, 2=network error

ai_validate_key() {
  local provider="$1" api_key="$2" model="${3:-}"

  case "$provider" in
    claude)  _ai_validate_claude "$api_key" "$model" ;;
    openai)  _ai_validate_openai "$api_key" ;;
    gemini)  _ai_validate_gemini "$api_key" ;;
    *)       return 1 ;;
  esac
}

_ai_validate_claude() {
  local api_key="$1" model="${2:-claude-haiku-4-5-20251001}"
  local url="https://api.anthropic.com/v1/messages"

  local body
  body="$(printf '{"model": %s, "max_tokens": 1, "messages": [{"role": "user", "content": "hi"}]}' \
    "$(_ai_json_escape "$model")")"

  local body_file http_code
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' RETURN

  http_code="$(curl -sS -w '%{http_code}' \
    --max-time 15 \
    -o "$body_file" \
    -X POST \
    -H "x-api-key: ${api_key}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$body" \
    "$url" 2>/dev/null)" || return 2

  case "$http_code" in
    200) return 0 ;;
    401|403) return 1 ;;
    *) return 0 ;;  # Other codes (429, 5xx) mean auth worked
  esac
}

_ai_validate_openai() {
  local api_key="$1"
  local url="https://api.openai.com/v1/models"

  local body_file http_code
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' RETURN

  http_code="$(curl -sS -w '%{http_code}' \
    --max-time 15 \
    -o "$body_file" \
    -H "Authorization: Bearer ${api_key}" \
    "$url" 2>/dev/null)" || return 2

  case "$http_code" in
    200) return 0 ;;
    401|403) return 1 ;;
    *) return 2 ;;
  esac
}

_ai_validate_gemini() {
  local api_key="$1"
  local url="https://generativelanguage.googleapis.com/v1beta/models?key=${api_key}"

  local body_file http_code
  body_file="$(mktemp)"
  trap 'rm -f "$body_file"' RETURN

  http_code="$(curl -sS -w '%{http_code}' \
    --max-time 15 \
    -o "$body_file" \
    "$url" 2>/dev/null)" || return 2

  case "$http_code" in
    200) return 0 ;;
    400|401|403) return 1 ;;
    *) return 2 ;;
  esac
}

_ai_extract_error() {
  local response="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$response" | jq -r '.error.message // .error // empty' 2>/dev/null && return 0
  fi
  printf '%s' "$response" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1
}
