#!/usr/bin/env bash

# Shared Java toolchain discovery for development and packaging scripts.

java_major_version() {
  local java_bin="$1"
  local version_line
  version_line="$("$java_bin" -version 2>&1 | head -n 1)"
  if [[ "$version_line" =~ \"1\.([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$version_line" =~ \"([0-9]+)(\.|-|\") ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "0"
  fi
}

is_compatible_java_home() {
  local candidate="$1"
  [[ -n "$candidate" \
    && -x "$candidate/bin/java" \
    && "$(java_major_version "$candidate/bin/java")" -ge 25 ]]
}

resolve_java_25_home() {
  local candidate
  for candidate in "$@"; do
    if is_compatible_java_home "$candidate"; then
      echo "$candidate"
      return
    fi
  done

  if [[ "$(uname -s)" == "Darwin" && -x /usr/libexec/java_home ]]; then
    candidate="$(/usr/libexec/java_home -v 25 2>/dev/null || true)"
    if is_compatible_java_home "$candidate"; then
      echo "$candidate"
      return
    fi
  fi

  local java_bin
  java_bin="$(command -v java || true)"
  if [[ -n "$java_bin" && "$(java_major_version "$java_bin")" -ge 25 ]]; then
    candidate="$("$java_bin" -XshowSettings:properties -version 2>&1 \
      | awk -F'= ' '/^[[:space:]]*java.home = / {print $2; exit}')"
    if is_compatible_java_home "$candidate"; then
      echo "$candidate"
      return
    fi
  fi

  return 1
}
