"""
Talks to a locally running Ollama server. Nothing leaves your machine.
Requires: `ollama serve` running, and OLLAMA_MODEL pulled/built
(`villager-ideas` by default -- see `ollama show villager-ideas
--modelfile`).
"""
import requests
import config


def generate(user_prompt, system_prompt=None):
    """`system_prompt` defaults to None deliberately: villager-ideas is a
    custom Modelfile-based model whose SYSTEM block already defines the
    full IN CHARACTER: / WISH: contract. Passing a competing system
    message here would override that baked-in prompt, so only pass one
    if you're pointing OLLAMA_MODEL at a plain base model instead."""
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": user_prompt})

    resp = requests.post(
        f"{config.OLLAMA_HOST}/api/chat",
        json={
            "model": config.OLLAMA_MODEL,
            "messages": messages,
            "stream": False,
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["message"]["content"]
