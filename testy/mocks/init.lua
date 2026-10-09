-- Установка всех моков в фиксированном порядке.
local M = {}

local ORDER = {
  "testy.mocks.timer",
  "testy.mocks.window",
  "testy.mocks.graphics",
  "testy.mocks.audio",
  "testy.mocks.filesystem",
  "testy.mocks.event",
}

function M.install()
  for _, mod in ipairs( ORDER ) do
    local ok, m = pcall( require, mod )
    if ok and m and m.install then
      m.install()
    end
  end
end

function M.reset_all()
  for _, mod in ipairs( ORDER ) do
    local ok, m = pcall( require, mod )
    if ok and m and m.reset then m.reset() end
  end
end

function M.uninstall_all()
  for i = #ORDER, 1, -1 do
    local ok, m = pcall( require, ORDER[i] )
    if ok and m and m.uninstall then m.uninstall() end
  end
end

return M
