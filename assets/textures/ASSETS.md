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

### 2) Cut — `tools/sprite_cutter.py --ffmpeg` (предпочтительно)

```bash
python3 tools/sprite_cutter.py src.jpg out.png --color FFFFFF --tolerance 55 --pad 4 --ffmpeg
```

ffmpeg `colorkey` снимает альфу аккуратнее по сглаженному краю, чем flood.
Раньше его было нельзя (он keyит **весь кадр** и выедал светлое ядро пламени /
блики на стали), теперь дыры лечатся: `restore_interior()` заливает прозрачность
от рамки, и всё, что не связано с фоном, получает непрозрачность обратно.

Крутилки: `--ff-similarity` (по умолчанию 0.20, больше = агрессивнее),
`--ff-blend` (0.05). При 0.35 на белом фоне выедало ~7000 px пламени.

**Замер качества** (светлые пиксели по контуру — должно быть <2%):

```bash
python3 - <<'PY'
from PIL import Image
im=Image.open('assets/textures/torch.png').convert('RGBA'); w,h=im.size; px=im.load()
b=e=0
for y in range(h):
    for x in range(w):
        r,g,bl,a=px[x,y]
        if a==0: continue
        if any(not(0<=x+dx<w and 0<=y+dy<h) or px[x+dx,y+dy][3]==0
               for dx,dy in((1,0),(-1,0),(0,1),(0,-1))):
            e+=1
            if min(r,g,bl)>190: b+=1
print(f'{b}/{e} = {100*b/e:.1f}%')
PY
```

### 2b) Cut — flood без ffmpeg (запасной)
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
- **hand_torch / hand_knife / flame_only не перерезать из `masters/*_source.jpg`** — там фон не чистый белый (угол `(6,5,3)`), выйдет хуже. В игре они уже 0% каймы, резаны из магента-раёв.

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

## Heroes (портреты, батч 1)

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **hero_kael** | `hero_kael.png` | `masters/hero_kael.png` | `masters/hero_kael_source.jpg` | Каэль, паладин / танк |
| **hero_lyra** | `hero_lyra.png` | `masters/hero_lyra.png` | `masters/hero_lyra_source.jpg` | Лира, охотница / DPS |
| **hero_sera** | `hero_sera.png` | `masters/hero_sera.png` | `masters/hero_sera_source.jpg` | Сера, огненный маг / AoE |

Фон gen: `#FF00FF`. Cut: `--color FF00FF --ffmpeg --erode-light 2`.  
Без рамок; круглый crop делает UI.

---

## Cards (иллюстрации, батч 1)

**Только art.** Рамку, название, ⚡ cost рисует движок — в PNG нет цифр/рамки.

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **card_slice** | `card_slice.png` | `masters/card_slice.png` | `masters/card_slice_source.jpg` | Slice — удар кинжалом |
| **card_block** | `card_block.png` | `masters/card_block.png` | `masters/card_block_source.jpg` | Block — щит + барьер |
| **card_firebolt** | `card_firebolt.png` | `masters/card_firebolt.png` | `masters/card_firebolt_source.jpg` | Firebolt — огненная стрела |
| **card_blood_lash** | `card_blood_lash.png` | `masters/card_blood_lash.png` | `masters/card_blood_lash_source.jpg` | Blood Lash — кровавый хлыст |
| **card_bone_rattle** | `card_bone_rattle.png` | `masters/card_bone_rattle.png` | `masters/card_bone_rattle_source.jpg` | Bone Rattle — кость на шнуре |

Промпты: `docs/ART_PROMPTS.md` §2.  
Качество cut (bright edge): все **≤0.3%**.

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
  assets/textures/torch.png --color FFFFFF --tolerance 55 --pad 4 --ffmpeg
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
