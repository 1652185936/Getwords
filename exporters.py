"""Build TXT / SRT / PDF documents from transcript segments."""

from __future__ import annotations

import io
from typing import List, Optional

from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
)


def _fmt_timestamp(seconds: float, srt: bool = False) -> str:
    if seconds < 0:
        seconds = 0
    ms = int(round((seconds - int(seconds)) * 1000))
    s = int(seconds)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if srt:
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"
    if h:
        return f"{h:d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def build_text(segments: List[dict], include_timestamps: bool = False) -> str:
    lines = []
    for seg in segments:
        text = seg["text"].replace("\n", " ").strip()
        if not text:
            continue
        if include_timestamps:
            lines.append(f"[{_fmt_timestamp(seg['start'])}] {text}")
        else:
            lines.append(text)
    return "\n".join(lines) + "\n"


def build_srt(segments: List[dict]) -> str:
    blocks = []
    for i, seg in enumerate(segments, start=1):
        text = seg["text"].strip()
        if not text:
            continue
        start = seg["start"]
        end = start + max(seg.get("duration", 0.0), 0.0)
        blocks.append(
            f"{i}\n"
            f"{_fmt_timestamp(start, srt=True)} --> {_fmt_timestamp(end, srt=True)}\n"
            f"{text}\n"
        )
    return "\n".join(blocks)


# Register a CJK-capable font once so Chinese/Japanese/Korean render in PDFs.
_CJK_FONT = "STSong-Light"
_font_registered = False


def _ensure_font() -> str:
    global _font_registered
    if not _font_registered:
        try:
            pdfmetrics.registerFont(UnicodeCIDFont(_CJK_FONT))
            _font_registered = True
        except Exception:
            return "Helvetica"
    return _CJK_FONT


def build_pdf(
    segments: List[dict],
    title: Optional[str] = None,
    video_id: Optional[str] = None,
    include_timestamps: bool = False,
) -> bytes:
    font = _ensure_font()
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
        title=title or "YouTube Transcript",
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "TitleCJK", parent=styles["Title"], fontName=font, fontSize=18, leading=24,
    )
    meta_style = ParagraphStyle(
        "Meta", parent=styles["Normal"], fontName=font, fontSize=9,
        textColor="#666666", leading=14,
    )
    body_style = ParagraphStyle(
        "BodyCJK", parent=styles["Normal"], fontName=font, fontSize=11,
        leading=17, alignment=TA_LEFT, spaceAfter=4,
    )
    ts_style = ParagraphStyle(
        "TS", parent=body_style, textColor="#1a73e8", fontSize=9,
    )

    story = []
    if title:
        story.append(Paragraph(_esc(title), title_style))
    if video_id:
        story.append(
            Paragraph(f"https://www.youtube.com/watch?v={video_id}", meta_style)
        )
    story.append(Spacer(1, 0.5 * cm))

    for seg in segments:
        text = _esc(seg["text"].replace("\n", " ").strip())
        if not text:
            continue
        if include_timestamps:
            story.append(Paragraph(f"[{_fmt_timestamp(seg['start'])}]", ts_style))
        story.append(Paragraph(text, body_style))

    doc.build(story)
    return buf.getvalue()


def _esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )
