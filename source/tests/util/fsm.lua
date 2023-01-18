local lu <const> = import 'lib/luaunit/luaunit'
import 'util/fsm'

TestFiniteStateMachine = {

    testFiniteStateMachine = function()
        local log = {}
        local logCallback = function(args) table.insert(log, args) end

        local fsm = FiniteStateMachine.new{
            start = 'BED',
            transitions = {
                StateTransition.new{event = 'wake', from = 'BED', to = 'HOME', callback = logCallback},
                StateTransition.new{event = 'sleep', from = 'HOME', to = 'BED', callback = logCallback},
                StateTransition.new{event = 'eat', from = 'HOME', to = 'HOME', callback = logCallback},
                StateTransition.new{event = 'drive', from = 'HOME', to = 'WORK', callback = logCallback},
                StateTransition.new{event = 'drive', from = 'WORK', to = 'HOME', callback = logCallback},
            },
        }
        lu.assertEquals(fsm.state, 'BED')
        lu.assertEquals(#log, 0)

        local transitioned = fsm:trigger('drive')
        lu.assertFalse(transitioned)
        lu.assertEquals(fsm.state, 'BED')
        lu.assertEquals(#log, 0)

        local transitioned = fsm:trigger('wake')
        lu.assertTrue(transitioned)
        lu.assertEquals(fsm.state, 'HOME')
        lu.assertEquals(#log, 1)
        lu.assertEquals(log[1], {from = 'BED', to = 'HOME', event = 'wake', fsm = fsm})

        local transitioned = fsm:trigger('eat')
        lu.assertTrue(transitioned)
        lu.assertEquals(fsm.state, 'HOME')
        lu.assertEquals(#log, 2)
        lu.assertEquals(log[2], {from = 'HOME', to = 'HOME', event = 'eat', fsm = fsm})

        local transitioned = fsm:trigger('drive')
        lu.assertTrue(transitioned)
        lu.assertEquals(fsm.state, 'WORK')
        lu.assertEquals(#log, 3)
        lu.assertEquals(log[3], {from = 'HOME', to = 'WORK', event = 'drive', fsm = fsm})

        local transitioned = fsm:trigger('drive', {distance = 12})
        lu.assertTrue(transitioned)
        lu.assertEquals(fsm.state, 'HOME')
        lu.assertEquals(#log, 4)
        lu.assertEquals(log[4], {from = 'WORK', to = 'HOME', event = 'drive', payload = {distance = 12}, fsm = fsm})
    end,

    testMustTrigger = function()
        local fsm = FiniteStateMachine.new{
            start = 'STATE',
            transitions = {},
        }
        lu.assertErrorMsgContains('invalid transition: no transition for event anEvent in state STATE', function()
            fsm:mustTrigger('anEvent')
        end)
    end,

    testStateCallbacks = function()
        local events = {}
        local fsm = FiniteStateMachine.new{
            start = 'BED',
            transitions = {
                StateTransition.new{event = 'wake', from = 'BED', to = 'HOME'},
                StateTransition.new{event = 'sleep', from = 'HOME', to = 'BED'},
            },
            stateCallbacks = {
                ['BED'] = {
                    enter = function()
                        table.insert(events, 'enter BED')
                    end,
                    leave = function()
                        table.insert(events, 'leave BED')
                    end,
                },
            }
        }

        lu.assertEquals(events, {'enter BED'})

        fsm:mustTrigger('wake')
        lu.assertEquals(events, {'enter BED', 'leave BED'})
        fsm:mustTrigger('sleep')
        lu.assertEquals(events, {'enter BED', 'leave BED', 'enter BED'})
    end,

    testCallbackOrder = function()
        local callbacks = {}
        local fsm = FiniteStateMachine.new{
            start = 'BED',
            transitions = {
                StateTransition.new{
                    event = 'wake',
                    from = 'BED',
                    to = 'HOME',
                    callback = function()
                        table.insert(callbacks, 'transition')
                    end,
                },
            },
            stateCallbacks = {
                ['BED'] = {
                    leave = function()
                        table.insert(callbacks, 'leave state')
                    end,
                },
                ['HOME'] = {
                    enter = function()
                        table.insert(callbacks, 'enter state')
                    end,
                }
            },
        }

        fsm:mustTrigger('wake')
        lu.assertEquals(callbacks, {'leave state', 'transition', 'enter state'})
    end,
}
