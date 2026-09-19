# lib/widgets.zsh — ghost text asíncrono sobre ZLE.
#
# Flujo: cada modificación del buffer incrementa una generación y lanza un
# worker en segundo plano. El worker duerme el debounce y se auto-aborta si la
# generación ya no es la actual, así que solo la última pulsación llega a la
# red. El resultado vuelve por un descriptor vigilado con `zle -F`, que es la
# única forma de hacer E/S no bloqueante dentro de ZLE.
#
# Dos detalles no obvios de ZLE, ambos aprendidos a base de que no funcionara:
#
#  1. Un manejador `zle -F` NO es un widget: dentro de él BUFFER, CURSOR y
#     POSTDISPLAY están vacíos. Por eso la consulta que corresponde a cada
#     generación se guarda al dispararla (_NLCMD_PENDING_Q) en vez de releerse
#     del buffer al recibir la respuesta.
#  2. Por lo mismo, para pintar hay que invocar un widget registrado con
#     `zle -N` Y llamar a `zle -R` después. Las dos cosas: el widget solo, o
#     `zle -R` sobre POSTDISPLAY asignado directamente, no repintan.

# Depuración: NLCMD_DEBUG=/ruta/al/log para seguir el flujo desde otra terminal.
_nlcmd_log() { [[ -n ${NLCMD_DEBUG:-} ]] && print -r -- "${(%):-%D{%T}} $*" >> $NLCMD_DEBUG }

typeset -g _NLCMD_GEN=0
typeset -g _NLCMD_SUGGESTION=
typeset -g _NLCMD_LAST_Q=
typeset -g _NLCMD_PENDING_Q=
typeset -g _NLCMD_HL=
typeset -g _NLCMD_FD=
typeset -g _NLCMD_VFD=

