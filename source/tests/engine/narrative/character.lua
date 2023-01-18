-- COMPILE VERSION: 0.3
-- SOURCE:
--[[

main {
    if script.testcase == "characterNameIsImmutable" {
        jump characterNameIsImmutable
    } else if script.testcase == "backgroundCanBeMutated" {
        jump backgroundCanBeMutated
    } else if script.testcase == "beliefCanBeMutated" {
        jump beliefCanBeMutated
    } else if script.testcase == "credits" {
        jump credits
    } else {
        error "unknown test case: {script.testcase}"
    }
}

characterNameIsImmutable {
    "Character name: {character.name}"
    set character.name "it's immutable"
    "Character name: {character.name}"   
}

backgroundCanBeMutated {
    "Background: {character.background}"
    set character.background "suit"
    "Background: {character.background}"
    set character.background "notathing"
}

beliefCanBeMutated {
    "Belief: {character.belief}"
    set character.belief "capitalist"
    "Belief: {character.belief}"
    set character.belief "notathing"
}

credits {
    "balance = {character.credits}"
    add character.credits 20
    "balance = {character.credits}"
    add character.credits -200
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
    if ( self:getVar("script.testcase", "") == "characterNameIsImmutable" ) then
      self:passage_characterNameIsImmutable()
    else
    if ( self:getVar("script.testcase", "") == "backgroundCanBeMutated" ) then
      self:passage_backgroundCanBeMutated()
    else
    if ( self:getVar("script.testcase", "") == "beliefCanBeMutated" ) then
      self:passage_beliefCanBeMutated()
    else
    if ( self:getVar("script.testcase", "") == "credits" ) then
      self:passage_credits()
    else
      coroutine.yield("error", {message = self:processVars("unknown test case: {script.testcase}")})
    end
    end
    end
    end
end

function module:passage_characterNameIsImmutable()
    coroutine.yield("talk", {text = self:processVars("Character name: {character.name}"), attributes = {}})
    self:setVar("character.name", "it's immutable")
    coroutine.yield("talk", {text = self:processVars("Character name: {character.name}"), attributes = {}})
end

function module:passage_backgroundCanBeMutated()
    coroutine.yield("talk", {text = self:processVars("Background: {character.background}"), attributes = {}})
    self:setVar("character.background", "suit")
    coroutine.yield("talk", {text = self:processVars("Background: {character.background}"), attributes = {}})
    self:setVar("character.background", "notathing")
end

function module:passage_beliefCanBeMutated()
    coroutine.yield("talk", {text = self:processVars("Belief: {character.belief}"), attributes = {}})
    self:setVar("character.belief", "capitalist")
    coroutine.yield("talk", {text = self:processVars("Belief: {character.belief}"), attributes = {}})
    self:setVar("character.belief", "notathing")
end

function module:passage_credits()
    coroutine.yield("talk", {text = self:processVars("balance = {character.credits}"), attributes = {}})
    self:addVar("character.credits", 20)
    coroutine.yield("talk", {text = self:processVars("balance = {character.credits}"), attributes = {}})
    self:addVar("character.credits", -200)
end

return module
