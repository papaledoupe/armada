local lu <const> = import 'lib/luaunit/luaunit'
import 'engine/narrative/runner'
local Runner <const> = engine.narrative.runner

TestNarrativeRunner = {

    testNarrativeRunnerOnExample = function()
        local log = {}
        local runner = Runner.new{
            script = 'tests/engine/narrative/game',
            onTalk = function(payload)
                table.insert(log, "TALK: "..payload.text)
            end,
            onError = function(payload)
                table.insert(log, "ERROR: "..payload.error)
            end
        }

        runner:mustTrigger('start')
        lu.assertEquals(runner.state, 'AWAITING_NEXT')
        lu.assertEquals(log[1], "TALK: Welcome to the game.")

        runner:mustTrigger('next')
        lu.assertEquals(runner.state, 'AWAITING_NEXT')
        lu.assertEquals(log[2], "TALK: Heads or tails?")

        runner:mustTrigger('next')
        lu.assertEquals(runner.state, 'AWAITING_CHOICE')
        
        runner:mustTrigger('chose', {"heads"})
        lu.assertEquals(runner.state, 'AWAITING_NEXT')
        lu.assertEquals(log[3], "TALK: You chose heads.")

        runner:mustTrigger('next')
        lu.assertEquals(runner.state, 'FINISHED')
    end,

    testNarrativeRunnerFailure = function()
        local log = {}
        local runner = Runner.new{
            script = 'tests/engine/narrative/game',
            onError = function(payload)
                table.insert(log, "ERROR: "..payload.error)
            end
        }

        runner:mustTrigger('start')
        lu.assertEquals(runner.state, 'AWAITING_NEXT')

        runner:mustTrigger('next')
        lu.assertEquals(runner.state, 'AWAITING_NEXT')

        runner:mustTrigger('next')
        lu.assertEquals(runner.state, 'AWAITING_CHOICE')
        
        runner:mustTrigger('chose', {"sides"})
        lu.assertEquals(runner.state, 'ERRORED')
        lu.assertStrContains(log[1], "ERROR: ")
    end,

    testNarrativeRunnerWithPredefinedVars = function()
        local log = {}
        local runner = Runner.new{
            script = 'tests/engine/narrative/vars',
            vars = {
                character = {
                    strength = 6,
                    intelligence = 2,
                },
            },
            onTalk = function(payload)
                table.insert(log, "TALK: "..payload.text)
            end,
            onError = function(payload)
                print('ERROR: '..payload.error)
            end,
        }

        runner:mustTrigger('start')

        lu.assertEquals(runner.state, 'AWAITING_NEXT')
        lu.assertEquals(log[1], "TALK: You're so strong!")
    end,

    testNarrativeRunnerScriptRaisedError = function()
        local err = ""
        local runner = Runner.new{
            script = 'tests/engine/narrative/errors',
            vars = { number = 3 },
            onError = function(payload)
                err = payload.error
            end,
        }

        runner:mustTrigger('start')

        lu.assertEquals(runner.state, 'ERRORED')
        lu.assertEquals(err, 'number was greater than 2 (3)')
    end,

    testNarrativeRunnerScriptCallFunc = function()
        local params = nil
        local runner = Runner.new{
            script = 'tests/engine/narrative/calls',
            vars = {
                my = { 
                    value = "foo",
                    func = function(p)
                        params = p
                    end,
                },
            },
        }

        runner:mustTrigger('start')

        lu.assertEquals(runner.state, 'FINISHED')
        lu.assertEquals(params, {param1 = 4, param2 = "str", param3 = false, param4 = "foo"})
    end,

    testNarrativeRunnerScriptCallCallableTable = function()
        local params = nil
        local callable = {}
        setmetatable(callable, {
            __call = function(tbl, p)
                params = p
            end,
        })
        local runner = Runner.new{
            script = 'tests/engine/narrative/calls',
            vars = {
                my = { 
                    value = "foo",
                    func = callable,
                },
            },
        }

        runner:mustTrigger('start')

        lu.assertEquals(runner.state, 'FINISHED')
        lu.assertEquals(params, {param1 = 4, param2 = "str", param3 = false, param4 = "foo"})
    end,

    testNarrativeRunnerScriptAccessor = function()
        local outputs = {}
        local accessor = {
            value = "starting value",
            get = function(self)
                return self.value
            end,
            set = function(self, v)
                self.value = v
            end,
        }
        local runner = Runner.new{
            script = 'tests/engine/narrative/accessors',
            vars = {
                my = { 
                    accessor = accessor,
                },
            },
            onTalk = function(payload)
                table.insert(outputs, payload.text)
            end,
        }

        runner:mustTrigger('start')
        while runner.state == 'AWAITING_NEXT' do
            runner:mustTrigger('next')
        end

        lu.assertEquals(runner.state, 'FINISHED')
        lu.assertEquals(outputs, {
            "value: starting value",
            "value: 1",
            "value: true",
            "value: str",
        })
    end,

}
