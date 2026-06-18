"""GetWords — Android app (Kivy).

Paste a YouTube URL, fetch the captions, read them on screen, and export
to TXT / SRT / PDF saved on the phone. Pure-Python so it can be packaged
into an APK with Buildozer / python-for-android.
"""

from __future__ import annotations

import os
import threading
import traceback
from datetime import datetime

from kivy.app import App
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.metrics import dp
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.scrollview import ScrollView
from kivy.uix.spinner import Spinner
from kivy.uix.textinput import TextInput

from subtitles import (
    extract_video_id,
    fetch_transcript,
    ts as _ts,
    build_text,
    build_srt,
    build_pdf,
)

Window.softinput_mode = "below_target"

PRIMARY = (1, 0.231, 0.188, 1)     # red
ACCENT = (0.102, 0.451, 0.909, 1)  # blue
BG = (0.06, 0.07, 0.09, 1)
CARD = (0.11, 0.13, 0.16, 1)


# --------------------------------------------------------------------------- #
# Storage helpers
# --------------------------------------------------------------------------- #
def output_dir():
    """A writable folder; prefer one the user can browse to."""
    try:
        from android.storage import primary_external_storage_path  # type: ignore

        d = os.path.join(primary_external_storage_path(), "Download", "GetWords")
        os.makedirs(d, exist_ok=True)
        # verify writable
        test = os.path.join(d, ".w")
        with open(test, "w") as f:
            f.write("ok")
        os.remove(test)
        return d
    except Exception:
        pass
    try:
        from android.storage import app_storage_path  # type: ignore

        d = os.path.join(app_storage_path(), "exports")
        os.makedirs(d, exist_ok=True)
        return d
    except Exception:
        pass
    d = os.path.join(os.path.expanduser("~"), "GetWords")
    os.makedirs(d, exist_ok=True)
    return d


def request_android_permissions():
    try:
        from android.permissions import request_permissions, Permission  # type: ignore

        request_permissions(
            [Permission.INTERNET, Permission.WRITE_EXTERNAL_STORAGE,
             Permission.READ_EXTERNAL_STORAGE]
        )
    except Exception:
        pass


