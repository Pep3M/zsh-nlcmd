#!/usr/bin/env python3
# Servidor falso con la forma de /v1/chat/completions, para probar el plugin
# sin gastar peticiones reales. Devuelve a propósito un comando envuelto en
# fences y con prefijo "$", que es lo que suelen hacer los modelos de verdad.
import json, http.server, itertools, os
n = itertools.count(1)
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        i = next(n)
        open(os.environ.get('NLCMD_TEST_HITS', '/tmp/nlcmd_hits'), 'a').write(f"{i}\n")
        content = "```bash\n$ lsof -iTCP -sTCP:LISTEN -n -P\n```"
        out = json.dumps({"choices":[{"message":{"content":content}}]}).encode()
        self.send_response(200); self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self,*a): pass
http.server.HTTPServer(('127.0.0.1',8731), H).serve_forever()
