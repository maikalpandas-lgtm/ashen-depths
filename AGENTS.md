# Agent rules — Ashen Depths

## Art / sprites (обязательно)

1. **Не генерировать** новые картинки (image_gen / Imagine / «перерисуй») **без явной просьбы** пользователя.
2. Работать с **уже существующими** ассетами из каталога:
   - `assets/textures/ASSETS.md` — подписи, назначение, **рецепт обрезки**
   - `assets/textures/masters/` — source + PNG masters
   - `assets/textures/*.png` — файлы, которые грузит игра
3. Если нужно поправить спрайт: **scale / position / cut / код** — не новая генерация.
4. Новые ассеты — **только** после фразы вроде «нарисуй / сгенерируй / перерисуй X».
5. После gen (когда попросили): подписать в `ASSETS.md` + masters, не плодить безымянные `_tmp*`.
6. **Обрезка:** только рабочий способ из `ASSETS.md` § «Как обрезать» — edge flood chromakey (`tools/sprite_cutter.py`), **без** жирного outline-inflate и без агрессивного scissor на стали.
7. **Viewmodel:** не stretch/shake всю руку с факелом — рука статична; лёгкий stretch только у мелких wall-torch props.

## Git

- Коммитить осмысленно, не коммитить мусор (`_tmp*`, `raw/cut/`, `gen_*` — см. `.gitignore`).
- Push на `origin/main` после нормального коммита, если пользователь ждёт изменения на GitHub.

## Design

- Бой/карты/рюкзак — `docs/DESIGN.md` (§7 cards no board, §8 BB backpack).
- Не менять зафиксированные решения в DESIGN без запроса.
