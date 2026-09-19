# lib/config.zsh — valores por defecto. Sobreescribibles desde .zshrc
# declarando la variable ANTES de cargar el plugin.

# --- Proveedor -------------------------------------------------------------
: ${NLCMD_BASE_URL:=https://ai-gateway.vercel.sh/v1}
: ${NLCMD_MODEL:=openai/gpt-5.4-mini}
: ${NLCMD_API_KEY_VAR:=AI_GATEWAY_API_KEY}

# --- Disparo ---------------------------------------------------------------
# Carácter comodín. '#' es un comentario de shell: si la petición falla o
# pulsas Enter por accidente, no se ejecuta nada.
: ${NLCMD_TRIGGER:=#}
# Caracteres mínimos tras el comodín antes de gastar una petición.
: ${NLCMD_MIN_CHARS:=6}
# Debounce en segundos. Decimal admitido (GNU/BSD sleep aceptan fracciones).
: ${NLCMD_DEBOUNCE:=0.35}
# Timeout duro de la petición.
: ${NLCMD_TIMEOUT:=8}

# --- Contexto que se envía -------------------------------------------------
# El historial NO se envía nunca: suele contener tokens y contraseñas.
: ${NLCMD_SEND_CWD:=1}
: ${NLCMD_SEND_GIT:=1}
: ${NLCMD_SEND_TOOLS:=1}
: ${NLCMD_SEND_LS:=0}

# --- Verificación con Jev (opcional) ---------------------------------------
: ${NLCMD_VERIFY:=0}
: ${NLCMD_VERIFY_MODEL:=typesafe-ai/jev}
# Probabilidad a partir de la cual el comando se pinta como peligroso.
: ${NLCMD_DANGER_THRESHOLD:=0.5}

# --- Apariencia ------------------------------------------------------------
: ${NLCMD_HINT_PREFIX:=$'  ⟶ '}
: ${NLCMD_STYLE_PENDING:=fg=8}
: ${NLCMD_STYLE_READY:=fg=6}
: ${NLCMD_STYLE_DANGER:=fg=1,bold}

# --- Estado en disco -------------------------------------------------------
: ${NLCMD_STATE_DIR:=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/zsh-nlcmd-$UID}
: ${NLCMD_CACHE_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-nlcmd}
