-- Мок love.window. getMode возвращает три значения (как LÖVE).
local M = {}
local state = { width = 1280, height = 720, flags = {} }

function M.install()
  _G.love = _G.love or {}
  love.window = love.window or {}
  love.window.setMode = function( w, h, flags )
    if w and h then
      state.width = w
      state.height = h
    end
    state.flags = flags or {}
    return true
  end
  love.window.getMode = function()
    return state.width, state.height, state.flags
  end
  love.window.getDesktopDimensions = function()
    return 1920, 1080
  end
  love.window.isVisible = function() return true end
  love.window.setTitle = function() end
  love.window.hasFocus = function() return true end
end

function M.get_width()  return state.width  end
function M.get_height() return state.height end
function M.get_flags()  return state.flags  end

function M.reset()
  state.width = 1280
  state.height = 720
  state.flags = {}
end

return M
