# FocusFlow

FocusFlow is a small Windows automation project that makes waiting for AI agents
less awkward:

1. Submit a prompt in Codex.
2. FocusFlow remembers the current window and pauses Spotify.
3. Chrome switches to an existing Instagram Reels tab.
4. When the AI response finishes, FocusFlow pauses Reels, restores the original
   window, and resumes Spotify.

I built this as an early portfolio project while learning software and AI
engineering. The interesting part was not just the idea—it was debugging
Windows focus restrictions, Chrome background-tab throttling, partial event-log
writes, and media state across multiple applications.

## Demo

Add a short screen recording here showing:

- Spotify playing
- a prompt being submitted
- Reels opening
- Codex returning when the response completes

## Features

- Supports the Codex desktop app and Codex CLI.
- Remembers and restores the original Windows window.
- Maximizes restored Codex/terminal and Chrome windows.
- Pauses and resumes the Spotify desktop app.
- Pauses Instagram Reels when returning to work.
- Restarts its local controller automatically if it becomes unhealthy.
- Runs locally and listens only on `127.0.0.1`.

## How it works

```text
Codex prompt/session event
        |
        v
Local Node.js controller
        |
        +--> Windows helper: remember window + control Spotify
        |
        +--> Chrome extension: select the existing Reels tab
        |
        v
Codex completion event
        |
        +--> pause Reels
        +--> restore/maximize original window
        +--> resume Spotify
```

The controller watches Codex's local JSONL session events for `user_message`
and `task_complete`. Official Codex lifecycle hooks are installed as an
additional event path.

## Requirements

- Windows 10 or 11
- Node.js
- PowerShell 7 or Windows PowerShell
- Google Chrome
- Spotify desktop app
- Codex desktop app or CLI

## Installation

Clone or download this repository, open PowerShell in the project directory,
and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

Then:

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Choose **Load unpacked**.
4. Select `%USERPROFILE%\.focus-flow\chrome-extension`.
5. Keep one Instagram Reels tab open.
6. Restart Codex.
7. If Codex asks you to trust the two FocusFlow hooks, review and approve them.

## Hermes and other agents

One-shot Hermes command:

```powershell
& "$HOME\.focus-flow\hermes-focus.ps1" "your prompt here"
```

Other agents can call:

```powershell
powershell.exe -NoProfile -File "$HOME\.focus-flow\event.ps1" start
powershell.exe -NoProfile -File "$HOME\.focus-flow\event.ps1" stop
```

## Privacy and security

- FocusFlow does not upload browsing history, prompts, files, or credentials.
- It reads appended event types from local Codex session files to detect when a
  prompt starts and finishes.
- Its HTTP controller is bound to the local machine only.
- Never commit your `.codex` directory, browser profile, authentication files,
  logs, or `window-state.json`.

## Current limitations

- Windows only.
- Expects one open Instagram Reels tab for predictable behavior.
- Instagram and Spotify UI changes may require selector updates.
- Desktop-app focus restrictions can vary between Windows configurations.
- The Spotify desktop restore command assumes Spotify was playing when the
  request began.

## What I learned

- Building event-driven desktop automation.
- Using Windows native APIs from PowerShell.
- Writing a Chrome Manifest V3 extension.
- Handling race conditions and partial JSONL writes.
- Adding health checks and self-recovery.
- Debugging behavior across several independent applications.

## AI assistance

This project was built with guidance and code assistance from OpenAI Codex. I
chose the problem, tested the behavior on my computer, reported failures, and
iterated on the design and fixes. I have documented the architecture so I can
continue learning from and maintaining it.

## License

[MIT](LICENSE)

