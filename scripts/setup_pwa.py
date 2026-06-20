#!/usr/bin/env python3
"""Torna a app Streamlit instalável como PWA (Progressive Web App).

Gera ícones, manifest e service worker, e injeta as tags necessárias no
index.html que o Streamlit serve. É idempotente — pode correr sempre que o
Streamlit é (re)instalado (o deploy.sh chama-o automaticamente).
"""
from __future__ import annotations

import os
import re
import subprocess

from PIL import Image, ImageDraw, ImageFont

BG = (15, 123, 102, 255)        # #0F7B66 (acento esmeralda)
THEME = "#0F7B66"
APP_BG = "#F4F6F4"
APP_NAME = "As Minhas Despesas"
SHORT_NAME = "Despesas"

HEAD_TAGS = f"""    <link rel="manifest" href="./manifest.webmanifest" />
    <meta name="theme-color" content="{THEME}" />
    <meta name="mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="default" />
    <meta name="apple-mobile-web-app-title" content="{SHORT_NAME}" />
    <link rel="apple-touch-icon" href="./icon-180.png" />
    <script>
      if ('serviceWorker' in navigator) {{
        window.addEventListener('load', function () {{
          navigator.serviceWorker.register('./sw.js').catch(function () {{}});
        }});
      }}
    </script>"""

MANIFEST = f"""{{
  "name": "{APP_NAME}",
  "short_name": "{SHORT_NAME}",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "{APP_BG}",
  "theme_color": "{THEME}",
  "icons": [
    {{ "src": "./icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" }},
    {{ "src": "./icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" }},
    {{ "src": "./icon-512-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }}
  ]
}}
"""

# Service worker "network-first": tenta sempre a rede primeiro (garante que as
# atualizações aparecem), usa a cache só como recurso offline. Nunca interfere
# com a comunicação interna do Streamlit (/_stcore) nem com pedidos não-GET.
SERVICE_WORKER = """const CACHE = 'despesas-shell-v1';

self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.pathname.startsWith('/_stcore')) return;   // deixa o Streamlit em paz
  if (req.mode !== 'navigate') return;
  event.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put('./', copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match('./'))
  );
});
"""


def _font(size: int) -> ImageFont.FreeTypeFont:
    """Encontra uma fonte com o símbolo €, via fontconfig e caminhos comuns."""
    candidates: list[str] = []
    try:
        out = subprocess.run(
            ["fc-match", "-f", "%{file}", "sans:bold"],
            capture_output=True, text=True, timeout=5,
        )
        if out.stdout.strip():
            candidates.append(out.stdout.strip())
    except Exception:
        pass
    candidates += [
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _make_icon(path: str, size: int, maskable: bool = False) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if maskable:
        draw.rectangle([0, 0, size, size], fill=BG)
        glyph = int(size * 0.46)
    else:
        draw.rounded_rectangle([0, 0, size, size], radius=int(size * 0.22), fill=BG)
        glyph = int(size * 0.56)
    draw.text((size / 2, size / 2 * 0.97), "€", font=_font(glyph),
              fill=(255, 255, 255, 255), anchor="mm")
    img.save(path)


def static_dir() -> str:
    import streamlit
    return os.path.join(os.path.dirname(streamlit.__file__), "static")


def main() -> None:
    static = static_dir()
    print(f"Pasta estática do Streamlit: {static}")

    _make_icon(os.path.join(static, "icon-192.png"), 192)
    _make_icon(os.path.join(static, "icon-512.png"), 512)
    _make_icon(os.path.join(static, "icon-512-maskable.png"), 512, maskable=True)
    _make_icon(os.path.join(static, "icon-180.png"), 180)
    print("Ícones gerados.")

    with open(os.path.join(static, "manifest.webmanifest"), "w") as f:
        f.write(MANIFEST)
    with open(os.path.join(static, "sw.js"), "w") as f:
        f.write(SERVICE_WORKER)
    print("manifest.webmanifest e sw.js escritos.")

    index_path = os.path.join(static, "index.html")
    html = open(index_path).read()
    block = f"<!-- PWA:start -->\n{HEAD_TAGS}\n    <!-- PWA:end -->"
    if "<!-- PWA:start -->" in html:
        html = re.sub(r"<!-- PWA:start -->.*?<!-- PWA:end -->", block, html, flags=re.S)
        print("index.html: bloco PWA atualizado.")
    else:
        html = html.replace("</head>", f"    {block}\n  </head>", 1)
        print("index.html: bloco PWA injetado.")
    with open(index_path, "w") as f:
        f.write(html)

    print("PWA pronta. (Requer HTTPS para instalar — ver deploy/INSTALL.md)")


if __name__ == "__main__":
    main()
