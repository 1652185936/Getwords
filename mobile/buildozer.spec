[app]
title = GetWords
package.name = getwords
package.domain = org.getwords

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,ttf,otf
source.include_patterns = assets/*

version = 1.0

# Pure-Python deps (youtube-transcript-api, fpdf, defusedxml, requests stack)
# need no recipes; openssl is pulled in for HTTPS.
requirements = python3,kivy==2.3.0,android,pyjnius,openssl,requests,urllib3,idna,certifi,charset-normalizer,defusedxml,youtube-transcript-api,fpdf

# Use a pinned python-for-android checkout (Python 3.11) prepared by the CI
# workflow. p4a master builds CPython 3.14, which Kivy 2.3.0 cannot compile,
# and a release *tag* can't be passed via p4a.branch, so we point at a local
# clone instead.
p4a.source_dir = /home/runner/p4a-src

orientation = portrait
fullscreen = 0

android.permissions = INTERNET,WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE
android.api = 34
android.minapi = 24
android.archs = arm64-v8a
android.accept_sdk_license = True
android.allow_backup = 1

# Show a console-style logcat tag for debugging
log_level = 2

[buildozer]
warn_on_root = 0
