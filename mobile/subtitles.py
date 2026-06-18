"""Pure-Python subtitle fetching + export logic (no Kivy/Android imports).

Kept separate from main.py so it can be unit-tested on a desktop.
"""

from __future__ import annotations

import os
import re

_YT_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


def extract_video_id(url_or_id: str) -> str:
    s = (url_or_id or "").strip()
    if _YT_ID_RE.match(s):
        return s
    for p in (
        r"(?:v=|/v/)([A-Za-z0-9_-]{11})",
        r"youtu\.be/([A-Za-z0-9_-]{11})",
        r"/embed/([A-Za-z0-9_-]{11})",
        r"/shorts/([A-Za-z0-9_-]{11})",
        r"/live/([A-Za-z0-9_-]{11})",
    ):
        m = re.search(p, s)
        if m:
            return m.group(1)
    raise ValueError("链接里找不到有效的 YouTube 视频 ID")


def fetch_transcript(url_or_id: str, preferred_lang=None):
    """Return (segments, language_code, [available_lang_codes])."""
    from youtube_transcript_api import YouTubeTranscriptApi

    video_id = extract_video_id(url_or_id)
    api = YouTubeTranscriptApi()
    tlist = api.list(video_id)

    available = [t.language_code for t in tlist]

    chosen = None
    if preferred_lang:
        try:
            chosen = tlist.find_transcript([preferred_lang])
        except Exception:
            chosen = None
    if chosen is None:
        for code in available:
            try:
                chosen = tlist.find_transcript([code])
                break
            except Exception:
                continue
    if chosen is None:
        raise ValueError("这个视频没有可用的字幕")

    fetched = chosen.fetch()
    segments = [
        {"start": float(s.start), "duration": float(s.duration), "text": s.text}
        for s in fetched.snippets
    ]
    return segments, chosen.language_code, available


def ts(seconds, srt=False):
    if seconds < 0:
        seconds = 0
    ms = int(round((seconds - int(seconds)) * 1000))
    s = int(seconds)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if srt:
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"
    return f"{h:d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def build_text(segments, timestamps=False):
    out = []
    for seg in segments:
        text = seg["text"].replace("\n", " ").strip()
        if not text:
            continue
        out.append(f"[{ts(seg['start'])}] {text}" if timestamps else text)
    return "\n".join(out) + "\n"


def build_srt(segments):
    blocks = []
    for i, seg in enumerate(segments, 1):
        text = seg["text"].strip()
        if not text:
            continue
        end = seg["start"] + max(seg.get("duration", 0.0), 0.0)
        blocks.append(f"{i}\n{ts(seg['start'], True)} --> {ts(end, True)}\n{text}\n")
    return "\n".join(blocks)


# A bundled unicode font (added by the CI build) guarantees CJK PDFs even on
# devices whose only CJK font is a .ttc collection (which PyFPDF can't read).
_BUNDLED_FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "assets", "cjk.ttf")

# Plain .ttf CJK fonts that ship on many Android / HarmonyOS / EMUI devices.
_DEVICE_FONT_CANDIDATES = [
    "/system/fonts/DroidSansFallbackFull.ttf",
    "/system/fonts/DroidSansFallback.ttf",
    "/system/fonts/HarmonyOS_Sans_SC_Regular.ttf",
    "/system/fonts/HwChinese-Regular.ttf",
    "/system/fonts/NotoSansSC-Regular.ttf",
]


def find_cjk_font():
    if os.path.exists(_BUNDLED_FONT):
        return _BUNDLED_FONT
    for p in _DEVICE_FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    try:
        for name in sorted(os.listdir("/system/fonts")):
            low = name.lower()
            if low.endswith(".ttf") and any(
                k in low for k in ("chinese", "fallback", "cjk", "sc")
            ):
                return os.path.join("/system/fonts", name)
    except Exception:
        pass
    return None


def build_pdf(path, segments, title=None, timestamps=False, font_path=None):
    import fpdf as _fpdf
    from fpdf import FPDF

    # Never try to write a font cache next to a read-only system font.
    try:
        _fpdf.set_global("FPDF_CACHE_MODE", 1)
    except Exception:
        pass

    pdf = FPDF(format="A4")
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()

    unicode_font = False
    font_path = font_path or find_cjk_font()
    if font_path and os.path.exists(font_path):
        try:
            pdf.add_font("uni", "", font_path, uni=True)
            unicode_font = True
        except Exception:
            unicode_font = False

    def emit(text, size):
        if unicode_font:
            pdf.set_font("uni", "", size)
            pdf.multi_cell(0, size * 0.62, text)
        else:
            pdf.set_font("Arial", "", size)
            safe = text.encode("latin-1", "ignore").decode("latin-1")
            pdf.multi_cell(0, size * 0.62, safe)

    if title:
        emit(title, 16)
        pdf.ln(2)

    for seg in segments:
        text = seg["text"].replace("\n", " ").strip()
        if not text:
            continue
        if timestamps:
            text = f"[{ts(seg['start'])}] {text}"
        emit(text, 11)

    pdf.output(path, "F")
