-- examples/requires_love.lua
-- testy:requires love

local function test_needs_love()
  assert( love ~= nil )
end

return {}
