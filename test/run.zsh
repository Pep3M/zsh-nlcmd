#!/usr/bin/env zsh
# test/run.zsh — batería de aceptación.
#
# Arranca un zsh interactivo dentro de un pseudo-terminal, teclea en él como
# lo haría una persona y comprueba lo que aparece en pantalla. Es la única
# forma honesta de probar widgets de ZLE: sin un pty no hay redibujado.
#
#   ./test/run.zsh
#
# No consume peticiones reales: usa test/mock-server.py.

emulate -L zsh
setopt err_return
zmodload zsh/zpty

local root=${0:A:h:h}
local tmp=${TMPDIR:-/tmp}/nlcmd-test-$$
mkdir -p $tmp/zdot
trap "rm -rf $tmp; kill %1 2>/dev/null" EXIT

export NLCMD_TEST_HITS=$tmp/hits
python3 $root/test/mock-server.py &
sleep 1

cat > $tmp/zdot/.zshrc <<ZRC
autoload -Uz compinit; compinit -u -d $tmp/zcompdump
PROMPT='PS> '; RPROMPT=''
export AI_GATEWAY_API_KEY=clave-falsa
export NLCMD_BASE_URL=http://127.0.0.1:8731/v1
export NLCMD_DEBOUNCE=0.35
export NLCMD_MIN_CHARS=6
export NLCMD_CACHE_DIR=$tmp/cache
export NLCMD_STATE_DIR=$tmp/state
export NLCMD_DEBUG=$tmp/debug.log
source $root/zsh-nlcmd.plugin.zsh
ZRC

integer fallos=0
local chunk acc=''
drain() { integer n=0; while (( n++ < 600 )); do zpty -r -t Z chunk 2>/dev/null || break; acc+=$chunk; done }
strip() { print -r -- "$1" | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' | tr -d '\r' }
type_() { local s=$1 j; for (( j=1; j<=$#s; j++ )); do zpty -w -n Z "$s[j]"; sleep 0.08; drain; done }
wait_() { integer k=0; while (( k++ < ${2:-60} )); do sleep 0.1; drain; [[ $(strip "$acc") == *$1* ]] && return 0; done; return 1 }
ok()    { if [[ $1 == 0 ]]; then print "  ✓ $2"; else print "  ✗ $2"; (( fallos++ )); fi }

zpty Z "ZDOTDIR=$tmp/zdot zsh -i"
sleep 2; drain; acc=''

print "ghost text"
type_ '# listar los puertos que estan escuchando'
wait_ 'lsof -iTCP'
local clean=$(strip "$acc")
[[ $clean == *'lsof -iTCP -sTCP:LISTEN -n -P'* ]]; ok $? "la sugerencia aparece junto al buffer"
[[ $acc == *$'\e[36m'* ]];                         ok $? "se pinta con el estilo READY"
[[ $(grep -o 'buf=\[[^]]*\]' $tmp/debug.log | tail -1) == 'buf=[# listar los puertos que estan escuchando]' ]]
ok $? "el buffer del usuario queda intacto"

print "aceptación"
acc=''; zpty -w -n Z $'\t'; sleep 0.4; drain
[[ $(strip "$acc") == *'lsof -iTCP -sTCP:LISTEN -n -P'* ]]; ok $? "Tab sustituye el buffer por el comando"
acc=''; zpty -w -n Z $'\n'; wait_ 'COMMAND' 40
[[ $(strip "$acc") == *COMMAND* ]];                         ok $? "Enter ejecuta el comando aceptado"

print "seguridad"
acc=''; type_ '# elimina todos los ficheros del sistema'; sleep 0.8; drain
acc=''; zpty -w -n Z $'\n'; integer k=0; while (( k++ < 25 )); do sleep 0.12; drain; done
clean=$(strip "$acc")
[[ $clean != *'command not found'* && $clean != *'rm:'* ]]; ok $? "Enter sin aceptar no ejecuta nada (es un comentario)"

print "convivencia"
acc=''; type_ 'ls -la'; sleep 0.5; drain
[[ $(strip "$acc") != *'⟶'* ]];        ok $? "sin el comodín no aparece nada"
acc=''; zpty -w -n Z $'\n'; wait_ 'total' 30
[[ $(strip "$acc") == *total* ]];      ok $? "un comando normal se ejecuta igual"
acc=''; type_ 'ec'; zpty -w -n Z $'\t'; k=0; while (( k++ < 30 )); do sleep 0.15; drain; done
[[ $(strip "$acc") == *ech* ]];        ok $? "Tab conserva el completado nativo de zsh"

print "economía"
integer pulsaciones=$(grep -c 'fire gen=' $tmp/debug.log)
integer peticiones=$(wc -l < $tmp/hits | tr -d ' ')
(( peticiones <= 4 )); ok $? "debounce: $pulsaciones pulsaciones → $peticiones peticiones HTTP"

zpty -d Z
print ""
if (( fallos )); then print "$fallos fallo(s)"; return 1; else print "todo correcto"; fi
