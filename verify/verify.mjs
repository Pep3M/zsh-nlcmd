// verify/verify.mjs — verificación semántica del comando generado con Jev.
//
// Jev solo es accesible vía AI SDK 7+ (no hay endpoint REST: la documentación
// de Vercel lo dice explícitamente), de ahí que esta pieza sea Node y no curl.
//
// Entrada  (stdin): dos líneas — la intención y el comando propuesto. Van por
//                   stdin y no por argv porque argv lo puede leer cualquier
//                   usuario de la máquina con `ps`.
// Salida  (stdout): "danger <prob>" | "ok <prob>" | "skip <motivo>"

import { experimental_evaluate as evaluate } from 'ai';
import { readFileSync } from 'node:fs';

const [intent, command] = readFileSync(0, 'utf8').split('\n');

if (!intent || !command) {
  process.stdout.write('skip faltan argumentos\n');
  process.exit(0);
}

const model = process.env.NLCMD_VERIFY_MODEL || 'typesafe-ai/jev';
const threshold = Number(process.env.NLCMD_DANGER_THRESHOLD ?? 0.5);

try {
  const { answers } = await evaluate({
    model,
    state: {
      intencion_del_usuario: intent,
      comando_propuesto: command,
      directorio: process.env.PWD,
    },
    questions: {
      destructivo: {
        type: 'boolean',
        instructions:
          'El comando propuesto, ¿provoca pérdida de datos irreversible, ' +
          'afecta a recursos fuera del directorio de trabajo, o altera el ' +
          'sistema de forma difícil de revertir?',
        criteria: {
          true: 'borra, sobrescribe o trunca datos; toca $HOME, / o rutas del sistema; ' +
                'opera sobre infraestructura remota; fuerza con -f o --force; descarga y ejecuta',
          false: 'solo lee, lista o inspecciona; o escribe únicamente dentro del ' +
                 'directorio de trabajo de forma reversible',
        },
      },
      resuelve: {
        type: 'boolean',
        instructions:
          '¿El comando propuesto hace realmente lo que pide la intención del usuario?',
      },
    },
  });

  const danger = answers.destructivo.probability;
  const solves = answers.resuelve.probability;

  // Un comando que no resuelve la petición y además toca cosas es el peor caso.
  if (danger >= threshold || solves < 0.35) {
    process.stdout.write(`danger ${danger.toFixed(2)}\n`);
  } else {
    process.stdout.write(`ok ${danger.toFixed(2)}\n`);
  }
} catch (err) {
  process.stdout.write(`skip ${String(err.message).slice(0, 80)}\n`);
}
