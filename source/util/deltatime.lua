import 'util/math'
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard

DeltaTime = {}
local lastT = -1
local dT = 0

function DeltaTime.reset()
    lastT = -1
    dT = 0
end

function DeltaTime.update(currentTime)
    local newT = currentTime == nil and playdate.getCurrentTimeMilliseconds() or currentTime
    if lastT == -1 then
        -- need 2 frames to know the delta since init.
        lastT = newT
        return
    end 
    dT = newT - lastT
    lastT = newT
end

function DeltaTime.getMillis()
    return dT
end

function DeltaTime.getSeconds()
    return dT/1000
end

function DeltaTime.throttled(args, f)
    typeGuard('table', args)
    typeGuard('function', f)
    local windowMillis = typeGuard('number', args.windowMillis or 1000)

    local lastCall = -util.math.MaxInteger
    return function(...)
        if lastT >= lastCall + windowMillis then
            lastCall = lastT
            f(table.unpack{...})
        end
    end
end