# --- Consulta actual, o fallo si el buffer no está disparado ----------------
_nlcmd_query() {
  setopt local_options extended_glob
  [[ $BUFFER == ${NLCMD_TRIGGER}* ]] || return 1
  local q=${BUFFER#$NLCMD_TRIGGER}
  q=${q##[[:space:]]##}
  q=${q%%[[:space:]]##}
  (( $#q >= NLCMD_MIN_CHARS )) || return 1
  print -r -- "$q"
}

# --- Pintado (solo desde dentro de un widget) -------------------------------
_nlcmd_unpaint() {
  [[ -n $_NLCMD_HL ]] && region_highlight=(${region_highlight:#$_NLCMD_HL})
  _NLCMD_HL=
}

_nlcmd_render() {
  _nlcmd_log "render buf=[$BUFFER] post=[$1]"
  _nlcmd_unpaint
  POSTDISPLAY=$1
  if [[ -n $1 ]]; then
    _NLCMD_HL="$#BUFFER $(( $#BUFFER + $#POSTDISPLAY )) $2"
    region_highlight+=($_NLCMD_HL)
  fi
}
zle -N _nlcmd_render

# --- Descriptores en vuelo --------------------------------------------------
_nlcmd_close() {
  local name=$1 fd=${(P)1}
  [[ -n $fd ]] || return
  zle -F $fd 2>/dev/null
  exec {fd}<&- 2>/dev/null
  eval "$name="
}

_nlcmd_cancel() {
  _nlcmd_close _NLCMD_FD
  _nlcmd_close _NLCMD_VFD
  _NLCMD_SUGGESTION=
  _NLCMD_LAST_Q=
}

# --- Disparo (se llama desde widgets que modifican el buffer) ---------------
_nlcmd_after_modify() {
  local q
  if ! q=$(_nlcmd_query); then
    _nlcmd_cancel
    _nlcmd_render ''
    return
  fi

  # Ya tenemos calculada exactamente esta consulta: no repetir la petición.
  [[ -n $_NLCMD_SUGGESTION && $q == $_NLCMD_LAST_Q ]] && return

  (( _NLCMD_GEN++ ))
  _nlcmd_secure_dir $NLCMD_STATE_DIR || return
  print -r -- $_NLCMD_GEN > $NLCMD_STATE_DIR/gen

  _nlcmd_close _NLCMD_FD
  _nlcmd_close _NLCMD_VFD
  _NLCMD_SUGGESTION=
  _NLCMD_LAST_Q=
  _nlcmd_render "${NLCMD_HINT_PREFIX}…" $NLCMD_STYLE_PENDING

  _NLCMD_PENDING_Q=$q
  _nlcmd_log "fire gen=$_NLCMD_GEN q=[$q]"
  exec {_NLCMD_FD}< <( "$NLCMD_ROOT/bin/nlcmd-fetch" $_NLCMD_GEN "$q" 2>/dev/null )
  zle -F $_NLCMD_FD _nlcmd_on_result
}

# --- Respuesta del generador ------------------------------------------------
_nlcmd_on_result() {
  local fd=$1 event=${2:-} line
  zle -F $fd 2>/dev/null
  [[ $fd == $_NLCMD_FD ]] && _NLCMD_FD=

  if [[ -z $event || $event == hup ]]; then
    IFS= read -r -u $fd line 2>/dev/null
  fi
  exec {fd}<&- 2>/dev/null

  [[ -z $line ]] && return
  local gen=${line%%$'\t'*} payload=${line#*$'\t'}
  (( gen == _NLCMD_GEN )) || { _nlcmd_log "descartado gen=$gen actual=$_NLCMD_GEN"; return }

  if [[ $payload == '!'* ]]; then
    _NLCMD_SUGGESTION=
    zle _nlcmd_render -- "${NLCMD_HINT_PREFIX}${payload#!}" $NLCMD_STYLE_PENDING
    zle -R
    return
  fi

  _NLCMD_SUGGESTION=$payload
  _NLCMD_LAST_Q=$_NLCMD_PENDING_Q
  zle _nlcmd_render -- "${NLCMD_HINT_PREFIX}${payload}" $NLCMD_STYLE_READY
  zle -R
  _nlcmd_log "READY sug=[$payload]"

  # El comando ya se ve; la verificación viaja detrás sin bloquear nada.
  if [[ $NLCMD_VERIFY == 1 ]] && command -v node &>/dev/null; then
    exec {_NLCMD_VFD}< <( "$NLCMD_ROOT/bin/nlcmd-verify" $_NLCMD_GEN "$_NLCMD_LAST_Q" "$payload" 2>/dev/null )
    zle -F $_NLCMD_VFD _nlcmd_on_verdict
  fi
}

# --- Veredicto de Jev -------------------------------------------------------
_nlcmd_on_verdict() {
  local fd=$1 event=${2:-} line
  zle -F $fd 2>/dev/null
  [[ $fd == $_NLCMD_VFD ]] && _NLCMD_VFD=
  if [[ -z $event || $event == hup ]]; then
    IFS= read -r -u $fd line 2>/dev/null
  fi
  exec {fd}<&- 2>/dev/null

  [[ -z $line || -z $_NLCMD_SUGGESTION ]] && return
  local gen=${line%%$'\t'*} verdict=${line#*$'\t'}
  (( gen == _NLCMD_GEN )) || return
  _nlcmd_log "veredicto [$verdict]"

  [[ $verdict == danger* ]] || return
  zle _nlcmd_render -- "${NLCMD_HINT_PREFIX}⚠ ${_NLCMD_SUGGESTION}" $NLCMD_STYLE_DANGER
  zle -R
}

# --- Aceptar la sugerencia --------------------------------------------------
_nlcmd_accept() {
  if [[ -n $_NLCMD_SUGGESTION ]]; then
    BUFFER=$_NLCMD_SUGGESTION
    CURSOR=$#BUFFER
    _nlcmd_cancel
    _nlcmd_render ''
    return
  fi
  zle ${_NLCMD_ORIG_TAB:-expand-or-complete}
}
zle -N _nlcmd_accept

# --- Enter: limpia el fantasma antes de ejecutar ----------------------------
_nlcmd_accept_line() {
  _nlcmd_cancel
  _nlcmd_render ''
  zle .accept-line
}
zle -N accept-line _nlcmd_accept_line

# --- Envoltura de los widgets que modifican el buffer -----------------------
_nlcmd_wrap() {
  local w=$1 orig fn
  case ${widgets[$w]:-builtin} in
    user:*) orig=nlcmd-orig-$w; zle -N $orig ${widgets[$w]#user:} ;;
    *)      orig=.$w ;;
  esac
  fn=_nlcmd_w_${w//-/_}
  functions[$fn]="zle $orig; _nlcmd_after_modify"
  zle -N $w $fn
}

for _w in self-insert backward-delete-char delete-char backward-kill-word \
          kill-word kill-whole-line yank magic-space; do
  _nlcmd_wrap $_w
done
unset _w
