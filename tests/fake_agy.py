#!/usr/bin/env python3
"""Simula `agy` (Antigravity CLI) para os testes automatizados sem chamadas de rede."""
import json
import os
import sys
import uuid

LOG = os.environ.get("PRAGUS_TEST_RPC_LOG")


def log(entry):
    if LOG:
        with open(LOG, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args and args.index(name) + 1 < len(args) else None


def agy_root():
    return os.environ.get("ANTIGRAVITY_CONFIG_DIR", os.path.expanduser("~/.gemini/antigravity-cli"))


def session_file(session):
    folder = os.path.join(agy_root(), "brain", session, ".system_generated", "logs")
    os.makedirs(folder, exist_ok=True)
    conv_dir = os.path.join(agy_root(), "conversations")
    os.makedirs(conv_dir, exist_ok=True)
    with open(os.path.join(conv_dir, session + ".pb"), "wb") as f:
        f.write(b"fake")
    return os.path.join(folder, "transcript.jsonl")


def record(session, entry):
    with open(session_file(session), "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def main():
    args = sys.argv[1:]
    log({"agy_argv": args, "cwd": os.getcwd()})

    if args == ["models"]:
        if os.environ.get("PRAGUS_FAKE_LOGGED_OUT"):
            print("Error: not logged in. Run agy auth login", file=sys.stderr)
            return 1
        print(
            "Available models:\n"
            "  gemini-4-argon-high *            Gemini 4 Argon (High)\n"
            "  gemini-4-argon-low               Gemini 4 Argon (Low)\n"
            "  gemini-4-argon-medium            Gemini 4 Argon (Medium)\n"
            "  gemini-3.8-flash-high            Gemini 3.8 Flash (High)\n"
            "  gemini-3.8-flash-low             Gemini 3.8 Flash (Low)\n"
            "  gemini-3.8-flash-medium          Gemini 3.8 Flash (Medium)\n"
            "  claude-sonnet-5-5                Claude Sonnet 5.5\n"
            "  gpt-oss-120b-medium              GPT-OSS 120B (Medium)\n"
        )
        return 0

    if "-p=/usage" in args:
        emit({
            "status": "SUCCESS",
            "command": {
                "name": "usage",
                "data": {
                    "groups": [
                        {
                            "name": "Gemini Models",
                            "buckets": [
                                {"window": "5h", "remaining_fraction": 0.9, "reset_time": "2100-01-01T00:00:00Z"},
                                {"window": "weekly", "remaining_fraction": 0.8, "reset_time": "2100-01-01T00:00:00Z"},
                            ],
                        },
                        {
                            "name": "Claude and GPT models",
                            "buckets": [
                                {"window": "5h", "remaining_fraction": 0.6, "reset_time": "2100-01-01T00:00:00Z"},
                                {"window": "weekly", "remaining_fraction": 0.5, "reset_time": "2100-01-01T00:00:00Z"},
                            ],
                        },
                        {
                            "name": "Gemini 4 Argon",
                            "buckets": [
                                {"window": "5h", "remaining_fraction": 0.85, "reset_time": "2100-01-01T00:00:00Z"},
                                {"window": "weekly", "remaining_fraction": 0.75, "reset_time": "2100-01-01T00:00:00Z"},
                            ],
                        },
                    ]
                },
            },
        })
        return 0

    session = option("--conversation") or str(uuid.uuid4())
    for line in sys.stdin:
        if not line.strip():
            continue
        msg = json.loads(line)
        log({"agy_stdin": msg})
        if msg.get("event") != "user":
            continue
        content = msg.get("message", {}).get("content", [])
        texts = [
            b.get("text", "")
            for b in content
            if b.get("type") == "text"
            and not b.get("text", "").startswith("[Instruções de contexto:")
            and not b.get("text", "").startswith("Histórico anterior importado")
            and not b.get("text", "").startswith("Arquivo anexado pelo usuário")
            and not b.get("text", "").startswith("Imagem anexada pelo usuário")
        ]
        question = texts[0] if texts else ""
        full_user = "\n\n".join(b.get("text", "") for b in content if b.get("type") == "text")
        record(session, {"step_index": 0, "type": "USER_INPUT", "status": "DONE", "content": f"<USER_REQUEST>\n{full_user}\n</USER_REQUEST>"})
        emit({"event": "init", "conversation_id": session, "init": {"cwd": os.getcwd(), "model": option("--model") or "gemini-4-argon"}})
        if "falhe" in question:
            emit({"event": "result", "conversation_id": session, "result": {"status": "ERROR", "error": "Falha simulada no Antigravity"}})
            return 0
        reply = "Antigravity: " + question
        emit({"event": "step_update", "conversation_id": session, "step_update": {"step_index": 1, "step_type": "thinking", "thinking_delta": "pensando..."}})
        emit({"event": "step_update", "conversation_id": session, "step_update": {"step_index": 1, "step_type": "planner_response", "text_delta": reply}})
        record(session, {"step_index": 1, "type": "PLANNER_RESPONSE", "status": "DONE", "content": reply})
        emit({"event": "result", "conversation_id": session, "result": {"status": "SUCCESS", "response": reply}})
    return 0


if __name__ == "__main__":
    sys.exit(main())
