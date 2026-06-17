"""Fetch YouTube subtitles/transcripts.

Primary source: youtube-transcript-api (fast, no download).
Fallback: yt-dlp (downloads the caption track) when the primary
source is blocked or has no data.
"""

from __future__ import annotations

import json
import re
import subprocess
import tempfile
import urllib.request
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Optional

from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import (
    TranscriptsDisabled,
    NoTranscriptFound,
    VideoUnavailable,
)


# --------------------------------------------------------------------------- #
# Data models
# --------------------------------------------------------------------------- #
@dataclass
class Segment:
    start: float       # seconds
    duration: float    # seconds
    text: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class TranscriptResult:
    video_id: str
    language: str
    language_code: str
    is_generated: bool
    segments: List[Segment]
    available_languages: List[dict]   # [{code, name, generated}]
    source: str                       # "youtube-transcript-api" | "yt-dlp"

    def to_dict(self) -> dict:
        d = asdict(self)
        d["segments"] = [s.to_dict() for s in self.segments]
        return d


class TranscriptError(Exception):
    """User-facing error while fetching a transcript."""


# --------------------------------------------------------------------------- #
# URL / id helpers
# --------------------------------------------------------------------------- #
_YT_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


def extract_video_id(url_or_id: str) -> str:
    """Accept a raw 11-char id or any common YouTube URL form."""
    s = (url_or_id or "").strip()
    if _YT_ID_RE.match(s):
        return s

    patterns = [
        r"(?:v=|/v/)([A-Za-z0-9_-]{11})",
        r"youtu\.be/([A-Za-z0-9_-]{11})",
        r"/embed/([A-Za-z0-9_-]{11})",
        r"/shorts/([A-Za-z0-9_-]{11})",
        r"/live/([A-Za-z0-9_-]{11})",
    ]
    for p in patterns:
        m = re.search(p, s)
        if m:
            return m.group(1)

    raise TranscriptError("Could not find a valid YouTube video ID in the input.")


# --------------------------------------------------------------------------- #
# Title lookup (best-effort, no API key)
# --------------------------------------------------------------------------- #
def fetch_title(video_id: str) -> Optional[str]:
    try:
        url = (
            "https://www.youtube.com/oembed?url="
            f"https://www.youtube.com/watch?v={video_id}&format=json"
        )
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("title")
    except Exception:
        return None


# --------------------------------------------------------------------------- #
# Primary: youtube-transcript-api
# --------------------------------------------------------------------------- #
def _list_languages(api: YouTubeTranscriptApi, video_id: str):
    """Return (transcript_list, [{code,name,generated}]) or (None, [])."""
    try:
        tlist = api.list(video_id)
    except Exception:
        return None, []

    langs = []
    for t in tlist:
        langs.append(
            {
                "code": t.language_code,
                "name": t.language,
                "generated": t.is_generated,
            }
        )
    return tlist, langs


def _fetch_via_api(video_id: str, preferred_lang: Optional[str]) -> TranscriptResult:
    api = YouTubeTranscriptApi()
    tlist, langs = _list_languages(api, video_id)

    if tlist is None:
        raise TranscriptError("__fallback__")

    # Choose a transcript object.
    chosen = None
    if preferred_lang:
        try:
            chosen = tlist.find_transcript([preferred_lang])
        except Exception:
            chosen = None
    if chosen is None:
        # Prefer the first available, manual over generated.
        ordered = sorted(langs, key=lambda x: x["generated"])
        for entry in ordered:
            try:
                chosen = tlist.find_transcript([entry["code"]])
                break
            except Exception:
                continue
    if chosen is None:
        raise TranscriptError("__fallback__")

    fetched = chosen.fetch()
    segments = [
        Segment(start=float(s.start), duration=float(s.duration), text=s.text)
        for s in fetched.snippets
    ]
    return TranscriptResult(
        video_id=video_id,
        language=fetched.language,
        language_code=fetched.language_code,
        is_generated=fetched.is_generated,
        segments=segments,
        available_languages=langs,
        source="youtube-transcript-api",
    )


# --------------------------------------------------------------------------- #
# Fallback: yt-dlp
# --------------------------------------------------------------------------- #
def _parse_json3(data: dict) -> List[Segment]:
    segments = []
    for ev in data.get("events", []):
        segs = ev.get("segs")
        if not segs:
            continue
        text = "".join(seg.get("utf8", "") for seg in segs).strip()
        if not text:
            continue
        start = ev.get("tStartMs", 0) / 1000.0
        dur = ev.get("dDurationMs", 0) / 1000.0
        segments.append(Segment(start=start, duration=dur, text=text))
    return segments


def _fetch_via_ytdlp(video_id: str, preferred_lang: Optional[str]) -> TranscriptResult:
    url = f"https://www.youtube.com/watch?v={video_id}"
    with tempfile.TemporaryDirectory() as tmp:
        out = str(Path(tmp) / "%(id)s.%(ext)s")
        lang_arg = preferred_lang or "en.*,.*"
        cmd = [
            "yt-dlp",
            "--skip-download",
            "--write-subs",
            "--write-auto-subs",
            "--sub-langs", lang_arg,
            "--sub-format", "json3",
            "-o", out,
            url,
        ]
        try:
            subprocess.run(cmd, capture_output=True, timeout=120, check=False)
        except FileNotFoundError:
            raise TranscriptError(
                "No transcript could be retrieved (yt-dlp is not installed)."
            )
        except subprocess.TimeoutExpired:
            raise TranscriptError("Timed out while downloading subtitles.")

        files = sorted(Path(tmp).glob("*.json3"))
        if not files:
            raise TranscriptError(
                "No subtitles are available for this video (tried all sources)."
            )

        chosen_file = files[0]
        if preferred_lang:
            for f in files:
                if f".{preferred_lang}." in f.name:
                    chosen_file = f
                    break

        # Language code is the segment between id and ".json3".
        parts = chosen_file.name.split(".")
        lang_code = parts[-2] if len(parts) >= 3 else "unknown"

        data = json.loads(chosen_file.read_text(encoding="utf-8"))
        segments = _parse_json3(data)
        if not segments:
            raise TranscriptError("The downloaded subtitle track was empty.")

        available = [{"code": f.name.split(".")[-2], "name": f.name.split(".")[-2],
                      "generated": True} for f in files]
        return TranscriptResult(
            video_id=video_id,
            language=lang_code,
            language_code=lang_code,
            is_generated=True,
            segments=segments,
            available_languages=available,
            source="yt-dlp",
        )


# --------------------------------------------------------------------------- #
# Public entry point
# --------------------------------------------------------------------------- #
def get_transcript(url_or_id: str, preferred_lang: Optional[str] = None) -> TranscriptResult:
    video_id = extract_video_id(url_or_id)

    try:
        return _fetch_via_api(video_id, preferred_lang)
    except TranscriptError as e:
        if str(e) != "__fallback__":
            raise
    except (TranscriptsDisabled, NoTranscriptFound, VideoUnavailable):
        pass
    except Exception:
        pass

    # Fallback to yt-dlp.
    return _fetch_via_ytdlp(video_id, preferred_lang)
