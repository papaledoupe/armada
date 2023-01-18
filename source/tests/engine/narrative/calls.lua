-- COMPILE VERSION: 0.3
-- SOURCE:
--[[

main {
  call my.func param1=4 param2="str" param3=false param4=my.value
}

]]
local module <const> = {}

function module.new(args)
  args = args or {}
  local m = {}
  m._vars = args.vars or {}
  setmetatable(m, module)
  module.__index = module

  return coroutine.create(function()
     return m:passage_main()
  end)
end

local function isAccessor(t)
  return type(t) == 'table' and (type(t.get) == 'function' or type(t.set) == 'function')
end

function module:getVar(label, defaultValue)
  local node = self._vars
  for part in string.gmatch(label, "[^.]+") do
    if isAccessor(node) then return defaultValue end
    node = node[part]
    if node == nil then return defaultValue end
  end
  if isAccessor(node) then
    if type(node.get) == 'function' then return node:get() else return defaultValue end
  end
  return node
end

function module:setVar(label, value)
  local path = {}
  for part in string.gmatch(label, "[^.]+") do
    table.insert(path, part)
  end
  local node = self._vars
  for i=1,#path-1 do
    if node[path[i]] == nil then
      node[path[i]] = {}
    end
    node = node[path[i]]
    if isAccessor(node) then return end
  end
  local leaf = node[path[#path]]
  if isAccessor(leaf) then
    if type(leaf.set) == 'function' then
      leaf:set(value)
    end
  else
    node[path[#path]] = value
  end
end

function module:addVar(label, value)
  local initial = self:getVar(label)
  if initial == nil then
    self:setVar(label, value)
  else
    self:setVar(label, initial + value)
  end
end

function module:callVar(label, attribs)
  local f = self:getVar(label)
  if type(f) == "function" then f(attribs or {}) end
  if type(f) == "table" and getmetatable(f) ~= nil and type(getmetatable(f).__call) == "function" then f(attribs or {}) end
end

function module:processVars(str)
  str = string.gsub(str, "{([^{}]*)}", function(v) return tostring(self:getVar(v) or "") end)
  return str
end

function module:passage_main()
    self:callVar("my.func", {param1 = 4, param2 = "str", param3 = false, param4 = self:getVar("my.value")})
end

return module
