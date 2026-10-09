-- Хелперы для SKIP-меток и определения LÖVE.
local M = {}

-- Пометить файл как требующий LÖVE: `-- testy:requires love` в шапке.

-- Вызвать в тесте, чтобы пропустить его, если LÖVE недоступен.
function M.skip_if_no_love()
  if _G.love == nil then
    error( "SKIP:requires love", 2 )
  end
end

-- Явный SKIP с причиной.
function M.skip( reason )
  error( "SKIP:" .. (reason or "no reason"), 2 )
end

-- Проверка, доступен ли LÖVE.
function M.has_love()
  return _G.love ~= nil
end

return M
