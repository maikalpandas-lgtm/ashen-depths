# Ashen Depths — Handoff

Один файл, чтобы передать проект другой нейросети / другому разработчику.
Скопируй блок «Промпт» ниже — этого достаточно для старта.

---

## Промпт (копировать целиком)

```
Изучи проект Ashen Depths — Godot 4 dungeon crawl + card combat.

Репо: https://github.com/maikalpandas-lgtm/ashen-depths
Стек: Godot 4.7+, GDScript
Запуск: открыть папку как проект, F5 → scenes/main.tscn
Управление: W/S — шаг на клетку, A/D — поворот 90°, R — новый данж, Esc — меню.
Камера залочена вперёд (grid crawler, не свободный FPS).

Обязательно прочитай перед кодом:
- AGENTS.md      — жёсткие правила (спрайты, git, движение)
- docs/DESIGN.md — дизайн (§7 карты без board, §8 backpack)
- docs/ROADMAP.md— фазы и что дальше
- docs/MCP_GODOT.md — как гонять Godot из агента
- assets/textures/ASSETS.md — каталог спрайтов + рецепт обрезки

Ключевые скрипты:
- scripts/dungeon_generator.gd — лабиринт, стены, факелы, пропсы (самый большой файл)
- scripts/player_controller.gd — grid-move, поворот 90°, sway рук
- scripts/torch_sprites.gd     — viewmodel рук + настенные факелы
- scripts/texture_factory.gd   — процедурные текстуры
- scripts/minimap.gd, main.gd, chest.gd, flame_flicker.gd, game_state.gd
- shaders/flame_shimmer.gdshader — анимация огня

Статус: Фаза 0–1 (лабиринт MVP) закрыта. Дальше Фаза 2 — партия из 3 героев + колоды.

Красные линии:
- НЕ генерировать/перерисовывать спрайты без явной просьбы — только scale/cut/код.
- НЕ делать double-layer / V-fold настенные факелы.
- Grid crawler only: шаг клетка, поворот 90°, props прибиты к стенам, без billboard к камере.
- НЕ ломать layout рук без скрина «до/после».
- После каждого осмысленного изменения: git commit + git push origin main.
- Сначала git status / git log -5, потом код.
```

---

## Что отдавать (минимальный набор)

```
ashen-depths/
  AGENTS.md
  README.md
  docs/DESIGN.md
  docs/ROADMAP.md
  docs/HANDOFF.md
  docs/MCP_GODOT.md
  project.godot
  scenes/          main.tscn, player.tscn
  scripts/*.gd
  shaders/
  assets/textures/ (+ ASSETS.md)
  tools/sprite_cutter.py
```

Не нужно: `.godot/`, `.import` кэш, бинарники, `raw/cut/`, `_tmp*`.

| Что | Зачем |
|---|---|
| `AGENTS.md` | правила, чтобы не наступала на те же грабли |
| `README.md` | запуск и управление |
| `docs/DESIGN.md` + `ROADMAP.md` | зачем и куда |
| `git log` / remote | история решений |
| 1–2 скрина «как сейчас» | визуальный эталон |
| Список «не трогать» | руки, ассеты, зафиксированные design-решения |

## Способы передачи

**A. GitHub (проще всего).** «Клонируй https://github.com/maikalpandas-lgtm/ashen-depths, прочитай AGENTS.md и docs/, предложи план Фазы 2.»

**B. Workspace.** Открыть папку `ashen-depths` в Claude Code / Cursor / Codex как рабочую директорию.

**C. Файлами.** Прикрепить `AGENTS.md`, `docs/DESIGN.md`, `docs/ROADMAP.md`, `docs/HANDOFF.md` + нужные `.gd`.

**D. Этот файл.** Отдать только `docs/HANDOFF.md` и сказать «читай ссылки внутри».

## Зафиксированные решения (не переоткрывать без запроса)

- Бой: карты **без board** (Inscryption-flavor), враги в коридоре — `DESIGN.md` §7.
- Инвентарь: **backpack 5×4** с adjacency — `DESIGN.md` §8.
- Движение: **grid crawler**, 90°, камера lock forward.
- Спрайты режутся edge flood chromakey (`tools/sprite_cutter.py`), без outline-inflate.
- Рука с факелом статична; лёгкий stretch — только у мелких wall-torch пропсов.
