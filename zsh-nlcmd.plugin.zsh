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
    test)
      # Petición real, con la respuesta del servidor tal cual. Es el único modo
      # de distinguir clave inválida, modelo no disponible y presupuesto agotado.
      local key=${(P)NLCMD_API_KEY_VAR}
      if [[ -z $key ]]; then
        print -u2 "No hay clave: exporta \$$NLCMD_API_KEY_VAR"
        return 1
      fi
      print "POST $NLCMD_BASE_URL/chat/completions  (modelo: $NLCMD_MODEL)"
      local body resp code
      body=$(jq -n --arg m "$NLCMD_MODEL" \
        '{model:$m, messages:[{role:"user",content:"di ok"}], max_tokens:5}')
      resp=$(print -r -- "header = \"Authorization: Bearer ${${key//\\/\\\\}//\"/\\\"}\"" |
        curl -sS -K - --max-time 15 -w $'\n%{http_code}' \
          "$NLCMD_BASE_URL/chat/completions" \
          -H 'Content-Type: application/json' --data-binary "$body" 2>&1)
      code=${resp##*$'\n'}; resp=${resp%$'\n'*}
      print "HTTP $code"
      print -r -- "${$(print -r -- "$resp" | jq . 2>/dev/null):-$resp}"
      case $code in
        200) print "\nLa clave y el modelo funcionan." ;;
        401) print "\nLa clave no es válida. Genera una nueva en:\n  https://vercel.com/d/stores/ai-gateway" ;;
        403)
          # El 403 más común no es falta de permisos: es que Vercel exige una
          # tarjeta registrada para liberar los créditos gratuitos.
          if [[ $resp == *customer_verification_required* ]]; then
            print "\nLa clave es válida. Vercel pide una tarjeta registrada para"
            print "desbloquear los créditos gratuitos (no cobra por ello):"
            print "  https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fai%3Fmodal%3Dadd-credit-card"
          else
            print "\nClave válida pero sin permiso para este modelo, o presupuesto agotado."
          fi
          ;;
        404) print "\nEse modelo no existe en el gateway. Lista disponibles en:\n  https://vercel.com/ai-gateway/models" ;;
      esac
      ;;
    clear-cache)
      rm -rf -- $NLCMD_CACHE_DIR && print "caché borrada: $NLCMD_CACHE_DIR" ;;
    *)
      print "uso: nlcmd {doctor|test|clear-cache}" ;;
  esac
}
