-- Add new test suite import paths here
local allTests <const> = {
    'support/support_test',
    'engine/narrative/runner',
    'util/oo',
    'util/simploo_ext',
    'util/fsm',
    'util/table',
    'util/task',
    'util/string',
    'util/enum',
    'util/math',
    'util/set',
    'util/deltatime',
    'util/memo',
    'game/state',
    'ship/ship',
    'ship/stats',
    'ship/command',
    'ship/weapons',
}

-- playdate SDK uses import over require which is an optimization for the playdate platform
-- for tests it's sufficient to just substitute require for it
import = require

local lu <const> = require('lib/luaunit/luaunit')
local files = {...} or {} -- CLI args

if #files > 0 then
    local allTestsTable = {}
    for _, file in ipairs(allTests) do
        allTestsTable[file] = file
    end
    for _, file in ipairs(files) do
        if allTestsTable[file] == nil then 
            error('test file '..file..' is missing from allTests, must add it first')
        end
    end
    for _, file in ipairs(files) do
        require('tests/'..file)
    end
else
    for _, file in ipairs(allTests) do
        require('tests/'..file)
    end
end

local luArgs = {}
for arg in string.gmatch(os.getenv('LU_ARGS') or '--output text --shuffle', "[^%s]+") do
    table.insert(luArgs, arg)
end
os.exit(lu.LuaUnit.run(table.unpack(luArgs)))
