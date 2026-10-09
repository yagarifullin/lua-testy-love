-- Мок love.event. Сохраняет оригинал, восстанавливает.
local M = {}
local calls = {}
local original_quit = nil

function M.install()
  _G.love = _G.love or {}
  love.event = love.event or {}
  if not original_quit then
    original_quit = love.event.quit
  end
  love.event.quit = function( code )
    calls[ #calls+1 ] = code or 0
  end
  love.event.pump = function() end
  love.event.clear = function() end
  love.event.push = function() end
end

function M.calls() return calls end
function M.reset() calls = {} end

function M.uninstall()
  if original_quit ~= nil then
    love.event.quit = original_quit
    original_quit = nil
  end
  -- Если original_quit == nil — ничего не делаем.
end

return M
