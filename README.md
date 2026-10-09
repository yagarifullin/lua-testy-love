# lua-testy-love

Форк [lua-testy](https://github.com/siffiejoe/lua-testy) с поддержкой
[LÖVE2D](https://love2d.org/).

**lua-testy** — минималистичный фреймворк для юнит-тестирования Lua-модулей.
Тесты пишутся **внутри** модулей как локальные функции с префиксом `test_`,
собираются через `debug`-хуки и выполняются без изменения публичного API
модуля.

**lua-testy-love** добавляет:

- запуск тестов **внутри** LÖVE-приложения (headless и windowed);
- **моки** для `love.*` API (`timer`, `graphics`, `audio`, `filesystem`,
  `window`, `event`);
- статус **SKIP** (`testy_skip(reason)` и метка `-- testy:requires love`);
- расширенный CLI (`--mock-love`, `--no-extra`, `-r`, `-t`, `-v`, `-h`,
  `--test`, `--window`).

Философия оригинала сохранена: **минимализм**, **pure Lua**, **тесты
внутри модулей**, **отсутствие внешних зависимостей** (кроме LÖVE для
LÖVE-режима).

---

## Оглавление

1. [Установка](#установка)
2. [Структура проекта](#структура-проекта)
3. [Быстрый старт](#быстрый-старт)
   - [Standalone-режим](#standalone-режим)
   - [LÖVE headless](#löve-headless)
   - [LÖVE windowed](#löve-windowed)
4. [Как писать тесты](#как-писать-тесты)
5. [SKIP и метки](#skip-и-метки)
6. [Моки `love.*`](#моки-love)
7. [CLI](#cli)
8. [TAP-вывод](#tap-вывод)
9. [Коды выхода](#коды-выхода)
10. [Отличия от оригинала](#отличия-от-оригинала)
11. [Ограничения](#ограничения)
12. [Лицензия](#лицензия)

---

## Установка

**Требования:**

- **Standalone:** Lua 5.1+ (5.1, 5.2, 5.3, 5.4, LuaJIT).
- **LÖVE-режим:** LÖVE 11.x.

**Установка:**

Скопируйте `testy.lua` и директорию `testy/` в свой проект.
your-project/
├── testy.lua
├── testy/
│ ├── cli.lua
│ ├── compat.lua
│ ├── extra.lua
│ ├── love.lua
│ ├── runner.lua
│ └── mocks/
│ ├── init.lua
│ ├── timer.lua
│ ├── window.lua
│ ├── graphics.lua
│ ├── audio.lua
│ ├── filesystem.lua
│ └── event.lua
└── your-module.lua

text

Никаких `luarocks`, `pip`, `npm` — **только** файлы.

---

## Структура проекта

Полная структура **форка** (как эталонный пример):
lua-testy-love/
├── conf.lua # LÖVE-конфиг (читает --window из arg)
├── main.lua # LÖVE-точка входа
├── module.lua # демонстрационный модуль с тестами
├── testy.lua # CLI-обёртка + патч (SKIP, cli.parse)
├── README.md
├── testy/ # модули фреймворка
│ ├── cli.lua # парсер аргументов + рекурсивный обход
│ ├── compat.lua # skip_if_no_love, skip, has_love
│ ├── extra.lua # оригинал testy.extra (is, is_eq, raises, ...)
│ ├── love.lua # LÖVE-обёртка (setup, run, finish)
│ ├── runner.lua # общий раннер (делегирует в testy.lua)
│ └── mocks/ # моки love.* API
│ ├── init.lua # установка всех моков в фиксированном порядке
│ ├── timer.lua # love.timer
│ ├── window.lua # love.window
│ ├── graphics.lua # love.graphics
│ ├── audio.lua # love.audio
│ ├── filesystem.lua # love.filesystem
│ └── event.lua # love.event
├── examples/ # примеры использования
│ ├── standalone.lua # обычные тесты без LÖVE
│ ├── skip_demo.lua # пример testy_skip
│ └── requires_love.lua # пример метки -- testy:requires love
└── tests/ # тесты самого форка
├── test_extra.lua # тесты testy.extra
├── test_mocks_timer.lua
├── test_mocks_window.lua
├── test_mocks_graphics.lua
├── test_mocks_audio.lua
├── test_mocks_filesystem.lua
└── test_mocks_event.lua

text

---

## Быстрый старт

### Standalone-режим

Работает **без** LÖVE, в чистом Lua.

```bash
# Один файл
lua testy.lua your-module.lua

# Несколько файлов
lua testy.lua module1.lua module2.lua

# Рекурсивный обход директории
lua testy.lua -r tests/

# TAP-вывод (для prove и других TAP-консьюмеров)
lua testy.lua -t your-module.lua

# С моками love.* (позволяет тестировать LÖVE-зависимый код без LÖVE)
lua testy.lua --mock-love your-module.lua

# Не грузить testy.extra
lua testy.lua --no-extra your-module.lua

# Справка
lua testy.lua -h
Пример вывода:

text
add ('your-module.lua') ..
mul ('your-module.lua') ..
4 tests (4 ok, 0 failed, 0 errors, 0 skipped)
LÖVE headless
Запускается внутри LÖVE. Окно не показывается
(t.window = false в conf.lua). Моки love.* устанавливаются
автоматически.

conf.lua:

lua
function love.conf( t )
  local windowed = false
  for _, a in ipairs( arg or {} ) do
    if a == "--window" then windowed = true; break end
  end

  if windowed then
    t.window = { width = 800, height = 600, title = "lua-testy-love" }
  else
    t.window = false
  end

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.identity = "lua_testy_love"
end
main.lua:

lua
local testy = require( "testy.love" )

function love.load( args )
  if testy.is_test_mode( args ) then
    testy.setup( args )
    return
  end
  -- обычная инициализация приложения
end

function love.update( dt )
  if testy.is_active() and not testy._tests_done then
    testy.run()
    if not testy.is_windowed() then
      testy.finish()
    end
  end
end

function love.draw()
  if testy.is_active() and testy.is_windowed() then
    love.graphics.print( "Running tests...", 10, 10 )
    if testy._tests_done then
      testy.finish()
    end
  end
end
Запуск:

bash
# Тесты из конкретных файлов
love . --test your-module.lua

# Рекурсивный обход директории
love . --test -r tests/

# TAP-вывод
love . --test -t your-module.lua
Пример вывода:

text
screen size ('module.lua') ...
new image missing ('module.lua') .
play sound missing ('module.lua') .
5 tests (5 ok, 0 failed, 0 errors, 0 skipped)
LÖVE сам завершается после прогона (обычно < 1 сек).

LÖVE windowed
То же самое, но с окном. Полезно для визуальной отладки.

bash
love . --test --window your-module.lua
Окно появится на один кадр, тесты прогонятся, LÖVE завершится.

Отличие от headless:

love.graphics — реальный, не мок.

love.audio — реальный.

love.filesystem — реальный.

love.window — реальный.

Моки не ставятся.

Поэтому: тесты, требующие существующих файлов (изображений, звуков),
в headless проходят с моками, а в windowed — падают, если файлов нет.
Пишите тесты так, чтобы они работали в обоих режимах.

Как писать тесты
Тесты — это локальные функции с префиксом test_. Они собираются
автоматически через debug-хуки при загрузке модуля. Публичное API
модуля не меняется.

Пример your-module.lua:

lua
local M = {}

function M.add( a, b )
  return a + b
end

function M.mul( a, b )
  return a * b
end

-- Тесты ниже — локальные, недоступны снаружи.
-- Если модуль загружен через `require`, они выйдут из области видимости
-- и будут собраны GC. Никакого оверхеда в production.

local function test_add()
  assert( M.add( 1, 2 ) == 3 )
  assert( M.add( -1, 1 ) == 0 )
  assert( M.add( 0, 0 ) == 0 )
end

local function test_mul()
  assert( M.mul( 2, 3 ) == 6 )
  assert( M.mul( 0, 5 ) == 0 )
  assert( M.mul( -1, 5 ) == -5 )
end

return M
Запуск:

bash
lua testy.lua your-module.lua
Вывод:

text
add ('your-module.lua') ...
mul ('your-module.lua') ...
6 tests (6 ok, 0 failed, 0 errors, 0 skipped)
Ассерты:

Используйте обычный assert( cond, msg ) или testy_assert( cond, msg ).
Оба работают внутри тестов и не завершают программу при провале.
Вне тестов assert работает как обычно.

Если нужен assert в helper-функции или callback — используйте
testy_assert:

lua
local function assert_equal( x, y )
  testy_assert( x == y, "values differ" )
end

local function test_example()
  assert_equal( 1, 1 )
end
SKIP и метки
Явный SKIP
lua
local function test_not_ready()
  testy_skip( "not implemented yet" )
  -- код ниже не выполнится
end
Вывод:

text
not ready ('your-module.lua')
SKIP (not implemented yet)
Метка «требует LÖVE»
В шапке файла:

lua
-- testy:requires love
В standalone (без --mock-love) такой файл пропускается с
пометкой SKIP (requires LOVE).

В --mock-love и в LÖVE-режиме — тесты выполняются.

Условный SKIP
lua
local compat = require( "testy.compat" )

local function test_needs_love()
  compat.skip_if_no_love()
  assert( love ~= nil )
end
skip_if_no_love() бросает SKIP, если love == nil.

Моки love.*
Моки устанавливаются в LÖVE headless и standalone с --mock-love.
В windowed LÖVE и без --mock-love — реальные love.*.

love.timer
getTime() — без мутации (возвращает текущее фиктивное время).

advance(dt) — явное продвижение времени.

getDelta(), getAverageDelta() — последнее / среднее.

getFPS() — фиксировано 60.

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
newImage(path) — проверяет существование файла, бросает при отсутствии.

newQuad(...) — мок-объект с getViewport.

newFont(size) — мок с getWidth, getHeight.

draw, print, printf — spy: записывают вызовы в список.

setColor — spy.

getWidth/Height — читают из love.window.

Остальные методы (rectangle, line, circle, ...) — no-op.

lua
local graphics = require( "testy.mocks.graphics" )
graphics.install()
graphics.reset()
love.graphics.draw( "sprite", 10, 20 )
local calls = graphics.get_draw_calls()
assert( #calls == 1 )
assert( calls[1][1] == "sprite" )
love.filesystem
load(path) — читает через io, обрабатывает shebang.

read(path) — читает через io.

exists(path) — проверка через io.

getInfo(path) — {type = "file"} или {type = "directory"}.

Не затирает реальный love.filesystem, если LÖVE уже инициализирован.

love.audio
newSource(path) — проверяет существование файла.

play — spy.

stop, pause — no-op.

lua
local audio = require( "testy.mocks.audio" )
audio.install()
audio.reset()
local src = love.audio.newSource( "testy.lua", "static" )
love.audio.play( src )
assert( #audio.get_play_calls() == 1 )
love.window
setMode(w, h, flags) — мутирует состояние.

getMode() — возвращает три значения (w, h, flags), как в LÖVE.

isVisible, setTitle, hasFocus — заглушки.

love.event
quit(code) — spy: запоминает вызов, не завершает процесс.

uninstall() — восстанавливает оригинальный love.event.quit (если был).

lua
local event = require( "testy.mocks.event" )
event.install()
event.reset()
love.event.quit( 1 )
assert( event.calls()[1] == 1 )
Управление моками
lua
local mocks = require( "testy.mocks.init" )
mocks.install()       -- установить все моки (в фиксированном порядке)
mocks.reset_all()     -- сбросить состояние всех моков
mocks.uninstall_all() -- снять моки (восстановить оригиналы, где возможно)
Порядок установки: timer, window, graphics, audio,
filesystem, event.

CLI
Флаг	Описание
-r	Рекурсивный обход директорий в поисках *.lua
-t	TAP-вывод (в stdout)
-v	Verbose
-h, --help	Справка
--mock-love	Установить моки love.* (только standalone)
--no-extra	Не загружать testy.extra
--test	LÖVE-режим (только для love . --test)
--window	LÖVE windowed (только для love . --test --window)
Грамматика:

text
testy.lua [flags] <files> [flags] <files> ...
Флаги могут идти до или после файлов. Порядок не важен.

Приоритеты:

-h перебивает всё — показывает справку, выходит с кодом 0.

-t совместим с -r и -v.

--test и --window имеют смысл только внутри love.

TAP-вывод
С флагом -t фреймворк выводит результат в формате
TAP:

text
# screen size ('module.lua')
ok 1 module.lua:21
ok 2 module.lua:22
ok 3 module.lua:23
# new image missing ('module.lua')
ok 4 module.lua:29
# play sound missing ('module.lua')
ok 5 module.lua:35
1..5
Совместим с prove:

bash
prove --exec "lua testy.lua -t" your-module.lua
SKIP в TAP:

text
ok 6 your-module.lua:42 # SKIP not implemented yet
Коды выхода
0 — все тесты прошли или есть SKIP.

1 — есть FAIL или ERROR.

Для TAP-режима exit code всегда 0, даже при FAIL (это требование TAP —
консьюмер сам читает вывод).

Отличия от оригинала
Возможность	lua-testy	lua-testy-love
Запуск в чистом Lua	✅	✅
Синтаксис тестов (test_, assert)	✅	✅
TAP-вывод	✅	✅
testy.extra	✅	✅
Рекурсивный обход -r	✅	✅
Статус SKIP	❌	✅
Метка -- testy:requires love	❌	✅
Запуск внутри LÖVE	❌	✅
Моки love.*	❌	✅
LÖVE headless	❌	✅
LÖVE windowed	❌	✅
Флаг --mock-love	❌	✅
Публичное API testy.lua сохранено. Патч касается только парсинга
аргументов (делегирование в testy/cli.lua) и SKIP-обработки.

Ограничения
Моки love.graphics не эмулируют рендеринг. Проверить пиксели
в headless нельзя. Для визуальной регрессии — Xvfb + скриншоты
(вне скоупа).

Моки love.audio не воспроизводят звук. Проверяются только
вызовы API (spy), не сам звук.

love.timer в моке не синхронизирован с реальным временем.
Тесты, зависящие от реального FPS, будут врать. Используйте
advance(dt) для детерминированного времени.

love.filesystem в моке работает через io, не через
виртуальную ФС LÖVE. Пути — реальные, относительно CWD.

Headless в LÖVE — это скрытое окно (t.window = false), не
настоящий headless. GPU инициализируется. Для настоящего headless
используйте standalone-режим.

love.filesystem.exists deprecated в LÖVE 11.5. При использовании
в LÖVE-режиме LÖVE выдаст warning. Используйте getInfo для чистоты.

В windowed-режиме моки не ставятся. Тесты, требующие моков
(например, newImage с несуществующим файлом), в windowed будут
падать иначе, чем в headless. Пишите тесты так, чтобы они работали
в обоих режимах.

Моки покрывают не всё API LÖVE. По мере необходимости — дополнять.

Лицензия
MIT (как и оригинал lua-testy).

Ссылки
Оригинал: siffiejoe/lua-testy

LÖVE2D: love2d.org

TAP: testanything.org
