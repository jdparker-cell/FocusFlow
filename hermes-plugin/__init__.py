"""Hermes Agent lifecycle bridge for FocusFlow."""

from __future__ import annotations

import urllib.request


BASE_URL = "http://127.0.0.1:38473/event"


def _send(action: str) -> None:
    request = urllib.request.Request(
        f"{BASE_URL}/{action}",
        data=b"",
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=2) as response:
            response.read()
    except Exception:
        # FocusFlow is optional automation. It must never break a Hermes turn.
        pass


def _start_focusflow(**kwargs):
    del kwargs
    _send("start")
    return None


def _stop_focusflow(**kwargs):
    del kwargs
    _send("stop")
    return None


def register(ctx):
    ctx.register_hook("pre_llm_call", _start_focusflow)
    ctx.register_hook("post_llm_call", _stop_focusflow)
    ctx.register_hook("on_session_finalize", _stop_focusflow)

