"use strict";

const $ = (id) => document.getElementById(id);
const urlInput = $("url");
const fetchBtn = $("fetchBtn");
const langSel = $("lang");
const tsCheck = $("ts");
const statusEl = $("status");
const resultCard = $("resultCard");
const transcriptEl = $("transcript");

let current = null; // { video_id, title, segments, ... }

function setStatus(msg, kind) {
  if (!msg) { statusEl.classList.add("hidden"); return; }
  statusEl.textContent = msg;
  statusEl.className = "status " + (kind || "");
}

function fmtTime(sec) {
  sec = Math.max(0, Math.floor(sec));
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return h ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
}

async function fetchTranscript() {
  const url = urlInput.value.trim();
  if (!url) { setStatus("Please paste a YouTube URL.", "error"); return; }

  fetchBtn.disabled = true;
  setStatus("Fetching subtitles…", "loading");
  resultCard.classList.add("hidden");

  try {
    const res = await fetch("/api/transcript", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url, lang: langSel.value || null }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Request failed");
    current = data;
    render(data);
    setStatus("", "");
  } catch (e) {
    setStatus(e.message, "error");
  } finally {
    fetchBtn.disabled = false;
  }
}

function render(data) {
  $("vidTitle").textContent = data.title || data.video_id;
  const gen = data.is_generated ? "auto-generated" : "manual";
  $("meta").textContent =
    `${data.language} (${data.language_code}) · ${gen} · ` +
    `${data.segments.length} lines · source: ${data.source}`;

  // Populate language dropdown.
  const cur = langSel.value;
  langSel.innerHTML = '<option value="">Auto (best available)</option>';
  (data.available_languages || []).forEach((l) => {
    const o = document.createElement("option");
    o.value = l.code;
    o.textContent = `${l.name}${l.generated ? " (auto)" : ""}`;
    if (l.code === data.language_code) o.selected = true;
    langSel.appendChild(o);
  });
  langSel.disabled = false;

  transcriptEl.innerHTML = "";
  const vid = data.video_id;
  data.segments.forEach((seg) => {
    const line = document.createElement("div");
    line.className = "line";
    const t = document.createElement("a");
    t.className = "t";
    t.textContent = fmtTime(seg.start);
    t.href = `https://www.youtube.com/watch?v=${vid}&t=${Math.floor(seg.start)}s`;
    t.target = "_blank";
    t.rel = "noopener";
    const txt = document.createElement("div");
    txt.className = "txt";
    txt.textContent = seg.text;
    line.appendChild(t);
    line.appendChild(txt);
    transcriptEl.appendChild(line);
  });
  applyTs();
  resultCard.classList.remove("hidden");
}

function applyTs() {
  transcriptEl.classList.toggle("no-ts", !tsCheck.checked);
}

async function exportAs(fmt) {
  if (!current) return;
  try {
    const res = await fetch(`/api/export/${fmt}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        segments: current.segments,
        title: current.title,
        video_id: current.video_id,
        include_timestamps: tsCheck.checked,
      }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || "Export failed");
    }
    const blob = await res.blob();
    const dispo = res.headers.get("Content-Disposition") || "";
    const m = dispo.match(/filename="?([^"]+)"?/);
    const name = m ? m[1] : `transcript.${fmt}`;
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(a.href);
  } catch (e) {
    setStatus(e.message, "error");
  }
}

function copyText() {
  if (!current) return;
  const useTs = tsCheck.checked;
  const text = current.segments
    .map((s) => (useTs ? `[${fmtTime(s.start)}] ${s.text}` : s.text))
    .join("\n");
  navigator.clipboard.writeText(text).then(
    () => { $("copyBtn").textContent = "✓ Copied"; setTimeout(
      () => ($("copyBtn").textContent = "⧉ Copy"), 1500); },
    () => setStatus("Copy failed.", "error")
  );
}

fetchBtn.addEventListener("click", fetchTranscript);
urlInput.addEventListener("keydown", (e) => { if (e.key === "Enter") fetchTranscript(); });
langSel.addEventListener("change", () => { if (current) fetchTranscript(); });
tsCheck.addEventListener("change", applyTs);
document.querySelectorAll(".exp").forEach((b) =>
  b.addEventListener("click", () => exportAs(b.dataset.fmt)));
$("copyBtn").addEventListener("click", copyText);
