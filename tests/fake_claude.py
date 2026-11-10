#!/usr/bin/env python3
"""Simula `claude -p --input-format stream-json --output-format stream-json` para os testes.

Não faz chamadas de rede. Registra argumentos e entradas em PRAGUS_TEST_RPC_LOG e grava
sessões em CLAUDE_CONFIG_DIR/projects como o Claude Code faz.
"""
import json
import os
import re
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
    return args[args.index(name) + 1] if name in args else None


def session_file(session):
    root = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
    folder = os.path.join(root, "projects", re.sub(r"[^A-Za-z0-9]", "-", os.getcwd()))
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, session + ".jsonl")


def record(session, entry):
    entry.update({"sessionId": session, "cwd": os.getcwd(), "entrypoint": "sdk-cli", "uuid": str(uuid.uuid4())})
    with open(session_file(session), "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def initialize(request_id):
    account = {} if os.environ.get("PRAGUS_FAKE_LOGGED_OUT") else {"email": "teste@example.invalid", "subscriptionType": "Claude Pro"}
    emit({"type": "control_response", "response": {"subtype": "success", "request_id": request_id, "response": {
        "models": [
            {"value": "default", "displayName": "Default", "supportsEffort": True, "supportedEffortLevels": ["low", "high"]},
            {"value": "sonnet", "displayName": "Sonnet", "supportsEffort": True, "supportedEffortLevels": ["low", "medium", "high"]},
            {"value": "haiku", "displayName": "Haiku"},
        ],
        "account": account,
    }}})


def answer(session, content, lines):
    # A pergunta é o primeiro texto que não seja histórico importado (anexos vêm depois).
    texts = [block.get("text", "") for block in content
             if block.get("type") == "text" and not block.get("text", "").startswith("Histórico anterior importado")]
    question = texts[0] if texts else ""
    record(session, {"type": "user", "message": {"role": "user", "content": content}})
    message_id = "msg_" + uuid.uuid4().hex[:8]
    emit({"type": "stream_event", "event": {"type": "message_start", "message": {"id": message_id}}})
    emit({"type": "stream_event", "event": {"type": "content_block_start", "content_block": {"type": "text", "text": ""}}})
    if "demorado" in question:
        emit({"type": "stream_event", "event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "Parcial"}}})
        for line in lines:
            request = json.loads(line)
            log({"stdin": request})
            if request.get("type") == "control_request" and request["request"].get("subtype") == "interrupt":
                emit({"type": "result", "subtype": "error_during_execution", "is_error": True, "session_id": session})
                return
        return
    if "falhe" in question:
        emit({"type": "result", "subtype": "error_during_execution", "is_error": True, "errors": ["Falha simulada"], "session_id": session})
        return
    reply = "Resposta: " + question
    for piece in (reply[: len(reply) // 2], reply[len(reply) // 2:]):
        emit({"type": "stream_event", "event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": piece}}})
    emit({"type": "assistant", "message": {"id": message_id, "role": "assistant", "content": [{"type": "text", "text": reply}]}, "session_id": session})
    record(session, {"type": "assistant", "message": {"id": message_id, "role": "assistant", "model": "fake", "content": [{"type": "text", "text": reply}]}})
    emit({"type": "rate_limit_event", "rate_limit_info": {"status": "allowed", "unifiedWindows": {
        "five_hour": {"utilization": 0.25, "resetsAt": 4102444800},
        "seven_day": {"utilization": 0.5, "resetsAt": 4102444800}}}})
    emit({"type": "result", "subtype": "success", "is_error": False, "result": reply, "session_id": session})


def main():
    log({"argv": sys.argv[1:], "cwd": os.getcwd()})
    session = option("--resume") or str(uuid.uuid4())
    if option("--resume") and not os.path.exists(session_file(session)):
        print("No conversation found with session ID: " + session, file=sys.stderr)
        return 1
    lines = iter(sys.stdin.readline, "")
    for line in lines:
        if not line.strip():
            continue
        message = json.loads(line)
        log({"stdin": message})
        if message.get("type") == "control_request" and message["request"].get("subtype") == "initialize":
            initialize(message["request_id"])
        elif message.get("type") == "control_request" and message["request"].get("subtype") == "get_usage":
            emit({"type": "control_response", "response": {"subtype": "success", "request_id": message["request_id"], "response": {
                "rate_limits_available": True, "rate_limits": {
                    "five_hour": {"utilization": 25, "resets_at": "2100-01-01T00:00:00.000000+00:00"},
                    "seven_day": {"utilization": 50, "resets_at": "2100-01-01T00:00:00.000000+00:00"}}}}})
        elif message.get("type") == "user":
            emit({"type": "system", "subtype": "init", "session_id": session, "cwd": os.getcwd()})
            answer(session, message["message"]["content"], lines)
    return 0


if __name__ == "__main__":
    sys.exit(main())
