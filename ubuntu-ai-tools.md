# AI CLI TOOL USAGE (ubuntu-ai-tools)

**Core principle:** A fast, deterministic CLI tool set is installed on this
system. USE these instead of writing ad-hoc scripts/custom logic. Always filter
**locally** before data enters the context — ask for limited, flag-constrained
output.

## Task → tool

| Task | Tool | Typical call |
|---|---|---|
| JSON filter/transform | `jq` | `jq '.items[].name' f.json` |
| YAML filter (Go yq) | `yq` | `yq '.services.web.image' c.yml` |
| YAML→JSON | `yq` | `yq -o=json '.' c.yml` |
| Text/regex search | `rg` | `rg -n --max-count 5 'TODO'` |
| File search | `fd` | `fd -e ts -d 3 router` |
| View a file (limited) | `bat` / `head` / `tail` | `bat --line-range 1:40 f` |
| CLI documentation | `tldr` | `tldr ffmpeg` |
| WebSocket | `websocat` | `websocat -1 wss://… <<<'ping'` |
| HTTP request | `http` (httpie) / `curl` | `http GET api/… key==val` |
| Clipboard | `xclip` | `… \| xclip -selection clipboard` |
| Fuzzy filtering | `fzf` | `fd . \| fzf` |
| Diff (pretty) | `delta` | `git diff \| delta` |
| Search-and-replace in file | `sd` | `sd 'foo' 'bar' file` |
| JSON→lines (greppable) | `gron` | `gron f.json \| rg key` |
| JSON interactive browsing | `jless` | `jless f.json` |
| Markdown render | `glow` | `glow README.md` |
| Disk usage | `dust` / `duf` / `ncdu` | `dust -d 2` |
| Benchmark | `hyperfine` | `hyperfine 'cmd a' 'cmd b'` |
| Parallelize | `parallel` | `parallel cmd ::: a b c` |
| Run on file change | `entr` | `fd -e py \| entr -c pytest` |
| Faster compilation | `ccache` | C/C++ build cache |
| SQLite | `sqlite3` | `sqlite3 db 'select …'` |
| Download (fast/resumable) | `aria2c` / `curl` | `aria2c -x8 URL` |

## Media / image / video

| Task | Tool |
|---|---|
| Video convert/cut/transcode | `ffmpeg` |
| Image convert/resize | `convert` / `magick` (ImageMagick) |
| Image/video metadata (EXIF) | `exiftool` |
| GIF optimization | `gifsicle` |
| PNG/JPEG optimization | `optipng`, `pngquant`, `jpegoptim` |
| WebP encode/decode | `cwebp` / `dwebp` |
| PDF → text/image | `pdftotext`, `pdftoppm` (poppler-utils) |
| PDF/PS handling | `gs` (ghostscript) |
| OCR (image → text) | `tesseract` |
| Video/audio download | `yt-dlp` |
| Document conversion | `pandoc` |

## Databases

| Engine | Tool | Typical call |
|---|---|---|
| PostgreSQL | `psql` | `psql "$DATABASE_URL" -c 'select 1'` |
| MySQL / MariaDB | `mysql` | `mysql -h host -u user -p db -e 'show tables'` |
| MS SQL Server | `sqlcmd` | `sqlcmd -S host -U sa -Q 'select 1'` |
| SQLite | `sqlite3` | `sqlite3 app.db '.tables'` |
| MongoDB | `mongosh` | `mongosh "$MONGO_URI" --eval 'db.users.countDocuments()'` |
| Any of the above | `usql` | `usql pg://user:pw@host/db -c 'select 1'` |

- `usql` is a universal client: one syntax for pg/mysql/mssql/sqlite/mongo
  (`usql my://…`, `usql sqlite:app.db`, `usql mongodb://…`).
- Run queries non-interactively (`-c` / `-e` / `--eval` / `-Q`) and pipe the
  result through `jq`/`rg` — don't open an interactive REPL.
- Prefer connection strings from env vars (`$DATABASE_URL`); never hardcode
  credentials in commands.

## Output-filtering rules

- Do NOT `cat` files larger than 20 lines → use `bat --line-range`, `head`, `tail`.
- NEVER dump API/JSON/YAML logs raw → pipe through `jq` / `yq` for the wanted key.
- For search use `rg` / `fd` (not `grep`/`find`), always with depth/match limits
  (`-d`, `--max-count`, `-m`).
- For documentation use `tldr` instead of the full `man` / verbose recall.
- For WS use `websocat` (single shot `-1`), not an infinite loop.

> If a tool above exists for a task, call it — don't write your own bash/Python
> script for it.
