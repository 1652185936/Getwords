# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec — builds a single-file 'GetWords' desktop app.

Build with:  pyinstaller getwords.spec --noconfirm
"""

from PyInstaller.utils.hooks import collect_all

datas = [("templates", "templates"), ("static", "static")]
binaries = []
hiddenimports = ["youtube_transcript_api"]

# Bundle data/binaries/submodules for libs that load resources at runtime.
# yt_dlp is the optional fallback path; if its collection fails on the build
# machine (e.g. a broken cryptography install) the app still works via the
# primary youtube-transcript-api source, so we degrade gracefully.
for pkg in ("reportlab", "yt_dlp"):
    try:
        d, b, h = collect_all(pkg)
        datas += d
        binaries += b
        hiddenimports += h
    except Exception as exc:  # noqa: BLE001
        print(f"[getwords.spec] WARNING: skipping bundling of {pkg!r}: {exc}")

block_cipher = None

a = Analysis(
    ["desktop.py"],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "cryptography"],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="GetWords",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,        # keep a console so the URL/status is visible
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,
)
