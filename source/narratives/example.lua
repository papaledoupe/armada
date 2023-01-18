-- COMPILE VERSION: 0.3
-- SOURCE:
--[[

game {
  choice "Heads or tails?" who="Tosser" {
    "Heads." {
      "You chose heads." who="Tosser"
    }
    "Having carefully considered my options, I have decided to go with tails." {
      "You chose tails." who="Tosser"
    }
  }
}

loop {
  jump game
  choice "Go again?" who="Tosser" {
    "Yep!" {
      jump loop
    }
    "No way." {
      "Ok, that's the game over then!" who="Tosser"
    }
  }
}

main {
  "Welcome to the game. This is designed to simply test various aspects of the narrative UI."
  "I am going to toss a coin." who="Tosser"
  jump loop
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

function module:passage_game()
    coroutine.yield("talk", {text = "Heads or tails?", attributes = {who = "Tosser"}})
    local choices1 = {}
    local choiceFns1 = {}
    table.insert(choices1, "Heads.")
    choiceFns1["Heads."] = function()
        coroutine.yield("talk", {text = "You chose heads.", attributes = {who = "Tosser"}})
    end
    table.insert(choices1, "Having carefully considered my options, I have decided to go with tails.")
    choiceFns1["Having carefully considered my options, I have decided to go with tails."] = function()
        coroutine.yield("talk", {text = "You chose tails.", attributes = {who = "Tosser"}})
    end
    local choice1_idx = coroutine.yield("choice", {choices = choices1})
    choiceFns1[choice1_idx]()
end

function module:passage_loop()
    self:passage_game()
    coroutine.yield("talk", {text = "Go again?", attributes = {who = "Tosser"}})
    local choices2 = {}
    local choiceFns2 = {}
    table.insert(choices2, "Yep!")
    choiceFns2["Yep!"] = function()
        self:passage_loop()
    end
    table.insert(choices2, "No way.")
    choiceFns2["No way."] = function()
        coroutine.yield("talk", {text = "Ok, that's the game over then!", attributes = {who = "Tosser"}})
    end
    local choice2_idx = coroutine.yield("choice", {choices = choices2})
    choiceFns2[choice2_idx]()
end

function module:passage_main()
    coroutine.yield("talk", {text = "Welcome to the game. This is designed to simply test various aspects of the narrative UI.", attributes = {}})
    coroutine.yield("talk", {text = "I am going to toss a coin.", attributes = {who = "Tosser"}})
    self:passage_loop()
end

return module
