-- Пример standalone-тестов (без LÖVE).
-- Запуск: lua testy.lua examples/standalone.lua

local M = {}

function M.add( a, b )
  return a + b
end

function M.mul( a, b )
  return a * b
end

local function test_add()
  assert( M.add( 1, 2 ) == 3 )
  assert( M.add( -1, 1 ) == 0 )
end

local function test_mul()
  assert( M.mul( 2, 3 ) == 6 )
  assert( M.mul( 0, 5 ) == 0 )
end

return M
