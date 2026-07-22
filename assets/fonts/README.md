# Fonts

| Файл | Где | Лицензия |
|---|---|---|
| `Cinzel.ttf` | названия карт, заголовки, кнопки | SIL OFL 1.1 — `OFL-Cinzel.txt` |
| `MedievalSharp.ttf` | флейвор-текст | SIL OFL 1.1 — `OFL-MedievalSharp.txt` |

Источник: [google/fonts](https://github.com/google/fonts) (`ofl/cinzel`, `ofl/medievalsharp`).
OFL разрешает коммерческое использование и включение в игру. Тексты лицензий
лежат рядом — **не удалять**, это условие лицензии.

Подключение — `scripts/ui/ui_theme.gd`.

⚠️ Правила карт и цифры HP набирать **Cinzel**, не MedievalSharp: рукописная
гарнитура разваливается ниже ~13px, а описание эффекта у нас 10px.
