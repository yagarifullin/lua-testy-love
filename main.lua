-- LÖVE-точка входа для lua-testy-love.
-- Запуск: `love . --test <files>` (headless) или `love . --test --window <files>`.

local testy = require( "testy.love" )

function love.load( args )
  -- args — это arg, переданный LÖVE.
  if testy.is_test_mode( args ) then
    testy.setup( args )
    return
  end
  -- Если --test не передан — приложение работает как обычно.
  -- Для lua-testy-love это означает: ничего не делать.
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
  -- В windowed-режиме показываем минимальное окно и выходим после первого кадра.
  if testy.is_active() and testy.is_windowed() then
    love.graphics.print( "lua-testy-love: running tests...", 10, 10 )
    if testy._tests_done then
      testy.finish()
    end
  end
end
