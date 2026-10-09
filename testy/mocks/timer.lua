-- Мок love.timer. Без мутации getTime. Явный advance.
local M = {}
local fake_time = 0
local last_delta = 0
local deltas = {}
local MAX_DELTAS = 60

function M.install()
  _G.love = _G.love or {}
  love.timer = love.timer or {}
  love.timer.getTime = function() return fake_time end
  love.timer.getDelta = function() return last_delta end
  love.timer.getAverageDelta = function()
    if #deltas == 0 then return 0 end
    local s = 0
    for _, d in ipairs( deltas ) do s = s + d end
    return s / #deltas
  end
  love.timer.sleep = function() end
  love.timer.getFPS = function() return 60 end
  love.timer.step = function() end
end

function M.advance( dt )
  dt = dt or 0.016
  fake_time = fake_time + dt
  last_delta = dt
  deltas[ #deltas+1 ] = dt
  if #deltas > MAX_DELTAS then table.remove( deltas, 1 ) end
end

function M.reset()
  fake_time = 0
  last_delta = 0
  deltas = {}
end

function M.uninstall()
  -- Мок необратим (мы не знаем реальный love.timer).
  -- Оставляем как есть.
end

return M
