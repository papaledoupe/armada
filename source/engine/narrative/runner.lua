import "util/fsm"
import "util/oo"
import "util/string"
import "narratives/all"
local typeGuard <const> = util.oo.typeGuard

engine = engine or {}
engine.narrative = engine.narrative or {}
engine.narrative.runner = {}

local function getScript(path)
    if util.string.startsWith(path, 'tests/') then
        -- only works inside tests - require() does not work on playdate
        return require(path)
    end
    if narratives.all[path] == nil then
        error('attempted to get undefined narrative script: '..path)
    end
    return narratives.all[path]
end

--[[

    NOT_STARTED
      │          talk
 start│   ┌─────────────────┐
      ▼   │     next        ▼
┌───RUNNING◄───────────AWAITING_NEXT
│     │ │ ▲     chose
│     │ │ └──────────────────┐
│     │ │     choice         │
│     │ └─────────────►AWAITING_CHOICE
│     │finish
│     ▼
│   FINISHED
│
│error
│
│
└──►ERRORED

]]
function engine.narrative.runner.new(args)
    args = args or {}
    local vars = typeGuard('table', args.vars or {})
    local scriptPath = typeGuard('string', args.script or error('script required'))
    local onTalk = typeGuard('function', args.onTalk or function() end)
    local onChoice = typeGuard('function', args.onChoice or function() end)
    local onFinish = typeGuard('function', args.onFinish or function() end)
    local onError = typeGuard('function', args.onError or function() end)

    local scriptCoroutine = getScript(scriptPath).new{vars = vars}

    local enterRunning = function(args)
        local continue, cmdOrErr, payload = coroutine.resume(scriptCoroutine, table.unpack(args.payload or {}))
        if continue == false then
            if string.find(cmdOrErr, "early exit") then
                args.fsm:mustTrigger('finish')
            else
                args.fsm:mustTrigger('error', {error = cmdOrErr})
            end
        elseif cmdOrErr == nil then
            args.fsm:mustTrigger('finish')
        elseif cmdOrErr == 'talk' then
            args.fsm:mustTrigger('talk', {text = payload.text, attributes = payload.attributes})
        elseif cmdOrErr == 'choice' then
            args.fsm:mustTrigger('choice', {choices = payload.choices})
        elseif cmdOrErr == 'error' then
            args.fsm:mustTrigger('error', {error = payload.message})
        else
            args.fsm:mustTrigger('error', {error = 'unknown command returned from script: '..cmdOrErr})
        end
    end

    return FiniteStateMachine.new{
        start = 'NOT_STARTED',
        transitions = {
            StateTransition.new{
                event = 'start',
                from = 'NOT_STARTED',
                to = 'RUNNING',
                callback = enterRunning,
            },
            StateTransition.new{
                event = 'talk',
                from = 'RUNNING',
                to = 'AWAITING_NEXT',
                callback = function(args)
                    onTalk(args.payload)
                end,
            },
            StateTransition.new{
                event = 'next',
                from = 'AWAITING_NEXT',
                to = 'RUNNING',
                callback = enterRunning,
            },
            StateTransition.new{
                event = 'choice',
                from = 'RUNNING',
                to = 'AWAITING_CHOICE',
                callback = function(args)
                    onChoice(args.payload)
                end,
            },
            StateTransition.new{
                event = 'chose',
                from = 'AWAITING_CHOICE',
                to = 'RUNNING',
                callback = function(args)
                    typeGuard('table', args.payload)
                    typeGuard('string', args.payload[1])
                    enterRunning(args)
                end,
            },
            StateTransition.new{
                event = 'finish',
                from = 'RUNNING',
                to = 'FINISHED',
                callback = function(args)
                    onFinish(args.payload)
                end,
            },
            StateTransition.new{
                event = 'error',
                from = 'RUNNING',
                to = 'ERRORED',
                callback = function(args)
                    onError(args.payload)
                end,
            },
        },
    }
end
