# Chatty

A dead simple native macOS chat app for [Claude Code](https://claude.com/claude-code). It's a thin SwiftUI front-end over the `claude` CLI — your messages stream back token-by-token, conversations keep their context, and replies render as real markdown.
No API key to manage: Chatty drives the `claude` binary you already have installed, so it uses your existing Claude Code auth.



<img width="1800" height="1416" alt="Screenshot 2026-06-24 at 11-19-59" src="https://github.com/user-attachments/assets/991944fc-ea36-4f14-b0a8-44ea9499b60a" />


## Features

- **Streaming responses** — text appears token-by-token via `claude --output-format stream-json`.
- **Multi-turn memory** — captures the `session_id` and passes `--resume`, so it's a real conversation, not one-shots.
- **Markdown rendering** — headings, lists, tables, code blocks, blockquotes (GitHub-flavored, via [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)).
- **Dark / light mode** — toggle in the header, remembered across launches.
- **Tools work** — web search, file reads, bash, etc. run in a configurable working directory.

## Install

One line — downloads the latest release, removes the Gatekeeper quarantine, and installs to `/Applications`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lubabs770/chatty/main/install.sh)"
```

Then launch it from Spotlight or `open -a Chatty`.


> [!WARNING]  
>**Security note:** `bypassPermissions` lets Claude run tools (including bash and file edits) inside `workingDirectory` with **no confirmation prompt** — there's no interactive approval in this UI, so anything stricter auto-denies tool calls mid-turn. Point `workingDirectory` at a scratch folder, or set `permissionMode` to `"default"` for conversation-only.

### Requirements

- macOS 13 (Ventura) or later. The release is a **universal** binary (Apple Silicon + Intel).
- [Claude Code](https://claude.com/claude-code) installed and authenticated — Chatty looks for `claude` at `~/.local/bin/claude`, `/opt/homebrew/bin/claude`, or `/usr/local/bin/claude`.

> The app is **unsigned**. The installer strips the quarantine attribute for you. If you download the `.zip` from the Releases page by hand instead, run `xattr -dr com.apple.quarantine /Applications/Chatty.app` once.

## Build from source

```sh
git clone https://github.com/lubabs770/chatty.git
cd chatty
./make-app.sh            # builds release + wraps it in Chatty.app
open Chatty.app
```

For day-to-day hacking, `./make-app.sh && open Chatty.app`. Use `UNIVERSAL=1 ./make-app.sh` for a universal (arm64 + x86_64) build — this needs full Xcode, not just the Command Line Tools. Don't use `swift run` — a bare SPM binary launches as a background process and never takes keyboard focus; the `.app` bundle is what makes it a real, focusable app.

Releases are built automatically: pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which builds the universal bundle on a macOS runner and publishes it to GitHub Releases.

## Configuration

A few constants at the top of `Sources/Chatty/ChatViewModel.swift`:

| Constant | Default | What it does |
|---|---|---|
| `workingDirectory` | `$HOME` | Directory Claude runs in — what it can see and edit. |
| `permissionMode` | `bypassPermissions` | Tool-use policy. |


## why?
I started chatting with claude via claude code, I wanted my chat history to "obsidianize" - claude code history lives on your own machine as opposed to web


## How it works

```
SwiftUI UI  ──►  Process: claude -p <prompt> --output-format stream-json
                          --include-partial-messages --resume <session>
            ◄──  JSONL stream, parsed line-by-line, text deltas appended live
```

The pipe is drained with an async byte sequence (not `readDataToEndOfFile` after `waitUntilExit`, which deadlocks once output exceeds the ~64KB pipe buffer), so the UI stays responsive and large replies never hang.

## License

MIT
