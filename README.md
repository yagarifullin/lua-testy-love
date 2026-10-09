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
- LÖVE2D: [love2d.org](https://love2d.org/)
- TAP: [testanything.org](http://testanything.org/)
