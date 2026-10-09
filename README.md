# на русском
# lua-testy-love

Форк [lua-testy](https://github.com/siffiejoe/lua-testy) с поддержкой
[LÖVE2D](https://love2d.org/).

Минималистичный фреймворк юнит-тестирования для Lua и LÖVE-игр.
Тесты пишутся **внутри** модулей как локальные функции с префиксом
`test_`, собираются автоматически через `debug`-хуки и не меняют
публичное API модуля.

**Что даёт форк:**

- запуск тестов в чистом Lua (**standalone**) — как в оригинале;
- запуск тестов **внутри LÖVE** — headless и windowed;
- **моки** для `love.*` (`timer`, `graphics`, `audio`, `filesystem`,
  `window`, `event`);
- статус **SKIP** (`testy_skip(reason)` и метка `-- testy:requires love`);
- расширенный CLI (`--mock-love`, `--no-extra`, `-r`, `-t`, `-v`, `-h`,
  `--test`, `--window`).

Философия оригинала сохранена: **минимализм**, **pure Lua**, **тесты
внутри модулей**, **никаких зависимостей** (кроме LÖVE для LÖVE-режима).

---

## Содержание

1. [Требования](#требования)
2. [Установка в вашу игру](#установка-в-вашу-игру)
3. [Написание тестов](#написание-тестов)
4. [Запуск тестов](#запуск-тестов)
5. [SKIP и метки](#skip-и-метки)
6. [Моки `love.*`](#моки-love)
7. [CLI](#cli)
8. [TAP-вывод и коды выхода](#tap-вывод-и-коды-выхода)
9. [CI (GitHub Actions, GitLab CI)](#ci)
10. [Структура фреймворка](#структура-фреймворка)
11. [Отличия от оригинала](#отличия-от-оригинала)
12. [Ограничения](#ограничения)
13. [Лицензия](#лицензия)

---

## Требования

- **Standalone:** Lua 5.1+ (5.1, 5.2, 5.3, 5.4, LuaJIT).
- **LÖVE-режим:** LÖVE 11.x.

Внешних зависимостей нет.

---

## Установка в вашу игру

> **Важно.** Просто скопировать `testy.lua` и `testy/` в корень игры
> **недостаточно**. Нужно **дополнить** свои `conf.lua` и `main.lua`,
> чтобы LÖVE знал о тестовом режиме.

### Шаг 1. Скопировать фреймворк

Скопируйте в **корень** вашей игры **два** элемента:

```
your-game/
├── testy.lua         ← скопировать
├── testy/            ← скопировать
├── conf.lua          ← у вас уже есть, дополнить
├── main.lua          ← у вас уже есть, дополнить
├── src/              ← ваш код
│   ├── player.lua
│   └── enemy.lua
└── tests/            ← создать
    └── test_player.lua
```

**Минимум для работы:** `testy.lua` + `testy/`. Без остальных файлов
фреймворк не заработает.

**Что не нужно копировать:** `examples/`, `tests/`, `module.lua`,
`main.lua`, `conf.lua` из репозитория форка — это демонстрационные
файлы, а не часть фреймворка.

### Шаг 2. Дополнить `conf.lua`

**Не заменяйте** свой `conf.lua` — **допишите** в него чтение `arg`,
чтобы LÖVE умел запускаться в headless-режиме при `--test`:

```lua
function love.conf( t )
  -- ─── Ваши обычные настройки игры ───────────────────────────
  t.window.title = "My Game"
  t.window.width = 1280
  t.window.height = 720
  t.identity = "my_game"
  -- ...

  -- ─── Добавить: обработка тестового режима ──────────────────
  local test_mode, windowed = false, false
  for _, a in ipairs( arg or {} ) do
    if a == "--test"   then test_mode = true end
    if a == "--window" then windowed  = true end
  end

  if test_mode and not windowed then
    t.window = false             -- headless: без окна
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
  end
end
```

**Зачем:** без этих строк `love . --test` создаст окно и запустит
игру как обычно, проигнорировав флаги.

**С `--window`:** окно создаётся, LÖVE работает в windowed-режиме.

### Шаг 3. Дополнить `main.lua`

**Не заменяйте** свой `main.lua`. **Добавьте** проверку тестового
режима в начале `love.load`, `love.update` и `love.draw`:

```lua
-- В самом начале main.lua:
local testy = require( "testy.love" )

function love.load( args )
  -- ─── Перехват тестового режима ─────────────────────────────
  if testy.is_test_mode( args ) then
    testy.setup( args )
    return                       -- не запускать игровую логику
  end

  -- ─── Ваша обычная инициализация ────────────────────────────
  player = require( "src.player" )
  enemy  = require( "src.enemy" )
  -- ...
end

function love.update( dt )
  -- ─── Тестовый режим: прогнать тесты и выйти ────────────────
  if testy.is_active() then
    if not testy._tests_done then
      testy.run()
      if not testy.is_windowed() then
        testy.finish()           -- headless: выход сразу
      end
    end
    return                       -- не запускать игровую логику
  end

  -- ─── Ваша игровая логика ───────────────────────────────────
  player:update( dt )
  enemy:update( dt )
  -- ...
end

function love.draw()
  -- ─── Windowed-тестовый режим ───────────────────────────────
  if testy.is_active() and testy.is_windowed() then
    love.graphics.print( "Running tests...", 10, 10 )
    if testy._tests_done then
      testy.finish()             -- выход после первого кадра
    end
    return                       -- не рисовать игру
  end

  -- ─── Ваша отрисовка ────────────────────────────────────────
  player:draw()
  enemy:draw()
  -- ...
end
```

**Зачем:**

- без `--test` игра работает как обычно;
- с `--test` игра **не** запускается — только тесты;
- в headless тесты прогоняются в первом `love.update` и LÖVE завершается;
- в windowed тесты прогоняются, окно мелькает на один кадр, выход
  в первом `love.draw`.

**Если у вас несколько файлов со `love.load`/`love.update`** —
вызывайте их только если `testy.is_active()` вернул `false`.

### Шаг 4. Создать директорию `tests/`

```
your-game/
└── tests/
    ├── test_player.lua
    └── test_enemy.lua
```

**Пример** `tests/test_player.lua`:

```lua
local player = require( "src.player" )   -- путь от корня игры

local function test_jump()
  assert( player.jump() == 10 )
end

local function test_take_damage()
  player.hp = 100
  player:take_damage( 30 )
  assert( player.hp == 70 )
end

return {}
```

Файл должен **вернуть** значение (таблицу, модуль, что угодно) — но
`return` **обязателен**, иначе тесты не соберутся (см. раздел
«Ограничения»).

### Шаг 5. Запустить тесты

```bash
cd your-game

# Headless, все тесты в tests/
love . --test -r tests/

# С окном (визуальная отладка)
love . --test --window -r tests/

# TAP-вывод (для CI)
love . --test -r -t tests/

# Один файл
love . --test tests/test_player.lua

# Обычный запуск игры (без тестов)
love .
```

### Что, если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `love . --test` запускает игру, а не тесты | В `main.lua` нет проверки `testy.is_test_mode(args)` | Шаг 3 |
| `module 'testy.love' not found` | `testy/` не в корне игры | Шаг 1 |
| Появляется окно при `--test` без `--window` | `conf.lua` не читает `arg` | Шаг 2 |
| Окно не появляется при `--test --window` | `conf.lua` не проверяет `--window` | Шаг 2 |
| `0 tests (0 ok, ...)` | Тесты в файле не возвращают значения, или файл не найден | Проверьте `return` в конце тестового файла |
| `dofile("testy.lua")` падает | LÖVE не видит `testy.lua` через `io.open` | Запускайте из корня игры: `cd your-game && love . --test ...` |

---

## Написание тестов

Тесты — это **локальные функции** с префиксом `test_`. Они собираются
автоматически при загрузке файла. Публичное API модуля **не** меняется.

### Способ 1. Тесты внутри модуля (оригинальный подход)

```lua
-- src/player.lua
local M = {}

function M.jump()
  return 10
end

-- Тесты — локальные, снаружи недоступны.
local function test_jump()
  assert( M.jump() == 10 )
  assert( M.jump() ~= 5 )
end

return M
```

**Плюс:** тесты рядом с кодом. **Минус:** тесты попадают в
production-сборку (безвредны — локальные функции собираются GC).

**Запуск:**

```bash
love . --test src/player.lua
```

### Способ 2. Тесты отдельно, в `tests/` (рекомендуется для игр)

```lua
-- tests/test_player.lua
local player = require( "src.player" )

local function test_jump()
  assert( player.jump() == 10 )
end

return {}
```

**Плюс:** тесты отделены от production-кода. **Минус:** нужно явно
`require`-ить модули.

**Запуск:**

```bash
love . --test -r tests/
```

### Ассерты

Внутри тестов используйте:

- `assert( cond, msg )` — стандартный, но перехваченный фреймворком;
- `testy_assert( cond, msg )` — работает также в helper-функциях и
  callbacks.

**Вне тестов** `assert` работает как обычно.

**Пример с helper:**

```lua
local function assert_equal( x, y, msg )
  testy_assert( x == y, msg or ( "expected " .. tostring(y) ..
                                 ", got " .. tostring(x) ) )
end

local function test_example()
  assert_equal( player.hp, 100 )
end
```

### `testy.extra`

Если `testy.extra` доступен (он рядом с `testy/`), автоматически
загружаются вспомогательные функции:

- `is( x, y )` — гибкое сравнение (с предikatами, NaN, вложенные таблицы);
- `is_eq( x, y )` — глубокое сравнение;
- `raises( p, f, ... )` — проверка, что `f(...)` бросает исключение;
- `returns( p, f, ... )` — проверка возвращаемых значений;
- `yields( f, ... )` — проверка корутин;
- `iterates( chks, f, s )` — проверка итераторов.

**Отключить:** флаг `--no-extra`.

**Пример:**

```lua
local function test_is_eq()
  assert( is_eq( { a = 1, b = { 2 } }, { a = 1, b = { 2 } } ) )
end

local function test_raises()
  local function boom() error( "oops", 0 ) end
  assert( raises( "oops", boom ) )
end
```

---

## Запуск тестов

### Standalone (чистый Lua, без LÖVE)

```bash
lua testy.lua your-module.lua
lua testy.lua tests/test_player.lua tests/test_enemy.lua
lua testy.lua -r tests/                  # рекурсивно
lua testy.lua -t tests/test_player.lua   # TAP
lua testy.lua --mock-love your-module.lua
lua testy.lua --no-extra your-module.lua
lua testy.lua -h
```

**Плюсы:** быстро, работает без LÖVE, подходит для чистой логики.

**Ограничение:** тесты, требующие `love.*`, в standalone не работают
(пропускаются с SKIP, если стоит метка `-- testy:requires love`).
С флагом `--mock-love` они выполняются с моками.

### LÖVE headless

```bash
love . --test your-module.lua
love . --test -r tests/
love . --test -t tests/test_player.lua
```

- Окно не создаётся (`t.window = false`).
- Моки `love.*` устанавливаются автоматически.
- LÖVE завершается сам после прогона.

### LÖVE windowed

```bash
love . --test --window your-module.lua
```

- Окно создаётся, реальные `love.*`.
- Окно мелькает на один кадр, LÖVE завершается.
- Моки **не** ставятся — тесты работают с реальными `love.graphics`,
  `love.audio` и т.д.

**Пишите тесты так, чтобы они работали и в headless, и в windowed.**
Например, `pcall( love.graphics.newImage, "no_such.png" )` возвращает
`false` в обоих режимах (и в моке, и в реальном LÖVE).

---

## SKIP и метки

### Явный SKIP

```lua
local function test_not_ready()
  testy_skip( "not implemented yet" )
  -- код ниже не выполнится
end
```

**Вывод:**

```
not ready ('tests/test_player.lua')
SKIP (not implemented yet)
```

В TAP:

```
ok 6 tests/test_player.lua:42 # SKIP not implemented yet
```

### Метка «требует LÖVE»

В **шапке** файла:

```lua
-- testy:requires love
```

В **standalone** (без `--mock-love`) такой файл пропускается с
пометкой `SKIP (requires LOVE)`.

В LÖVE-режиме и с флагом `--mock-love` тесты выполняются.

### Условный SKIP

```lua
local compat = require( "testy.compat" )

local function test_needs_love()
  compat.skip_if_no_love()   -- бросит SKIP, если love == nil
  assert( love ~= nil )
end
```

---

## Моки `love.*`

Моки устанавливаются в **LÖVE headless** и в **standalone с `--mock-love`**.
В LÖVE windowed и без `--mock-love` — **реальный** `love.*`.

### `love.timer`

- `getTime()` — без мутации, возвращает фиктивное время;
- `advance(dt)` — явное продвижение времени;
- `getDelta()`, `getAverageDelta()`;
- `getFPS()` — фиксировано 60;
- `sleep(sec)` — no-op.

```lua
local timer = require( "testy.mocks.timer" )
timer.install()
timer.reset()
local t0 = love.timer.getTime()
timer.advance( 0.5 )
local t1 = love.timer.getTime()
assert( t1 - t0 == 0.5 )
```

### `love.graphics`

- `newImage(path)` — проверяет существование файла, бросает ошибку
  при отсутствии;
- `newQuad(...)`, `newFont(size)` — мок-объекты;
- `draw`, `print`, `printf`, `setColor` — spy (записывают вызовы);
- `getWidth/Height` — берут значения из `love.window`;
- остальные методы — no-op.

```lua
local graphics = require( "testy.mocks.graphics" )
graphics.install()
graphics.reset()
love.graphics.draw( "sprite", 10, 20 )
local calls = graphics.get_draw_calls()
assert( #calls == 1 )
assert( calls[1][1] == "sprite" )
```

### `love.filesystem`

- `load(path)` — читает через `io`, обрабатывает shebang;
- `read(path)`, `exists(path)`, `getInfo(path)` — через `io`;
- **не затирает** реальный `love.filesystem`, если LÖVE инициализирован.

### `love.audio`

- `newSource(path)` — проверяет существование файла;
- `play` — spy;
- `stop`, `pause` — no-op.

```lua
local audio = require( "testy.mocks.audio" )
audio.install()
audio.reset()
local src = love.audio.newSource( "testy.lua", "static" )
love.audio.play( src )
assert( #audio.get_play_calls() == 1 )
```

### `love.window`

- `setMode(w, h, flags)` — мутирует состояние;
- `getMode()` — возвращает **три значения** (`w, h, flags`), как в LÖVE;
- `isVisible`, `setTitle`, `hasFocus` — заглушки.

### `love.event`

- `quit(code)` — spy: запоминает вызов, не завершает процесс;
- `uninstall()` — восстанавливает оригинальный `love.event.quit`.

```lua
local event = require( "testy.mocks.event" )
event.install()
event.reset()
love.event.quit( 1 )
assert( event.calls()[1] == 1 )
```

### Управление всеми моками

```lua
local mocks = require( "testy.mocks.init" )
mocks.install()        -- установить все моки
mocks.reset_all()      -- сбросить состояние
mocks.uninstall_all()  -- снять моки
```

Порядок установки: `timer`, `window`, `graphics`, `audio`,
`filesystem`, `event`.

---

## CLI

| Флаг | Описание | Где работает |
|---|---|---|
| `-r` | Рекурсивный обход директорий | Lua + LÖVE |
| `-t` | TAP-вывод в stdout | Lua + LÖVE |
| `-v` | Verbose | Lua + LÖVE |
| `-h`, `--help` | Справка | Lua + LÖVE |
| `--mock-love` | Установить моки `love.*` | только Lua |
| `--no-extra` | Не загружать `testy.extra` | Lua + LÖVE |
| `--test` | LÖVE-режим (только `love . --test`) | только LÖVE |
| `--window` | LÖVE windowed (только `love . --test --window`) | только LÖVE |

**Грамматика:**

```
testy.lua [flags] <files> [flags] <files> ...
```

Флаги могут идти до или после файлов.

**Примеры:**

```bash
lua testy.lua -r tests/                  # рекурсивно, все .lua
lua testy.lua -r -t tests/               # рекурсивно + TAP
lua testy.lua --mock-love tests/x.lua    # с моками
love . --test -r tests/                  # LÖVE headless
love . --test --window -r tests/         # LÖVE windowed
```

---

## TAP-вывод и коды выхода

С флагом `-t` результат выводится в формате
[TAP](http://testanything.org/):

```
# jump ('tests/test_player.lua')
ok 1 tests/test_player.lua:5
# take damage ('tests/test_player.lua')
ok 2 tests/test_player.lua:10
1..2
```

SKIP в TAP:

```
ok 3 tests/test_player.lua:20 # SKIP requires LOVE
```

**Коды выхода:**

- `0` — все тесты прошли, либо есть SKIP;
- `1` — есть FAIL или ERROR;
- в TAP-режиме (`-t`) exit code всегда `0` (по спецификации TAP).

**Проверка exit code локально:**

```bash
love . --test -r tests/
echo "exit: $?"
```

**С `prove`:**

```bash
prove --exec "lua testy.lua -t" tests/test_player.lua
```

---

## CI

Для запуска тестов в CI нужен **Xvfb** — виртуальный дисплей, потому
что LÖVE требует X-сервер, даже в headless-режиме.

### GitHub Actions

```yaml
# .github/workflows/tests.yml
name: Tests
on: [ push, pull_request ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install LÖVE and Xvfb
        run: |
          sudo apt-get update
          sudo apt-get install -y love xvfb libgl1-mesa-dri

      - name: Run tests
        run: |
          xvfb-run -a --server-args="-screen 0 1280x720x24" \
            love . --test -r -t tests/

      - name: Standalone tests (без LÖVE)
        run: |
          lua testy.lua -r -t tests/ || true
```

> `libgl1-mesa-dri` нужен, если в CI нет GPU — включится программный
> OpenGL (llvmpipe).

### GitLab CI

```yaml
# .gitlab-ci.yml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y love xvfb libgl1-mesa-dri lua5.1
  script:
    - xvfb-run -a --server-args="-screen 0 1280x720x24"
        love . --test -r -t tests/
    - lua testy.lua -r -t tests/
```

### Локальный запуск CI-команды

```bash
xvfb-run -a --server-args="-screen 0 1280x720x24" \
  love . --test -r -t tests/
```

**Проверка:** выводятся TAP-строки `ok N ...`, exit code `0`.

### Makefile

```makefile
test:
	love . --test -r -t tests/

test-windowed:
	love . --test --window -r tests/

test-standalone:
	lua testy.lua -r -t tests/

ci:
	xvfb-run -a --server-args="-screen 0 1280x720x24" \
		love . --test -r -t tests/

.PHONY: test test-windowed test-standalone ci
```

---

## Структура фреймворка

Это **внутренняя** структура фреймворка, которую вы копируете в игру:

```
testy.lua                 # CLI + патч (SKIP, cli.parse)
testy/
├── cli.lua               # парсер аргументов + рекурсивный обход
├── compat.lua            # skip_if_no_love, skip, has_love
├── extra.lua             # is, is_eq, raises, returns, yields, iterates
├── love.lua              # LÖVE-обёртка (setup, run, finish)
├── runner.lua            # общий раннер (делегирует в testy.lua)
└── mocks/
    ├── init.lua          # установка всех моков
    ├── timer.lua
    ├── window.lua
    ├── graphics.lua
    ├── audio.lua
    ├── filesystem.lua
    └── event.lua
```

`testy.lua` без `testy/` не работает. `testy/` без `testy.lua` тоже.
Копируйте **вместе**.

---

## Отличия от оригинала

| Возможность | lua-testy | lua-testy-love |
|---|---|---|
| Запуск в чистом Lua | ✅ | ✅ |
| Синтаксис тестов (`test_`, `assert`) | ✅ | ✅ |
| TAP-вывод | ✅ | ✅ |
| `testy.extra` | ✅ | ✅ |
| Рекурсивный обход `-r` | ✅ | ✅ |
| Статус SKIP | ❌ | ✅ |
| Метка `-- testy:requires love` | ❌ | ✅ |
| Запуск внутри LÖVE | ❌ | ✅ |
| Моки `love.*` | ❌ | ✅ |
| LÖVE headless | ❌ | ✅ |
| LÖVE windowed | ❌ | ✅ |
| Флаг `--mock-love` | ❌ | ✅ |

Публичное API `testy.lua` сохранено. Патч касается парсинга аргументов
(делегирование в `testy/cli.lua`) и SKIP-обработки.

---

## Ограничения

1. **Моки `love.graphics` не эмулируют рендеринг.** Проверить пиксели
   в headless нельзя. Для визуальной регрессии — Xvfb + скриншоты
   (вне скоупа фреймворка).

2. **Моки `love.audio` не воспроизводят звук.** Проверяются только
   вызовы API (spy), не сам звук.

3. **`love.timer` в моке не синхронизирован с реальным временем.**
   Используйте `advance(dt)` для детерминированного времени.

4. **`love.filesystem` в моке работает через `io`**, не через
   виртуальную ФС LÖVE. Пути реальные, относительно CWD.

5. **Headless в LÖVE — это скрытое окно** (`t.window = false`),
   не настоящий headless. GPU инициализируется. Для настоящего
   headless используйте standalone-режим.

6. **В windowed-режиме моки не ставятся.** Тесты работают с реальным
   `love.*`. Пишите тесты так, чтобы они работали в обоих режимах.

7. **`love.filesystem.exists` deprecated в LÖVE 11.5.** При
   использовании в LÖVE-режиме LÖVE выдаст warning. Используйте
   `getInfo` для чистоты или миритесь с warning.

8. **Файл теста должен возвращать значение** (обычно `return {}` или
   `return M`). Без `return` фреймворк не соберёт тесты из файла.

9. **`-r <directory>` использует `io.popen("ls ...")`** — работает
   на Linux и macOS, **не** работает на Windows. Для Windows
   перечислите файлы явно или используйте standalone-режим с
   рекурсией через `testy/cli.lua`.

10. **Моки покрывают не всё API LÖVE.** По мере необходимости
    дополняйте `testy/mocks/*.lua`.

---

## Лицензия

MIT (как и оригинал [lua-testy](https://github.com/siffiejoe/lua-testy)).

---

## Ссылки

- Оригинал: [siffiejoe/lua-testy](https://github.com/siffiejoe/lua-testy)
- Код: [Deepseek.com](https://deepseek.com)
- LÖVE2D: [love2d.org](https://love2d.org/)
- TAP: [testanything.org](http://testanything.org/)


# In English

# lua-testy-love

A fork of [lua-testy](https://github.com/siffiejoe/lua-testy) with
[LÖVE2D](https://love2d.org/) support.

A minimalist unit testing framework for Lua and LÖVE games. Tests are
written **inside** modules as local functions prefixed with `test_`,
collected automatically via `debug` hooks, and do not alter a module's
public API.

**What this fork adds:**

- run tests in plain Lua (**standalone**) — same as the original;
- run tests **inside LÖVE** — headless and windowed;
- **mocks** for `love.*` (`timer`, `graphics`, `audio`, `filesystem`,
  `window`, `event`);
- **SKIP** status (`testy_skip(reason)` and the `-- testy:requires love`
  marker);
- extended CLI (`--mock-love`, `--no-extra`, `-r`, `-t`, `-v`, `-h`,
  `--test`, `--window`).

The original philosophy is preserved: **minimalism**, **pure Lua**,
**tests inside modules**, **no dependencies** (except LÖVE for the LÖVE
mode).

---

## Contents

1. [Requirements](#requirements)
2. [Installing into your game](#installing-into-your-game)
3. [Writing tests](#writing-tests)
4. [Running tests](#running-tests)
5. [SKIP and markers](#skip-and-markers)
6. [Mocks for `love.*`](#mocks-for-love)
7. [CLI](#cli)
8. [TAP output and exit codes](#tap-output-and-exit-codes)
9. [CI (GitHub Actions, GitLab CI)](#ci)
10. [Framework structure](#framework-structure)
11. [Differences from the original](#differences-from-the-original)
12. [Limitations](#limitations)
13. [License](#license)

---

## Requirements

- **Standalone:** Lua 5.1+ (5.1, 5.2, 5.3, 5.4, LuaJIT).
- **LÖVE mode:** LÖVE 11.x.

No external dependencies.

---

## Installing into your game

> **Important.** Simply copying `testy.lua` and `testy/` into your game's
> root is **not enough**. You also need to **augment** your `conf.lua`
> and `main.lua` so LÖVE knows about the test mode.

### Step 1. Copy the framework

Copy **two** items into the **root** of your game:
your-game/
├── testy.lua ← copy
├── testy/ ← copy
├── conf.lua ← you already have this; augment it
├── main.lua ← you already have this; augment it
├── src/ ← your code
│ ├── player.lua
│ └── enemy.lua
└── tests/ ← create this
└── test_player.lua

text

**Minimum required to work:** `testy.lua` + `testy/`. Without the rest
of the files, the framework will not work.

**Do not copy:** `examples/`, `tests/`, `module.lua`, `main.lua`,
`conf.lua` from the fork's repository — these are demo files, not part
of the framework.

### Step 2. Augment your `conf.lua`

**Do not replace** your `conf.lua` — **add** the `arg` handling so
LÖVE can start in headless mode with `--test`:

lua
function love.conf( t )
  -- ─── Your usual game settings ──────────────────────────────
  t.window.title = "My Game"
  t.window.width = 1280
  t.window.height = 720
  t.identity = "my_game"
  -- ...

  -- ─── Add this: test-mode handling ──────────────────────────
  local test_mode, windowed = false, false
  for _, a in ipairs( arg or {} ) do
    if a == "--test"   then test_mode = true end
    if a == "--window" then windowed  = true end
  end

  if test_mode and not windowed then
    t.window = false             -- headless: no window
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
  end
end
Why: without these lines, love . --test will create a window and
launch the game as usual, ignoring the flags.

With --window: the window is created, LÖVE runs in windowed mode.

Step 3. Augment your main.lua
Do not replace your main.lua. Add test-mode handling at the
beginning of love.load, love.update, and love.draw:

lua
-- At the very top of main.lua:
local testy = require( "testy.love" )

function love.load( args )
  -- ─── Test-mode interception ────────────────────────────────
  if testy.is_test_mode( args ) then
    testy.setup( args )
    return                       -- do not run game logic
  end

  -- ─── Your usual initialization ─────────────────────────────
  player = require( "src.player" )
  enemy  = require( "src.enemy" )
  -- ...
end

function love.update( dt )
  -- ─── Test mode: run tests and exit ─────────────────────────
  if testy.is_active() then
    if not testy._tests_done then
      testy.run()
      if not testy.is_windowed() then
        testy.finish()           -- headless: exit immediately
      end
    end
    return                       -- do not run game logic
  end

  -- ─── Your game logic ───────────────────────────────────────
  player:update( dt )
  enemy:update( dt )
  -- ...
end

function love.draw()
  -- ─── Windowed test mode ────────────────────────────────────
  if testy.is_active() and testy.is_windowed() then
    love.graphics.print( "Running tests...", 10, 10 )
    if testy._tests_done then
      testy.finish()             -- exit after the first frame
    end
    return                       -- do not draw the game
  end

  -- ─── Your drawing ──────────────────────────────────────────
  player:draw()
  enemy:draw()
  -- ...
end
Why:

without --test the game runs as usual;

with --test the game is not launched — only tests;

in headless mode, tests run in the first love.update and LÖVE exits;

in windowed mode, tests run, the window flashes for one frame, and
LÖVE exits on the first love.draw.

If you have multiple files with love.load/love.update — call
them only when testy.is_active() returns false.

Step 4. Create the tests/ directory
text
your-game/
└── tests/
    ├── test_player.lua
    └── test_enemy.lua
Example tests/test_player.lua:

lua
local player = require( "src.player" )   -- path from the game root

local function test_jump()
  assert( player.jump() == 10 )
end

local function test_take_damage()
  player.hp = 100
  player:take_damage( 30 )
  assert( player.hp == 70 )
end

return {}
The file must return a value (a table, a module, anything) — but
the return is mandatory, otherwise tests will not be collected
(see "Limitations").

Step 5. Run tests
bash
cd your-game

# Headless, all tests in tests/
love . --test -r tests/

# With a window (visual debugging)
love . --test --window -r tests/

# TAP output (for CI)
love . --test -r -t tests/

# A single file
love . --test tests/test_player.lua

# Normal game launch (without tests)
love .
Troubleshooting
Symptom	Cause	Fix
love . --test runs the game instead of tests	main.lua lacks the testy.is_test_mode(args) check	Step 3
module 'testy.love' not found	testy/ is not in the game root	Step 1
A window appears with --test but without --window	conf.lua does not read arg	Step 2
No window appears with --test --window	conf.lua does not check for --window	Step 2
0 tests (0 ok, ...)	Tests in the file do not return a value, or the file is not found	Check for return at the end of the test file
dofile("testy.lua") fails	LÖVE cannot see testy.lua via io.open	Run from the game root: cd your-game && love . --test ...
Writing tests
Tests are local functions prefixed with test_. They are collected
automatically when the file is loaded. The module's public API is
not altered.

Option 1. Tests inside modules (original approach)
lua
-- src/player.lua
local M = {}

function M.jump()
  return 10
end

-- Tests are local, not visible from outside.
local function test_jump()
  assert( M.jump() == 10 )
  assert( M.jump() ~= 5 )
end

return M
Pros: tests next to the code. Cons: tests end up in production
builds (harmless — local functions are collected by the GC).

Run:

bash
love . --test src/player.lua
Option 2. Tests separately, in tests/ (recommended for games)
lua
-- tests/test_player.lua
local player = require( "src.player" )

local function test_jump()
  assert( player.jump() == 10 )
end

return {}
Pros: tests are separated from production code. Cons: you must
explicitly require the modules.

Run:

bash
love . --test -r tests/
Assertions
Inside tests, use:

assert( cond, msg ) — standard, but intercepted by the framework;

testy_assert( cond, msg ) — also works in helper functions and
callbacks.

Outside tests, assert behaves as usual.

Helper example:

lua
local function assert_equal( x, y, msg )
  testy_assert( x == y, msg or ( "expected " .. tostring(y) ..
                                 ", got " .. tostring(x) ) )
end

local function test_example()
  assert_equal( player.hp, 100 )
end
testy.extra
If testy.extra is available (it lives next to testy/), helper
functions are loaded automatically:

is( x, y ) — flexible comparison (with predicates, NaN, nested
tables);

is_eq( x, y ) — deep comparison;

raises( p, f, ... ) — asserts that f(...) throws;

returns( p, f, ... ) — asserts returned values;

yields( f, ... ) — asserts coroutine behavior;

iterates( chks, f, s ) — asserts iterators.

Disable with: the --no-extra flag.

Example:

lua
local function test_is_eq()
  assert( is_eq( { a = 1, b = { 2 } }, { a = 1, b = { 2 } } ) )
end

local function test_raises()
  local function boom() error( "oops", 0 ) end
  assert( raises( "oops", boom ) )
end
Running tests
Standalone (plain Lua, no LÖVE)
bash
lua testy.lua your-module.lua
lua testy.lua tests/test_player.lua tests/test_enemy.lua
lua testy.lua -r tests/                  # recursive
lua testy.lua -t tests/test_player.lua   # TAP
lua testy.lua --mock-love your-module.lua
lua testy.lua --no-extra your-module.lua
lua testy.lua -h
Pros: fast, works without LÖVE, good for pure logic.

Limitation: tests that require love.* will not run in standalone
mode (they are skipped with SKIP if the -- testy:requires love marker
is present). With the --mock-love flag, they run against mocks.

LÖVE headless
bash
love . --test your-module.lua
love . --test -r tests/
love . --test -t tests/test_player.lua
No window is created (t.window = false).

Mocks for love.* are installed automatically.

LÖVE exits by itself after the run.

LÖVE windowed
bash
love . --test --window your-module.lua
A window is created, real love.* is used.

The window flashes for one frame, then LÖVE exits.

Mocks are not installed — tests run against real love.graphics,
love.audio, etc.

Write tests so that they work in both headless and windowed modes.
For example, pcall( love.graphics.newImage, "no_such.png" ) returns
false in both modes (in the mock and in real LÖVE).

SKIP and markers
Explicit SKIP
lua
local function test_not_ready()
  testy_skip( "not implemented yet" )
  -- code below will not run
end
Output:

text
not ready ('tests/test_player.lua')
SKIP (not implemented yet)
In TAP:

text
ok 6 tests/test_player.lua:42 # SKIP not implemented yet
"Requires LÖVE" marker
At the top of the file:

lua
-- testy:requires love
In standalone mode (without --mock-love), such a file is skipped
with the SKIP (requires LOVE) note.

In LÖVE mode and with the --mock-love flag, tests run.

Conditional SKIP
lua
local compat = require( "testy.compat" )

local function test_needs_love()
  compat.skip_if_no_love()   -- throws SKIP if love == nil
  assert( love ~= nil )
end
Mocks for love.*
Mocks are installed in LÖVE headless and in standalone with
--mock-love. In LÖVE windowed and without --mock-love, real
love.* is used.

love.timer
getTime() — non-mutating, returns a fake time;

advance(dt) — explicit time advancement;

getDelta(), getAverageDelta();

getFPS() — fixed at 60;

sleep(sec) — no-op.

lua
local timer = require( "testy.mocks.timer" )
timer.install()
timer.reset()
local t0 = love.timer.getTime()
timer.advance( 0.5 )
local t1 = love.timer.getTime()
assert( t1 - t0 == 0.5 )
love.graphics
newImage(path) — checks the file's existence, errors if missing;

newQuad(...), newFont(size) — mock objects;

draw, print, printf, setColor — spies (record calls);

getWidth/Height — read from love.window;

other methods — no-op.

lua
local graphics = require( "testy.mocks.graphics" )
graphics.install()
graphics.reset()
love.graphics.draw( "sprite", 10, 20 )
local calls = graphics.get_draw_calls()
assert( #calls == 1 )
assert( calls[1][1] == "sprite" )
love.filesystem
load(path) — reads via io, strips shebang;

read(path), exists(path), getInfo(path) — via io;

does not overwrite the real love.filesystem if LÖVE is
initialized.

love.audio
newSource(path) — checks the file's existence;

play — spy;

stop, pause — no-op.

lua
local audio = require( "testy.mocks.audio" )
audio.install()
audio.reset()
local src = love.audio.newSource( "testy.lua", "static" )
love.audio.play( src )
assert( #audio.get_play_calls() == 1 )
love.window
setMode(w, h, flags) — mutates state;

getMode() — returns three values (w, h, flags), like LÖVE;

isVisible, setTitle, hasFocus — stubs.

love.event
quit(code) — spy: records the call, does not exit the process;

uninstall() — restores the original love.event.quit.

lua
local event = require( "testy.mocks.event" )
event.install()
event.reset()
love.event.quit( 1 )
assert( event.calls()[1] == 1 )
Managing all mocks
lua
local mocks = require( "testy.mocks.init" )
mocks.install()        -- install all mocks
mocks.reset_all()      -- reset state
mocks.uninstall_all()  -- remove mocks
Installation order: timer, window, graphics, audio,
filesystem, event.

CLI
Flag	Description	Where it works
-r	Recursive directory traversal	Lua + LÖVE
-t	TAP output to stdout	Lua + LÖVE
-v	Verbose	Lua + LÖVE
-h, --help	Help	Lua + LÖVE
--mock-love	Install love.* mocks	Lua only
--no-extra	Do not load testy.extra	Lua + LÖVE
--test	LÖVE mode (only love . --test)	LÖVE only
--window	LÖVE windowed (only love . --test --window)	LÖVE only
Grammar:

text
testy.lua [flags] <files> [flags] <files> ...
Flags may appear before or after file names.

Examples:

bash
lua testy.lua -r tests/                  # recursive, all .lua
lua testy.lua -r -t tests/               # recursive + TAP
lua testy.lua --mock-love tests/x.lua    # with mocks
love . --test -r tests/                  # LÖVE headless
love . --test --window -r tests/         # LÖVE windowed
TAP output and exit codes
With the -t flag, output is produced in
TAP format:

text
# jump ('tests/test_player.lua')
ok 1 tests/test_player.lua:5
# take damage ('tests/test_player.lua')
ok 2 tests/test_player.lua:10
1..2
SKIP in TAP:

text
ok 3 tests/test_player.lua:20 # SKIP requires LOVE
Exit codes:

0 — all tests passed, or there are SKIPs;

1 — there is a FAIL or ERROR;

in TAP mode (-t) exit code is always 0 (per the TAP spec).

Check the exit code locally:

bash
love . --test -r tests/
echo "exit: $?"
With prove:

bash
prove --exec "lua testy.lua -t" tests/test_player.lua
CI
To run tests in CI you need Xvfb — a virtual display — because LÖVE
requires an X server, even in headless mode.

GitHub Actions
yaml
# .github/workflows/tests.yml
name: Tests
on: [ push, pull_request ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install LÖVE and Xvfb
        run: |
          sudo apt-get update
          sudo apt-get install -y love xvfb libgl1-mesa-dri

      - name: Run tests
        run: |
          xvfb-run -a --server-args="-screen 0 1280x720x24" \
            love . --test -r -t tests/

      - name: Standalone tests (without LÖVE)
        run: |
          lua testy.lua -r -t tests/ || true
libgl1-mesa-dri is needed if the CI has no GPU — it enables
software OpenGL (llvmpipe).

GitLab CI
yaml
# .gitlab-ci.yml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update
    - apt-get install -y love xvfb libgl1-mesa-dri lua5.1
  script:
    - xvfb-run -a --server-args="-screen 0 1280x720x24"
        love . --test -r -t tests/
    - lua testy.lua -r -t tests/
Running the CI command locally
bash
xvfb-run -a --server-args="-screen 0 1280x720x24" \
  love . --test -r -t tests/
Expect: TAP lines ok N ... printed, exit code 0.

Makefile
makefile
test:
	love . --test -r -t tests/

test-windowed:
	love . --test --window -r tests/

test-standalone:
	lua testy.lua -r -t tests/

ci:
	xvfb-run -a --server-args="-screen 0 1280x720x24" \
		love . --test -r -t tests/

.PHONY: test test-windowed test-standalone ci
Framework structure
This is the internal structure of the framework you copy into your
game:

text
testy.lua                 # CLI + patch (SKIP, cli.parse)
testy/
├── cli.lua               # argument parser + recursive traversal
├── compat.lua            # skip_if_no_love, skip, has_love
├── extra.lua             # is, is_eq, raises, returns, yields, iterates
├── love.lua              # LÖVE wrapper (setup, run, finish)
├── runner.lua            # common runner (delegates to testy.lua)
└── mocks/
    ├── init.lua          # installs all mocks
    ├── timer.lua
    ├── window.lua
    ├── graphics.lua
    ├── audio.lua
    ├── filesystem.lua
    └── event.lua
testy.lua does not work without testy/. testy/ does not work
without testy.lua. Copy them together.

Differences from the original
Feature	lua-testy	lua-testy-love
Runs in plain Lua	✅	✅
Test syntax (test_, assert)	✅	✅
TAP output	✅	✅
testy.extra	✅	✅
Recursive traversal -r	✅	✅
SKIP status	❌	✅
-- testy:requires love marker	❌	✅
Runs inside LÖVE	❌	✅
Mocks for love.*	❌	✅
LÖVE headless	❌	✅
LÖVE windowed	❌	✅
--mock-love flag	❌	✅
The public API of testy.lua is preserved. The patch only affects
argument parsing (delegated to testy/cli.lua) and SKIP handling.

Limitations
Mocks for love.graphics do not emulate rendering. You cannot
verify pixels in headless mode. For visual regression, use
Xvfb + screenshots (outside the framework's scope).

Mocks for love.audio do not play sound. Only API calls are
verified (spies), not the actual audio.

love.timer in the mock is not synchronized with real time.
Use advance(dt) for deterministic time.

love.filesystem in the mock uses io, not LÖVE's virtual
filesystem. Paths are real, relative to the CWD.

Headless in LÖVE is a hidden window (t.window = false), not
true headless. The GPU is still initialized. For true headless,
use standalone mode.

In windowed mode mocks are not installed. Tests run against
real love.*. Write tests so they work in both modes.

love.filesystem.exists is deprecated in LÖVE 11.5. When used
in LÖVE mode, LÖVE emits a warning. Use getInfo for cleanliness
or accept the warning.

A test file must return a value (usually return {} or
return M). Without a return, the framework will not collect
tests from the file.

-r <directory> uses io.popen("ls ...") — works on Linux
and macOS, does not work on Windows. On Windows, list files
explicitly or use standalone mode via testy/cli.lua.

Mocks do not cover all of LÖVE's API. Extend
testy/mocks/*.lua as needed.

License
MIT (same as the original
lua-testy).

Links
Original: siffiejoe/lua-testy
Code: deepseek.com
LÖVE2D: love2d.org


