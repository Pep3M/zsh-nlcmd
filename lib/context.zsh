# lib/context.zsh — recolecta el contexto que acompaña a la petición.
# Todo lo de aquí viaja a un tercero: añadir campos con criterio.

nlcmd_context() {
  local -a parts
  parts+=("os: $(uname -s) $(uname -r)")
  parts+=("shell: zsh ${ZSH_VERSION:-?}")

  if [[ $NLCMD_SEND_CWD == 1 ]]; then
    # ~ en lugar de la ruta absoluta: no filtra el nombre de usuario.
    parts+=("cwd: ${PWD/#$HOME/~}")
  fi

  if [[ $NLCMD_SEND_GIT == 1 ]] && command git rev-parse --is-inside-work-tree &>/dev/null; then
    local branch dirty
    branch=$(command git symbolic-ref --short -q HEAD 2>/dev/null) || branch='(detached)'
    dirty=$(command git status --porcelain 2>/dev/null | head -1)
    parts+=("git: rama $branch${dirty:+, con cambios sin confirmar}")
  fi

  if [[ $NLCMD_SEND_TOOLS == 1 ]]; then
    local -a found
    local t
    for t in docker kubectl git rg fd jq brew npm pnpm cargo go python3 terraform aws gcloud; do
      command -v $t &>/dev/null && found+=$t
    done
    (( $#found )) && parts+=("herramientas: ${(j:, :)found}")
  fi

  if [[ $NLCMD_SEND_LS == 1 ]]; then
    local entries
    entries=$(command ls -A 2>/dev/null | head -40 | tr '\n' ' ')
    [[ -n $entries ]] && parts+=("ficheros: $entries")
  fi

  # Nombres de rama y rutas son texto que no controlamos y que acaba dentro del
  # prompt del modelo: se les quitan los caracteres de control.
  print -r -- "${${(F)parts}//[[:cntrl:]]/ }"
}
