# zsh-nlcmd

Escribe lo que quieres hacer. Acepta el comando con `Tab`.

```
PS> # listar los puertos que estan escuchando  ⟶ lsof -iTCP -sTCP:LISTEN -n -P
                                              └─ Tab lo escribe en el buffer
```

La sugerencia aparece atenuada a la derecha mientras escribes, sin bloquear el
prompt. **Nunca se ejecuta sola**: `Tab` la escribe en la línea y el `Enter`
siempre lo das tú.

---

## Por qué el comodín es `#`

Porque es un comentario de shell. Si la petición falla, si te distraes o si
pulsas `Enter` sin aceptar, la línea es inerte: no se ejecuta nada. El plugin
activa `interactive_comments` precisamente para garantizar esa propiedad.

Ningún otro carácter disponible tiene ese comportamiento de red de seguridad.

## Instalación

Necesitas `zsh`, `curl` y `jq`.

**Con gestor de plugins**

```zsh
# zinit
zinit light USUARIO/zsh-nlcmd

# antidote  (.zsh_plugins.txt)
USUARIO/zsh-nlcmd

# oh-my-zsh
git clone https://github.com/USUARIO/zsh-nlcmd \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-nlcmd
# y añade zsh-nlcmd a plugins=(...)
```

**Sin gestor de plugins**

```zsh
git clone https://github.com/USUARIO/zsh-nlcmd
./zsh-nlcmd/install.sh
```

**La clave (cada usuario la suya)**

El plugin no incluye ninguna credencial ni pasa por ningún servidor
intermediario: cada instalación habla directamente con el proveedor usando la
clave de quien la instala.

```zsh
export AI_GATEWAY_API_KEY='...'   # https://vercel.com/docs/ai-gateway
```

Comprueba que todo está en su sitio:

```zsh
nlcmd doctor
```

## Configuración

Declara las variables **antes** de cargar el plugin.

| Variable | Por defecto | Para qué |
|---|---|---|
| `NLCMD_MODEL` | `openai/gpt-5.4-mini` | Modelo generador |
| `NLCMD_BASE_URL` | `https://ai-gateway.vercel.sh/v1` | Endpoint compatible con OpenAI |
| `NLCMD_API_KEY_VAR` | `AI_GATEWAY_API_KEY` | Nombre de la variable con la clave |
| `NLCMD_TRIGGER` | `#` | Carácter comodín |
| `NLCMD_MIN_CHARS` | `6` | Caracteres mínimos antes de gastar una petición |
| `NLCMD_DEBOUNCE` | `0.35` | Segundos de espera tras la última pulsación |
| `NLCMD_TIMEOUT` | `8` | Timeout de la petición |
| `NLCMD_VERIFY` | `0` | Verificación con Jev (ver abajo) |

Nada está fijado en el código: el endpoint y el modelo son configurables porque
la oferta de modelos baratos cambia cada pocos meses.

**Teclas.** `Tab` acepta la sugerencia; si no hay ninguna, sigue siendo el
completado normal de zsh. `Ctrl+Espacio` es una alternativa explícita.

## Qué se envía

Solo esto, y cada pieza se puede desactivar:

- sistema operativo y versión de zsh
- directorio actual, con `$HOME` sustituido por `~`
- rama de git y si hay cambios sin confirmar (`NLCMD_SEND_GIT=0`)
- qué herramientas conocidas existen en el `PATH` (`NLCMD_SEND_TOOLS=0`)
- el listado de ficheros solo si lo pides (`NLCMD_SEND_LS=1`)

**El historial de comandos no se envía nunca**, ni hay opción para hacerlo: es
donde acaban los tokens y las contraseñas pegadas por error.

`nlcmd doctor` te imprime exactamente lo que saldría de tu máquina.

## Verificación con Jev (opcional)

[Jev](https://vercel.com/ai-gateway/models/jev), de TypeSafe AI, es un modelo de
decisión: no genera texto, responde preguntas tipadas (`boolean`, `choice`,
`score`) con su probabilidad. No puede traducir lenguaje natural a un comando
—el espacio de salida es cerrado y hay que declararlo de antemano—, pero sí es
bueno juzgando un comando ya generado.

Activado, después de mostrar la sugerencia se le pregunta en paralelo si el
comando es destructivo y si de verdad resuelve lo pedido. Si el veredicto es
malo, el texto se repinta en rojo con `⚠` antes de que pulses nada. Distingue
`rm -rf ./build` de `rm -rf ~/`, cosa que una lista negra de expresiones
regulares no hace.

```zsh
export NLCMD_VERIFY=1
cd ~/.local/share/zsh-nlcmd/verify && npm install
```

Requiere Node, porque **Jev solo es accesible a través del AI SDK**: la
documentación de Vercel dice explícitamente que la evaluación *«no está
soportada por los endpoints compatibles con OpenAI, Anthropic ni Cohere»*, así
que con `curl` no se puede. Esa es la única parte del proyecto que no es shell,
y por eso es opcional y va fuera del camino crítico: la sugerencia se muestra
primero y el veredicto llega después.

## Cómo funciona

```
pulsación
   └─ widget ZLE ──> generación++ ──> worker en segundo plano
                                         │
                                         ├─ duerme el debounce
                                         ├─ ¿mi generación sigue siendo la actual?
                                         │     no ──> muere sin gastar nada
                                         └─ curl ──> comando
                                                      │
              POSTDISPLAY <── widget de pintado <── zle -F (fd no bloqueante)
```

El debounce vive **dentro** del worker, no en el widget: cada pulsación lanza un
proceso que duerme y se suicida si ya no es el último. Así el prompt nunca se
bloquea y solo la última pulsación llega a la red. Medido con el banco de
pruebas: **67 pulsaciones → 2 peticiones HTTP**.

Hay además una caché en disco por (modelo, directorio, consulta), así que
repetir una petición no cuesta nada.

### Dos trampas de ZLE, por si tocas el código

1. **Un manejador `zle -F` no es un widget.** Dentro de él `BUFFER`, `CURSOR` y
   `POSTDISPLAY` están vacíos. Por eso la consulta de cada generación se guarda
   al dispararla en vez de releerse del buffer al recibir la respuesta.
2. **Para pintar desde un `zle -F` hacen falta las dos cosas**: invocar un
   widget registrado con `zle -N` *y* llamar a `zle -R` después. El widget solo
   no repinta; asignar `POSTDISPLAY` directamente y llamar a `zle -R`, tampoco.

## Pruebas

```zsh
./test/run.zsh
```

Levanta un zsh interactivo dentro de un pseudo-terminal, teclea en él a ritmo
humano y comprueba lo que aparece en pantalla. No gasta peticiones reales: usa
`test/mock-server.py`. Es la única forma honesta de probar widgets de ZLE.

Para depurar en vivo, `export NLCMD_DEBUG=/tmp/nlcmd.log` y míralo desde otra
terminal con `tail -f`.

## Limitaciones conocidas

- **Solo zsh.** ZLE es el único entorno donde el ghost text funciona bien; bash
  con readline no tiene equivalente.
- **Convivencia con `zsh-syntax-highlighting`.** Ambos escriben en
  `region_highlight`. El plugin retira su propia marca en vez de sobrescribir el
  array, pero si notas parpadeos, carga `zsh-nlcmd` *antes* del resaltador.
- **Un comando por petición.** Nada de flujos de varios pasos.
- **El modelo se equivoca.** De ahí que no se ejecute nada solo, nunca.

## Licencia

MIT.
