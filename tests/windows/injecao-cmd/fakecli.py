import json, os, sys
# CLI falso: registra argumentos e stdin no log e termina com sucesso.
data = sys.stdin.read() if not sys.stdin.isatty() else ""
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "calls.log"), "a", encoding="utf-8") as f:
    f.write(json.dumps({"via": "python", "argv": sys.argv[1:], "stdin": data}, ensure_ascii=False) + "\n")
