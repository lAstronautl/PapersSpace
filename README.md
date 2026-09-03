# PaperSpace
this is a note-taking site i made for fun. i hope you enjoy it.

controls:
LMB - drag item around
RMB - edit hovered item
A/D - rotate held item
E - snap to 45d angle
space - make new paper
Shift + MMB - point

## Структура

- `paperTest/` — исходники проекта (Godot 4.6.3), без изменений, кроме
  `2d/run_on_separate_thread = false` в `project.godot` (см. ниже, почему).
- `docs/` — собранный веб-билд (`index.html`, `.wasm`, `.pck`, `.js`).
  GitHub Pages отдаёт сайт прямо из этой папки.

Билд собран с `nothreads`-шаблонами экспорта, потому что GitHub Pages не
может выставить заголовки `Cross-Origin-Opener-Policy` /
`Cross-Origin-Embedder-Policy`, без которых многопоточный WASM не
запустится в браузере.
