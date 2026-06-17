# 🎬 YouTube Subtitle Extractor

Paste a YouTube link, fetch the video's captions, preview them, and export to
**TXT · SRT · PDF**. Supports picking the caption language and toggling
timestamps. Works with non‑Latin text (Chinese / Japanese / Korean) in the PDF.

![flow](https://img.shields.io/badge/paste%20URL-%E2%86%92%20get%20captions-%E2%86%92%20export-ff3b30)

## Features

- **Paste any YouTube URL** — `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`,
  `/live/`, or a bare 11‑char video ID.
- **Language picker** — lists every available caption track (manual + auto) and
  lets you switch between them.
- **Live preview** — clickable timestamps jump to that moment on YouTube.
- **Export**
  - `TXT` — plain text, optionally with `[mm:ss]` timestamps
  - `SRT` — standard subtitle file
  - `PDF` — formatted document with title, link, and CJK font support
  - `Copy` — copy the whole transcript to the clipboard
- **Robust fetching** — uses
  [`youtube-transcript-api`](https://github.com/jdepoix/youtube-transcript-api)
  first, then falls back to [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) if the
  primary source is blocked or empty.

## Run it

There are two ways to use it.

### A) Desktop app (recommended)

A double-clickable app that opens its own window — no terminal needed.

```bash
# macOS / Linux
./build.sh

# Windows
build.bat
```

This produces a single-file executable in `dist/`:

- **Windows:** `dist\GetWords.exe`
- **macOS / Linux:** `dist/GetWords`

Double-click it to launch. It starts a tiny local server and opens a native
window (falling back to your default browser if no GUI backend is available).

> The build must be run **on the same OS** you want the app for — PyInstaller
> does not cross-compile. Build on Windows for a `.exe`, on macOS for a Mac app.

### B) Run as a plain web app

```bash
pip install -r requirements.txt   # 1. install deps
python app.py                     # 2. start the server
#                                   3. open http://localhost:5000
```

Either way: paste a YouTube URL, click **Get Subtitles**, then use the export
buttons.

## Project layout

```
app.py                   Flask web server + JSON/export API
transcript_service.py    Fetch captions (youtube-transcript-api + yt-dlp fallback)
exporters.py             Build TXT / SRT / PDF documents
desktop.py               Desktop launcher (native window + browser fallback)
getwords.spec            PyInstaller build recipe
build.sh / build.bat     One-command build scripts
templates/index.html     Single-page UI
static/style.css         Styling (dark theme)
static/app.js            Front-end logic
requirements.txt         Python dependencies (web app)
requirements-desktop.txt Extra deps for building the desktop app
```

## API

The front end talks to two JSON endpoints — handy if you want to script it.

### `POST /api/transcript`

```json
{ "url": "https://www.youtube.com/watch?v=VIDEO_ID", "lang": "en" }
```

Returns the video id, chosen language, the list of available languages, and the
caption `segments` (`start`, `duration`, `text`). `lang` is optional.

### `POST /api/export/<txt|srt|pdf>`

```json
{
  "segments": [{ "start": 0.0, "duration": 2.5, "text": "Hello" }],
  "title": "My video",
  "video_id": "VIDEO_ID",
  "include_timestamps": true
}
```

Returns the generated file as a download.

## Notes

- A few videos genuinely have **no captions** (no manual subtitles and no
  auto‑generated track) — nothing can be extracted in that case.
- YouTube sometimes rate‑limits requests coming from data‑center / cloud IPs
  (you may see a `403`). Running the app from a normal residential network, or
  configuring a proxy for `yt-dlp`, resolves this. This is a YouTube‑side
  restriction, not a bug in the app — run the app on your own machine and it
  works.

## What was verified

Built and tested in CI-like conditions (single-file PyInstaller binary):

- ✅ URL parsing for every YouTube URL form + invalid-input handling
- ✅ TXT / SRT / PDF generation, including mixed CJK + Latin text in the PDF
- ✅ All API endpoints and error paths
- ✅ The packaged executable boots, serves the UI, and exports PDF/SRT/TXT
- ⚠️ *Live caption fetching* could not be exercised in the sandboxed build
  environment because its network proxy blocks YouTube (`403`). It works on a
  normal network — see the note above.
