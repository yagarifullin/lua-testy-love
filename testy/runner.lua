-- Общий раннер. Используется CLI-обёрткой и LÖVE-обёрткой.
local M = {}

-- Запускает тесты из списка файлов. Возвращает stats.
function M.run( opts, env )
  env = env or _G

  -- Устанавливаем моки, если запрошено.
  if opts.mock_love and not opts.test_mode then
    local ok, init = pcall( require, "testy.mocks.init" )
    if ok and init and init.install then init.install() end
  end

  -- Делегируем в патченный testy.lua через dofile.
  -- testy.lua ожидает _G.arg. Формируем его.
  local saved_arg = _G.arg
  local new_arg = {}
  if opts.tap then new_arg[#new_arg+1] = "-t" end
  if opts.recursive then new_arg[#new_arg+1] = "-r" end
  if opts.mock_love then new_arg[#new_arg+1] = "--mock-love" end
  if opts.no_extra then new_arg[#new_arg+1] = "--no-extra" end
  for _, f in ipairs( opts.files ) do
    new_arg[#new_arg+1] = f
  end
  _G.arg = new_arg

  -- Запускаем testy.lua. Он сам выведет и завершится os.exit.
  -- Чтобы перехватить код выхода, оборачиваем в pcall и ловим os.exit.
  local exit_code = 0
  local real_exit = os.exit
  os.exit = function( code ) exit_code = code or 0; error( "__TESTY_EXIT__", 0 ) end

  local testy_path = "testy.lua"
  local ok, err = pcall( dofile, testy_path )

  os.exit = real_exit
  _G.arg = saved_arg

  if not ok and err ~= "__TESTY_EXIT__" and
     not (type(err) == "string" and err:match("__TESTY_EXIT__")) then
    io.stderr:write( "runner error: ", tostring(err), "\n" )
    return { ok = false, exit_code = 1, error = err }
  end

  return { ok = exit_code == 0, exit_code = exit_code }
end

function M.exit_code( stats )
  return stats and stats.exit_code or 0
end

return M
