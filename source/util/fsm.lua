import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local typeGuardElements <const> = util.oo.typeGuardElements

class "StateTransition" {
    public {
        event = '',
        from = '',
        to = '',

        __construct = function(self, args)
            args = args or {}
            self.event = typeGuard('string', args.event or error('event required'))
            self.from = typeGuard('string', args.from or error('from required'))
            self.to = typeGuard('string', args.to or error('to required'))
            self.callback = typeGuard('function', args.callback or (function() end))
        end,

        triggerCallback = function(self, fsm, payload)
            self.callback{from = self.from, to = self.to, event = self.event, fsm = fsm, payload = payload}
        end,
    },
    private {
        callback = function() end,
    }
}

class "FiniteStateMachine" {
    public {
        __construct = function(self, args)
            args = args or {}
            self.state = typeGuard('string', args.start or error('start required'))
            self.log = typeGuard('boolean', args.log or false)
            typeGuardElements('StateTransition', args.transitions or error('transitions required'))

            for _, trans in ipairs(args.transitions) do
                if self.transitionsByStateByEvent[trans.from] == nil then
                    self.transitionsByStateByEvent[trans.from] = {}
                end
                self.transitionsByStateByEvent[trans.from][trans.event] = trans
            end

            for state, callbacks in pairs(args.stateCallbacks or {}) do
                for lifecycle, callback in pairs(callbacks) do
                    if lifecycle ~= 'enter' and lifecycle ~= 'leave' then
                        error('unknown lifecycle event '..lifecycle..' in state callback for '..state)
                    end
                    typeGuard('function', callback)
                end
                self.stateCallbacks[state] = typeGuard('table', callbacks)
            end

            self:triggerCurrentStateCallback('enter')
        end,

        trigger = function(self, event, payload)
            typeGuard('string', event)
            local trans = (self.transitionsByStateByEvent[self.state] or {})[event]
            if trans == nil then
                return false
            end
            self:triggerCurrentStateCallback('leave')
            self:changeState(event, trans.to)
            trans:triggerCallback(self, payload)
            self:triggerCurrentStateCallback('enter')
            return true
        end,

        mustTrigger = function(self, event, payload)
            if payload ~= nil then typeGuard('table', payload) end
            if not self:trigger(event, payload) then
                error('invalid transition: no transition for event '..event..' in state '..self.state)
            end
        end,
    },
    private {
        getter {
            state = '',
        },
        log = false,
        transitionsByStateByEvent = {},
        stateCallbacks = {},

        changeState = function(self, event, newState)
            local old = self.state
            self.state = newState
            if self.log then
                print('FSM transition: '..old..' --{' ..event..'}-> '..newState)
            end
        end,

        triggerCurrentStateCallback = function(self, lifecycle)
            local callbacks = self.stateCallbacks[self.state]
            if callbacks ~= nil then
                local callback = callbacks[lifecycle]
                if callback ~= nil then
                    callback(self)
                end
            end
        end,
    },
}
