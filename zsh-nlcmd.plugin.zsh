# zsh-nlcmd — convierte lenguaje natural en comandos, dentro del prompt.
#
#   # listar los puertos que están escuchando
#     ⟶ lsof -iTCP -sTCP:LISTEN -n -P        <-- Tab para aceptar
#
# La sugerencia NUNCA se ejecuta sola. Tab la escribe en el buffer; el Enter
# siempre lo das tú.

typeset -g NLCMD_ROOT=${0:A:h}

source "$NLCMD_ROOT/lib/config.zsh"
source "$NLCMD_ROOT/lib/context.zsh"

# Sin esto, zsh intenta ejecutar '#' como si fuera un comando. Con esto, una
# línea disparada que llegue a ejecutarse es un comentario inerte: es la razón
# por la que el comodín es '#' y no otro carácter.
setopt interactive_comments

if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
  print -u2 "zsh-nlcmd: faltan jq y/o curl; el plugin queda desactivado."
  return 0
fi

source "$NLCMD_ROOT/lib/widgets.zsh"

typeset -g _NLCMD_ORIG_TAB=${${(z)$(bindkey '^I')}[2]:-expand-or-complete}
bindkey '^I' _nlcmd_accept      # Tab acepta la sugerencia (o completa, si no hay)
bindkey '^ ' _nlcmd_accept      # Ctrl+Espacio, alternativa explícita

nlcmd() {
  case ${1:-} in
    doctor)
      print "root:      $NLCMD_ROOT"
      print "modelo:    $NLCMD_MODEL"
      print "endpoint:  $NLCMD_BASE_URL"
      # Nunca imprimir el valor: solo si existe y cuánto mide.
      local key=${(P)NLCMD_API_KEY_VAR}
      if [[ -n $key ]]; then
        print "clave:     \$$NLCMD_API_KEY_VAR definida (${#key} caracteres)"
      else
        print "clave:     AUSENTE — exporta \$$NLCMD_API_KEY_VAR"
      fi
      print "comodín:   '$NLCMD_TRIGGER'  (mínimo $NLCMD_MIN_CHARS caracteres)"
      print "debounce:  ${NLCMD_DEBOUNCE}s   timeout: ${NLCMD_TIMEOUT}s"
      print -n "verificación Jev: "
      if [[ $NLCMD_VERIFY != 1 ]]; then print "desactivada (NLCMD_VERIFY=1 para activarla)"
      elif ! command -v node &>/dev/null; then print "activada pero falta node"
      elif [[ ! -d $NLCMD_ROOT/verify/node_modules ]]; then print "activada pero falta 'npm install' en $NLCMD_ROOT/verify"
      else print "activa ($NLCMD_VERIFY_MODEL)"; fi
      print "contexto enviado:"
      nlcmd_context | sed 's/^/  /'
      ;;
    clear-cache)
      rm -rf -- $NLCMD_CACHE_DIR && print "caché borrada: $NLCMD_CACHE_DIR" ;;
    *)
      print "uso: nlcmd {doctor|clear-cache}" ;;
  esac
}
