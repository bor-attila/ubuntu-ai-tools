# ubuntu-ai-tools

A token-efficient CLI tool set for AI agents (Ubuntu). `tools.sh` installs the
tools and wires an AI instruction file into your user-level `~/.claude/CLAUDE.md`
so the AI calls ready-made tools instead of writing ad-hoc scripts. `cakephp.sh`
optionally adds CakePHP 5.x conventions for CakePHP projects.

## Files

| File | Purpose |
|------|---------|
| `tools.sh` | Installs the CLI tools and wires `ubuntu-ai-tools.md` |
| `cakephp.sh` | Installs and conditionally wires `CAKEPHP.md` |
| `ubuntu-ai-tools.md` | AI instruction file (task→tool mapping, rules) |
| `CAKEPHP.md` | CakePHP 5.x conventions (loaded only for CakePHP projects) |

## Install

```bash
./tools.sh      # CLI tools + ubuntu-ai-tools.md wiring
./cakephp.sh    # optional: CakePHP 5.x instructions (only for CakePHP work)
```

Both are re-runnable (idempotent) and manage their own marker block in
`~/.claude/CLAUDE.md`, so they don't interfere with each other.

`tools.sh` strategy: `apt` → `snap` → GitHub release binary/.deb.
`~/.local/bin` is added to PATH automatically; afterwards open a new terminal or
run `exec $SHELL`.

## What it installs

- **Required:** jq, yq, ripgrep, fd, bat, tldr, websocat, xclip, ccache, curl
- **Media:** ffmpeg, imagemagick, exiftool, gifsicle, optipng/pngquant/jpegoptim,
  webp, poppler-utils, ghostscript, tesseract-ocr, yt-dlp, pandoc
- **Modern CLI:** fzf, eza, zoxide, duf, dust, ncdu, hyperfine, aria2, parallel,
  sqlite3, tree, btop, entr, tig, httpie, gron, delta, sd, jless, glow, moreutils
- **Database clients:** psql (postgres), mysql/mariadb, sqlcmd (mssql), sqlite3,
  mongosh (mongo), and usql (universal client for all of them)

## AI wiring

`ubuntu-ai-tools.md` is copied into `~/.claude/`, and a marker block references
it from `~/.claude/CLAUDE.md` (`@ubuntu-ai-tools.md`). Re-running refreshes the
block without duplicating it.

`cakephp.sh` copies `CAKEPHP.md` (CakePHP 5.x conventions) into `~/.claude/` and
adds a separate marker block that references it **conditionally** — the AI reads
it only when `composer.json` requires `cakephp/cakephp`, so it is never loaded for
other projects. Skip this script if you don't work with CakePHP.

### Why CakePHP for AI-assisted development

CakePHP is included because its design happens to play to an LLM's strengths:

- **Convention over configuration.** Strict, predictable naming (table →
  model → controller → template) lets the AI infer the structure of code it
  hasn't seen instead of reading config to discover it. Less context to load,
  fewer wrong guesses.
- **Deterministic scaffolding.** `bin/cake bake` generates convention-compliant
  controllers, entities, and templates. The AI can drive a reliable generator
  rather than hand-writing boilerplate it might get subtly wrong.
- **Stable, versioned documentation.** A single source of truth
  ([book.cakephp.org/5.x](https://book.cakephp.org/5.x/),
  [api.cakephp.org/5.x](https://api.cakephp.org/5.x/)) gives the model accurate
  grounding and clear migration guides for deprecated APIs.
- **Explicit ORM.** The query builder is consistent and readable, with little
  hidden "magic," so generated queries are easier to verify and less likely to
  rely on behavior the model only half-remembers.

The net effect: more of the framework's behavior is *predictable from
convention*, which is exactly what reduces hallucination and rework in
AI-generated code. This is a pragmatic fit for this setup, not a claim that
CakePHP beats every framework for every team.

## Verify

```bash
for t in jq yq rg fd batcat tldr websocat xclip ccache curl \
         ffmpeg convert yt-dlp fzf delta sd \
         psql mysql sqlite3 sqlcmd mongosh usql; do
  command -v "$t" >/dev/null && echo "OK   $t" || echo "MISS $t"
done
```

Check the CLAUDE.md wiring (each block should appear exactly once):

```bash
rg -n 'ubuntu-ai-tools' ~/.claude/CLAUDE.md
```
