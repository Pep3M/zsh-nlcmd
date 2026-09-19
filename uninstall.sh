#!/usr/bin/env sh
# uninstall.sh — revierte la instalación.
#
#   ./uninstall.sh              pregunta antes de cada paso
#   ./uninstall.sh --yes        no pregunta, pero CONSERVA la clave de API
#   ./uninstall.sh --yes --purge-key   quita también la clave de .zshrc
#
# Deja siempre una copia de seguridad de .zshrc antes de tocarlo.

set -eu

RC="${ZDOTDIR:-$HOME}/.zshrc"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-nlcmd"
STATE="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/zsh-nlcmd-$(id -u)"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

AUTO=no
PURGE_KEY=no
for arg in "$@"; do
  case "$arg" in
    --yes)       AUTO=yes ;;
    --purge-key) PURGE_KEY=yes ;;
    *) echo "opción desconocida: $arg" >&2; exit 2 ;;
  esac
done

ask() {
  [ "$AUTO" = yes ] && return 0
  printf '%s [s/N] ' "$1"
  read -r a </dev/tty
  case "$a" in s|S|y|Y) return 0 ;; *) return 1 ;; esac
}

# --- .zshrc ----------------------------------------------------------------
# Se filtra por línea con coincidencia literal: nada de sed con expresiones
# regulares sobre el fichero de configuración de nadie.
clean_rc() {
  pattern=$1 label=$2
  [ -f "$RC" ] || return 0
  if ! grep -qF "$pattern" "$RC"; then
    echo "  · $label: no estaba"
    return 0
  fi
  echo "  Líneas que se quitarían de $RC:"
  grep -nF "$pattern" "$RC" | sed 's/^/    /'
  if ask "  ¿Las quito?"; then
    cp -- "$RC" "$RC.nlcmd-backup"
    tmp=$(mktemp) || return 1
    grep -vF "$pattern" -- "$RC" > "$tmp"
    cat -- "$tmp" > "$RC"
    rm -f -- "$tmp"
    echo "  · quitadas (copia en $RC.nlcmd-backup)"
  else
    echo "  · sin tocar"
  fi
}

echo "Desinstalando zsh-nlcmd"
echo
echo "1. Carga del plugin"
clean_rc "zsh-nlcmd.plugin.zsh" "línea de source"

echo
echo "2. Clave de API"
echo "  Ojo: puede que la uses para otras cosas. Solo se quita si lo pides."
if [ -f "$RC" ] && grep -q 'AI_GATEWAY_API_KEY' "$RC"; then
  if { [ "$PURGE_KEY" = yes ]; } ||
     { [ "$AUTO" = no ] && ask "  ¿Quitar también AI_GATEWAY_API_KEY de $RC?"; }; then
    cp -- "$RC" "$RC.nlcmd-backup"
    tmp=$(mktemp)
    grep -v 'AI_GATEWAY_API_KEY' -- "$RC" > "$tmp"
    cat -- "$tmp" > "$RC"
    rm -f -- "$tmp"
    echo "  · quitada (copia en $RC.nlcmd-backup)"
  else
    echo "  · conservada"
  fi
else
  echo "  · no estaba en $RC"
fi

# --- Datos en disco ---------------------------------------------------------
echo
echo "3. Datos en disco"
for d in "$CACHE" "$STATE"; do
  if [ -d "$d" ]; then
    rm -rf -- "$d"
    echo "  · borrado $d"
  else
    echo "  · no existía $d"
  fi
done
if [ -d "$HERE/verify/node_modules" ]; then
  rm -rf -- "$HERE/verify/node_modules"
  echo "  · borrado verify/node_modules"
fi
rm -f -- "${TMPDIR:-/tmp}"/nlcmd-req.* 2>/dev/null || true

# --- El repositorio ---------------------------------------------------------
echo
echo "4. El repositorio"
echo "  Está en $HERE"
if [ -d "$HERE/.git" ]; then
  echo "  Es un repositorio git; no lo borro yo. Si quieres:"
  echo "    rm -rf '$HERE'"
else
  if ask "  ¿Borro el directorio?"; then
    echo "  Ejecuta:  rm -rf '$HERE'"
  fi
fi

echo
echo "Listo. La sesión actual todavía tiene los widgets cargados en memoria."
echo "Para dejarla limpia sin cerrar la terminal:"
echo
echo "    exec zsh"
