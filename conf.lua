function love.conf( t )
  local windowed = false
  for _, a in ipairs( arg or {} ) do
    if a == "--window" then windowed = true; break end
  end

  if windowed then
    t.window = {
      width = 800,
      height = 600,
      title = "lua-testy-love",
      resizable = true,
    }
  else
    t.window = false
  end

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.identity = "lua_testy_love"
end
