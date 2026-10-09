-- Тесты автозагрузки testy.extra в LÖVE-режиме.
-- В standalone testy.extra тоже доступен (загружается testy.lua).

local function test_extra_available()
  assert( type( is ) == "function", "is not available" )
  assert( type( is_eq ) == "function", "is_eq not available" )
  assert( is( 1, 1 ) )
  assert( is_eq( {a=1}, {a=1} ) )
end

local function test_extra_is()
  assert( is( 3, 3 ) )
  assert( is( 3 )( 3 ) )
  assert( not is( 3, 4 ) )
  assert( is( 0/0, 0/0 ) )
end

local function test_extra_is_eq()
  assert( is_eq( { 1 }, { 1 } ) )
  assert( is_eq( 0/0, 0/0 ) )
  assert( not is_eq( { 1 }, {} ) )
end

local function test_extra_raises()
  local function f() error( "boom", 0 ) end
  assert( raises( "boom", f ) )
  assert( not raises( "other", f ) )
end

local function test_extra_returns()
  local function f() return 1, "a" end
  assert( returns( 1, f ) )
  assert( returns( resp( 1, "a" ), f ) )
end

local function test_extra_yields()
  local function f()
    local x = coroutine.yield( 1 )
    return x + 1
  end
  assert( yields( f, { 1 }, 1, { 5 }, 6 ) )
end

local function test_extra_iterates()
  assert( iterates( { 1, 2, 3 }, ipairs( { 1, 2, 3 } ) ) )
end

return {}
