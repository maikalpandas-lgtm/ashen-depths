# Texture assets — catalog

**Правило:** эти ассеты **канонические**.  
Новые картинки рисуем **только когда явно попросишь**.  
Не перегенерировать «на всякий случай».

Cut tool: `tools/sprite_cutter.py` (chromakey / edge flood).  
Masters (исходники + готовые PNG): `assets/textures/masters/`.

---

## Как обрезать (рабочий рецепт — **без артефактов**)

Проверено на viewmodel/torch: чистый край, без белой/розовой каймы.

### 1) Gen (только если попросили)
В промпт: **`pure solid neon magenta background #FF00FF`** (или pure white), один объект, thick black outline в самом арте.

### 2) Cut — `tools/sprite_cutter.py` (предпочтительно)
```bash
python3 tools/sprite_cutter.py path/to/raw.jpg assets/textures/out.png \
  --color FF00FF --tolerance 55 --pad 4
```
Что делает (и почему чисто):
1. **Flood-fill только с краёв** — вырезает key-цвет, **не** дырявит такой же цвет внутри силуэта  
2. **Despill** — убирает пурпурный/розовый fringe по контуру (JPEG/AI)  
3. **Binary alpha** (0 или 255) — нет полупрозрачной «молочной» каймы  
4. **Crop** по bbox + pad  

Для **white** фона: `--color FFFFFF --tolerance 40` (не жрать сталь/блики — при необходимости protect metal вручную).

### 3) Чего **не** делать (ломает край)
- **Не** раздувать outline (`MaxFilter` / «толстая чёрная обводка поверх») — жирный ореол  
- **Не** резать scissor > ~0.15 на стали (нож становится прозрачным)  
- **Не** ffmpeg `colorkey` на оранжевом огне / сером клинке, если key не чистый `#FF00FF` — съедает объект  
- ffmpeg ок **только** как pre-pass + потом тот же edge-flood cleanup (`--ffmpeg`)

### 4) В Godot
- `Sprite3D`: `transparent`, mild `alpha_scissor` ≤ 0.15 **или** disabled для ножа  
- `LINEAR_WITH_MIPMAPS` ок после hard alpha; не NEAREST если не нужен pixel look  

### 5) После cut
- Скопировать в `masters/` + строка в этой таблице  
- Игра грузит `assets/textures/<name>.png`  

---

## Viewmodel (рука игрока)

| ID | Файл в игре | Master PNG | Source (raw) | Назначение |
|----|-------------|------------|--------------|------------|
| **vm_hand_torch** | `hand_torch.png` | `masters/vm_hand_torch.png` | `masters/vm_hand_torch_source.jpg` | Левая рука + факел (FPS) |
| **vm_hand_knife** | `hand_knife.png` | `masters/vm_hand_knife.png` | `masters/vm_hand_knife_source.jpg` | Правая рука + нож (FPS) |

Код: `scripts/torch_sprites.gd` → `make_hand_torch()`.

---

## Props (мир)

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **prop_wall_torch** | `torch.png` | `masters/prop_wall_torch.png` | `masters/prop_wall_torch_source.jpg` | Факел на стене + крепёж (**одно ухо справа**) |
| **fx_flame** | `flame_only.png` | `masters/fx_flame.png` | `masters/fx_flame_source.jpg` | Только пламя (анимация tip) |
| **fx_torch_glow** | `torch_glow.png` | `masters/fx_torch_glow.png` | procedural | Soft radial glow |

Код: `scripts/torch_sprites.gd` → `make_wall_torch()`.

⚠️ **prop_wall_torch:** в игре должен быть вариант с **одним** креплением справа
(режется из `masters/prop_wall_torch_source.jpg`, белый фон):

```bash
python3 tools/sprite_cutter.py assets/textures/masters/prop_wall_torch_source.jpg \
  assets/textures/torch.png --color FFFFFF --tolerance 40 --pad 4
```

Магента-вариант из `raw/torch_raw.jpg` — это симметричная «H»-скоба с **двумя**
ушами, на стене читается неправильно. Не возвращать.

---

## Как просить изменения

- «подкрути размер vm_hand_torch» → только код / scale, **без** gen  
- «перерисуй нож» → gen **только** `vm_hand_knife`  
- «новые мобы» → gen с chromakey + `tools/sprite_cutter.py`  

---

## Источник gen (сессия)

Хорошая пачка Imagine (бело/магента фон), от которой ведём:

| Session image | → asset ID |
|---------------|------------|
| `images/8.jpg` | vm_hand_torch |
| `images/9.jpg` | vm_hand_knife |
| `images/10.jpg` | prop_wall_torch |
| `images/7.jpg` | fx_flame |

Позже magenta-пачка (`12–15` / `raw/*_raw.jpg`) — запасные, не трогаем без запроса.
