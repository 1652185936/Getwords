"""YouTube Subtitle Extractor — Flask web app.

Paste a YouTube URL, fetch its subtitles, preview them, and export
to TXT, SRT, or PDF.
"""

from __future__ import annotations

import io
import os
import re
import sys

from flask import Flask, jsonify, render_template, request, send_file

import exporters
from transcript_service import (
    TranscriptError,
    fetch_title,
    get_transcript,
)


def resource_path(rel: str) -> str:
    """Resolve a bundled resource both in dev and inside a PyInstaller build."""
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, rel)


app = Flask(
    __name__,
    template_folder=resource_path("templates"),
    static_folder=resource_path("static"),
)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/transcript", methods=["POST"])
def api_transcript():
    data = request.get_json(silent=True) or {}
    url = (data.get("url") or "").strip()
    lang = (data.get("lang") or "").strip() or None

    if not url:
        return jsonify({"error": "Please paste a YouTube URL."}), 400

    try:
        result = get_transcript(url, preferred_lang=lang)
    except TranscriptError as e:
        return jsonify({"error": str(e)}), 422
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": f"Unexpected error: {e}"}), 500

    payload = result.to_dict()
    payload["title"] = fetch_title(result.video_id) or f"YouTube {result.video_id}"
    return jsonify(payload)


def _safe_filename(name: str, ext: str) -> str:
    base = re.sub(r"[^\w\- ]+", "", name or "transcript").strip() or "transcript"
    base = re.sub(r"\s+", "_", base)[:80]
    return f"{base}.{ext}"


@app.route("/api/export/<fmt>", methods=["POST"])
def api_export(fmt: str):
    data = request.get_json(silent=True) or {}
    segments = data.get("segments") or []
    title = (data.get("title") or "transcript").strip()
    video_id = data.get("video_id")
    include_ts = bool(data.get("include_timestamps", False))

    if not segments:
        return jsonify({"error": "No transcript to export."}), 400

    fmt = fmt.lower()
    try:
        if fmt == "txt":
            content = exporters.build_text(segments, include_ts).encode("utf-8")
            return _send_bytes(content, "text/plain; charset=utf-8",
                               _safe_filename(title, "txt"))
        if fmt == "srt":
            content = exporters.build_srt(segments).encode("utf-8")
            return _send_bytes(content, "application/x-subrip; charset=utf-8",
                               _safe_filename(title, "srt"))
        if fmt == "pdf":
            content = exporters.build_pdf(segments, title=title,
                                          video_id=video_id,
                                          include_timestamps=include_ts)
            return _send_bytes(content, "application/pdf",
                               _safe_filename(title, "pdf"))
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": f"Export failed: {e}"}), 500

    return jsonify({"error": f"Unsupported format: {fmt}"}), 400


def _send_bytes(content: bytes, mimetype: str, filename: str):
    return send_file(
        io.BytesIO(content),
        mimetype=mimetype,
        as_attachment=True,
        download_name=filename,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
