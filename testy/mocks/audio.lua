-- Мок love.audio. Spy на play.
local M = {}
local play_calls = {}

function M.install()
_G.love = _G.love or {}
love.audio = love.audio or {}

local source_mock = {
    play = function(self) play_calls[#play_calls+1] = self end,
    stop = function() end,
    pause = function() end,
    setVolume = function() end,
    getVolume = function() return 1 end,
    setLooping = function() end,
    isPlaying = function() return false end,
    setPitch = function() end,
    getPitch = function() return 1 end,
    clone = function(self) return self end,
    type = function() return "Source" end,
}

love.audio.newSource = function( path, stype )
  -- Проверяем существование файла (как реальный LÖVE).
  -- В LÖVE newSource кидает ошибку, если файла нет.
  local exists = false
  if love.filesystem and love.filesystem.getInfo then
    exists = love.filesystem.getInfo( path ) ~= nil
  else
    local f = io.open( path, "r" )
    if f then f:close() exists = true end
  end

  if not exists then
    error( "Could not open file " .. tostring( path )
           .. ". Does not exist.", 2 )
  end

  return source_mock
end

love.audio.play = function( src )
play_calls[#play_calls+1] = src
end
love.audio.stop = function() end
love.audio.pause = function() end
love.audio.setVolume = function() end
love.audio.getVolume = function() return 1 end
end

function M.get_play_calls() return play_calls end
function M.reset() play_calls = {} end

return M
