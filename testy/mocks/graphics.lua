-- Мок love.graphics. Spy на draw-вызовы. newImage проверяет файл.
local M = {}
local window_mock = require( "testy.mocks.window" )

local draw_calls = {}
local setcolor_calls = {}
local font_mock

local function file_exists( path )
  if love.filesystem and love.filesystem.getInfo then
    return love.filesystem.getInfo( path ) ~= nil
  end
  local f = io.open( path, "r" )
  if f then f:close() return true end
  return false
end

function M.install()
  _G.love = _G.love or {}
  love.graphics = love.graphics or {}

  local image_mock = {
    getWidth = function() return 100 end,
    getHeight = function() return 100 end,
    setFilter = function() end,
    getDimensions = function() return 100, 100 end,
    type = function() return "Image" end,
    typeOf = function(_, t) return t == "Image" end,
  }

  local quad_mock = {
    getViewport = function() return 0, 0, 50, 50 end,
    setViewport = function() end,
    type = function() return "Quad" end,
  }

  font_mock = {
    getWidth = function(self, text) return #text * 8 end,
    getHeight = function() return 12 end,
    getLineHeight = function() return 14 end,
    getWrap = function(self, text, w) return w, { text } end,
    type = function() return "Font" end,
  }

  love.graphics.newImage = function( path )
    if not file_exists( path ) then
      error( "Could not load image: " .. tostring( path ) )
    end
    return image_mock
  end
  love.graphics.newQuad = function( x, y, w, h, sw, sh )
    return quad_mock
  end
  love.graphics.newFont = function( size )
    return font_mock
  end
  love.graphics.getFont = function() return font_mock end
  love.graphics.setFont = function() end

  love.graphics.draw = function( ... )
    draw_calls[ #draw_calls+1 ] = { ... }
  end
  love.graphics.print = function( ... )
    draw_calls[ #draw_calls+1 ] = { __print = true, ... }
  end
  love.graphics.printf = function( ... )
    draw_calls[ #draw_calls+1 ] = { __printf = true, ... }
  end

  love.graphics.setColor = function( ... )
    setcolor_calls[ #setcolor_calls+1 ] = { ... }
  end
  love.graphics.getColor = function() return 1, 1, 1, 1 end
  love.graphics.setBackgroundColor = function() end

  love.graphics.rectangle = function() end
  love.graphics.line = function() end
  love.graphics.circle = function() end
  love.graphics.polygon = function() end
  love.graphics.points = function() end
  love.graphics.arc = function() end
  love.graphics.ellipse = function() end

  love.graphics.setLineWidth = function() end
  love.graphics.getLineWidth = function() return 1 end
  love.graphics.setLineStyle = function() end

  love.graphics.push = function() end
  love.graphics.pop = function() end
  love.graphics.origin = function() end
  love.graphics.translate = function() end
  love.graphics.rotate = function() end
  love.graphics.scale = function() end
  love.graphics.shear = function() end

  love.graphics.getWidth = function() return window_mock.get_width() end
  love.graphics.getHeight = function() return window_mock.get_height() end

  love.graphics.clear = function() end
  love.graphics.present = function() end
  love.graphics.captureScreenshot = function( cb )
    -- Ничего не делаем: в headless нет реального фреймбуфера.
    if cb then cb( nil ) end
  end
end

function M.get_draw_calls() return draw_calls end
function M.get_setcolor_calls() return setcolor_calls end

function M.reset()
  draw_calls = {}
  setcolor_calls = {}
end

return M
