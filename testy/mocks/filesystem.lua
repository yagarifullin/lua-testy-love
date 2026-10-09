-- Мок love.filesystem. Не затирает реальный (если LÖVE уже инициализирован).
local M = {}

local load_chunk = loadstring or load  -- Lua 5.1: loadstring, 5.2+: load

local function io_read( path )
  local f = io.open( path, "r" )
  if not f then return nil end
  local content = f:read( "*a" )
  f:close()
  return content
end

local function io_exists( path )
  local f = io.open( path, "r" )
  if f then f:close() return true end
  return false
end

function M.install()
  _G.love = _G.love or {}

  -- Патч: если love.filesystem уже есть (LÖVE-режим), не трогаем.
  if love.filesystem then
    return
  end

  love.filesystem = {}

  love.filesystem.load = function( path )
    local content = io_read( path )
    if not content then return nil, "file not found: " .. path end
    -- Lua 5.1 loadstring не понимает shebang (#!...).
    content = content:gsub( "^#[^\n]*\n", "" )
    return load_chunk( content, "@" .. path )
  end

  love.filesystem.exists = function( path )
    return io_exists( path )
  end

  love.filesystem.read = function( path )
    return io_read( path )
  end

  love.filesystem.write = function( path, data )
    local f = io.open( path, "w" )
    if not f then return false end
    f:write( data )
    f:close()
    return true
  end

  love.filesystem.getInfo = function( path )
    if io_exists( path ) then
      return { type = "file" }
    end
    local f = io.open( path .. "/.", "r" )
    if f then f:close() return { type = "directory" } end
    return nil
  end

  love.filesystem.getDirectoryItems = function( path )
    return {}
  end

  love.filesystem.createDirectory = function() return true end
  love.filesystem.remove = function() return true end
  love.filesystem.getSaveDirectory = function() return "." end
  love.filesystem.getSource = function() return "." end
  love.filesystem.getSourceBaseDirectory = function() return "." end
end

return M
