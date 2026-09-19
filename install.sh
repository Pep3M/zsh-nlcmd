#!/usr/bin/env sh
# install.sh — instalación sin gestor de plugins.
#
#   git clone https://github.com/USUARIO/zsh-nlcmd && ./zsh-nlcmd/install.sh
#
# Si usas zinit, antidote, oh-my-zsh o similar, NO necesitas esto: mira el
# README. Este script solo clona el repositorio y te dice qué añadir a .zshrc;
# no modifica tu configuración sin preguntar.

set -eu

DEST="${NLCMD_DEST:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh-nlcmd}"
REPO="${NLCMD_REPO:-https://github.com/USUARIO/zsh-nlcmd.git}"
LINE="source $DEST/zsh-nlcmd.plugin.zsh"

for dep in zsh git curl jq; do
  command -v "$dep" >/dev/null 2>&1 || { echo "falta '$dep'. Instálalo y repite." >&2; exit 1; }
done

if [ -d "$DEST/.git" ]; then
  echo "Actualizando $DEST"
  git -C "$DEST" pull --ff-only
else
  echo "Clonando en $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --depth 1 "$REPO" "$DEST"
fi

RC="${ZDOTDIR:-$HOME}/.zshrc"
if [ -f "$RC" ] && grep -qF "$LINE" "$RC"; then
  echo "Tu .zshrc ya lo carga."
else
  echo
  echo "Añade esta línea a $RC:"
  echo
  echo "    $LINE"
  echo
  printf '¿La añado yo ahora? [s/N] '
  read -r answer
  case "$answer" in
    s|S|y|Y) printf '\n%s\n' "$LINE" >> "$RC"; echo "Añadida." ;;
    *)       echo "No he tocado nada." ;;
  esac
fi

echo
echo "Falta un paso: exporta tu clave del AI Gateway de Vercel."
echo "  https://vercel.com/docs/ai-gateway/authentication-and-byok/api-keys"
echo
echo "    export AI_GATEWAY_API_KEY='...'"
echo
echo "Luego abre una terminal nueva y ejecuta 'nlcmd doctor'."
