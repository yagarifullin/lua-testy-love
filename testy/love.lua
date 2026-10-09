-- LÖVE-обёртка. Запускает тесты внутри LÖVE.
local M = {}

M._active = false
M._windowed = false
M._tests_done = false
M._opts = nil
M._stats = nil

-- Проверяет, передан ли --test в arg.
function M.is_test_mode( args )
  args = args or _G.arg or {}
  for _, a in ipairs( args ) do
    if a == "--test" then return true end
  end
  return false
end

-- Установка. Вызывается в love.load.
function M.setup( args )
  M._opts = require( "testy.cli" ).parse( args or _G.arg or {} )
  M._active = true
  M._windowed = M._opts.window
  M._tests_done = false

  -- Ставим моки, если headless.
  if not M._windowed then
    local ok, init = pcall( require, "testy.mocks.init" )
    if ok and init and init.install then init.install() end
  end

  -- Автозагрузка testy.extra (если не отключена).
  if not M._opts.no_extra then
    pcall( require, "testy.extra" )
  end
end

function M.is_active()
  return M._active
end

function M.is_windowed()
  return M._windowed
end

-- Запуск тестов. Возвращает stats.
function M.run()
  if M._tests_done then return M._stats end
  M._tests_done = true

  local runner = require( "testy.runner" )

  -- Восстанавливаем реальный love.event.quit перед финалом.
  local event_mock = require( "testy.mocks.event" )

  local opts = M._opts or {}
  opts.mock_love = not M._windowed
  opts.test_mode = true

  M._stats = runner.run( opts )
  return M._stats
end

-- Финализация: выход.
function M.finish()
  local code = 0
  if M._stats and M._stats.exit_code then
    code = M._stats.exit_code
  end

  if not M._windowed then
    local event_mock = require( "testy.mocks.event" )
    event_mock.uninstall()
  end

  if _G.love and love.event and love.event.quit then
    love.event.quit( code )
  else
    os.exit( code, true )
  end
end

-- Хелпер для синхронного скриншота (используется в screenshot-тестах).
function M.capture_sync()
  if not (_G.love and love.graphics and love.graphics.captureScreenshot) then
    return nil
  end
  local captured = nil
  love.graphics.captureScreenshot( function( img ) captured = img end )
  local tries = 0
  while not captured and tries < 100 do
    if love.event and love.event.pump then love.event.pump() end
    if love.timer and love.timer.step then love.timer.step() end
    tries = tries + 1
  end
  return captured
end

return M
