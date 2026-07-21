# Texture assets — catalog

**Правило:** эти ассеты **канонические**.  
Новые картинки рисуем **только когда явно попросишь**.  
Не перегенерировать «на всякий случай».

Cut tool: `tools/sprite_cutter.py` (chromakey / edge flood).  
Masters (исходники + готовые PNG): `assets/textures/masters/`.

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
| **prop_wall_torch** | `torch.png` | `masters/prop_wall_torch.png` | `masters/prop_wall_torch_source.jpg` | Факел на стене + крепёж |
| **fx_flame** | `flame_only.png` | `masters/fx_flame.png` | `masters/fx_flame_source.jpg` | Только пламя (анимация tip) |
| **fx_torch_glow** | `torch_glow.png` | `masters/fx_torch_glow.png` | procedural | Soft radial glow |

Код: `scripts/torch_sprites.gd` → `make_wall_torch()`.

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
