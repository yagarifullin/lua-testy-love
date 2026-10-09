local filesystem = require( "testy.mocks.filesystem" )

local function test_load()
  filesystem.install()
  local f, err = love.filesystem.load( "testy.lua" )
  assert( f ~= nil, err )
end

local function test_exists()
  filesystem.install()
  assert( love.filesystem.exists( "testy.lua" ) )
  assert( not love.filesystem.exists( "no_such_file_xyz.lua" ) )
end

local function test_read()
  filesystem.install()
  local content = love.filesystem.read( "testy.lua" )
  assert( type( content ) == "string" )
  assert( #content > 0 )
end

local function test_getInfo()
  filesystem.install()
  local info = love.filesystem.getInfo( "testy.lua" )
  assert( info ~= nil )
  assert( info.type == "file" )
end

return {}