# --------------------------------------------------------------------------- #
# UI
# --------------------------------------------------------------------------- #
class Root(BoxLayout):
    def __init__(self, **kw):
        super().__init__(orientation="vertical", padding=dp(12),
                         spacing=dp(8), **kw)
        Window.clearcolor = BG

        self.segments = []
        self.lang_code = ""
        self.title_text = ""

        title = Label(text="[b]🎬 GetWords 字幕提取[/b]", markup=True,
                      size_hint_y=None, height=dp(40), font_size=dp(20))
        self.add_widget(title)

        self.url = TextInput(
            hint_text="粘贴 YouTube 链接，例如 https://youtu.be/...",
            multiline=False, size_hint_y=None, height=dp(46),
            font_size=dp(15), padding=[dp(10), dp(12)],
        )
        self.add_widget(self.url)

        row = BoxLayout(size_hint_y=None, height=dp(46), spacing=dp(8))
        self.lang = Spinner(text="自动", values=["自动"], size_hint_x=0.4)
        self.fetch_btn = Button(text="获取字幕", background_color=PRIMARY,
                                background_normal="")
        self.fetch_btn.bind(on_release=self.on_fetch)
        row.add_widget(self.lang)
        row.add_widget(self.fetch_btn)
        self.add_widget(row)

        opt = BoxLayout(size_hint_y=None, height=dp(34), spacing=dp(8))
        self.ts_btn = ToggleableLabel("□ 显示时间戳")
        opt.add_widget(self.ts_btn)
        self.add_widget(opt)

        self.status = Label(text="", size_hint_y=None, height=dp(24),
                            font_size=dp(13), color=(0.6, 0.7, 0.8, 1))
        self.add_widget(self.status)

        sv = ScrollView()
        self.transcript = Label(
            text="", markup=False, size_hint_y=None, halign="left",
            valign="top", font_size=dp(15), padding=[dp(6), dp(6)],
        )
        self.transcript.bind(
            width=lambda *_: setattr(self.transcript, "text_size",
                                     (self.transcript.width, None)),
            texture_size=lambda *_: setattr(self.transcript, "height",
                                            self.transcript.texture_size[1]),
        )
        sv.add_widget(self.transcript)
        self.add_widget(sv)

        exp = BoxLayout(size_hint_y=None, height=dp(48), spacing=dp(8))
        for label, fmt in (("导出 TXT", "txt"), ("导出 SRT", "srt"),
                           ("导出 PDF", "pdf"), ("复制", "copy")):
            b = Button(text=label, background_color=ACCENT,
                       background_normal="")
            b.bind(on_release=lambda _b, f=fmt: self.on_export(f))
            exp.add_widget(b)
        self.add_widget(exp)

    # -- actions -----------------------------------------------------------
    def set_status(self, msg, error=False):
        self.status.text = msg
        self.status.color = (1, 0.5, 0.5, 1) if error else (0.6, 0.7, 0.8, 1)

    def on_fetch(self, *_):
        url = self.url.text.strip()
        if not url:
            self.set_status("请输入 YouTube 链接", error=True)
            return
        self.fetch_btn.disabled = True
        self.set_status("正在获取字幕…")
        pref = None if self.lang.text == "自动" else self.lang.text
        threading.Thread(target=self._fetch_worker, args=(url, pref),
                         daemon=True).start()

    def _fetch_worker(self, url, pref):
        try:
            segments, code, available = fetch_transcript(url, pref)
            Clock.schedule_once(
                lambda _dt: self._fetch_done(segments, code, available))
        except Exception as e:
            traceback.print_exc()
            msg = str(e) or e.__class__.__name__
            Clock.schedule_once(lambda _dt: self._fetch_fail(msg))

    def _fetch_fail(self, msg):
        self.fetch_btn.disabled = False
        self.set_status(f"失败：{msg}", error=True)

    def _fetch_done(self, segments, code, available):
        self.fetch_btn.disabled = False
        self.segments = segments
        self.lang_code = code
        self.title_text = f"YouTube_{extract_video_id(self.url.text)}"
        vals = ["自动"] + available
        self.lang.values = vals
        if code in available:
            self.lang.text = code
        self._render()
        self.set_status(f"完成：{len(segments)} 行字幕（{code}）")

    def _render(self):
        ts = self.ts_btn.active
        lines = []
        for seg in self.segments:
            t = seg["text"].strip()
            if not t:
                continue
            lines.append(f"[{_ts(seg['start'])}]  {t}" if ts else t)
        self.transcript.text = "\n".join(lines)

    def on_export(self, fmt):
        if not self.segments:
            self.set_status("还没有字幕，先获取", error=True)
            return
        if fmt == "copy":
            from kivy.core.clipboard import Clipboard
            Clipboard.copy(build_text(self.segments, self.ts_btn.active))
            self.set_status("已复制到剪贴板")
            return
        threading.Thread(target=self._export_worker, args=(fmt,),
                         daemon=True).start()

    def _export_worker(self, fmt):
        try:
            stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            base = f"{self.title_text}_{stamp}"
            d = output_dir()
            ts = self.ts_btn.active
            if fmt == "txt":
                path = os.path.join(d, base + ".txt")
                with open(path, "w", encoding="utf-8") as f:
                    f.write(build_text(self.segments, ts))
            elif fmt == "srt":
                path = os.path.join(d, base + ".srt")
                with open(path, "w", encoding="utf-8") as f:
                    f.write(build_srt(self.segments))
            else:
                path = os.path.join(d, base + ".pdf")
                build_pdf(path, self.segments, self.title_text, ts)
            Clock.schedule_once(lambda _dt: self.set_status(f"已保存：{path}"))
        except Exception as e:
            traceback.print_exc()
            msg = str(e) or e.__class__.__name__
            Clock.schedule_once(lambda _dt: self.set_status(
                f"导出失败：{msg}", error=True))


class ToggleableLabel(Button):
    """A simple checkbox-like toggle button."""

    def __init__(self, label, **kw):
        self._label = label
        super().__init__(text=label, background_normal="",
                         background_color=(0, 0, 0, 0), halign="left",
                         size_hint_x=1, **kw)
        self.active = False
        self.bind(on_release=self._toggle)

    def _toggle(self, *_):
        self.active = not self.active
        self.text = ("☑ " if self.active else "□ ") + self._label[2:]
        app = App.get_running_app()
        if app and app.root:
            app.root._render()


class GetWordsApp(App):
    def build(self):
        self.title = "GetWords"
        return Root()

    def on_start(self):
        request_android_permissions()


if __name__ == "__main__":
    GetWordsApp().run()
