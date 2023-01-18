import "util/set"
local Set <const> = util.set
import "util/oo"
local typeGuard <const> = util.oo.typeGuard
local instanceOf <const> = util.oo.instanceOf

class "TaskQueueTask" {
    public {
        kind = '',
        fn = function() end,

        __construct = function(self, args)
            self.kind = typeGuard('string', args.kind or error('task kind required'))
            self.fn = typeGuard('function', args.run or error('task run function required'))
            self.state = typeGuard('table', args.initialState or {})
        end,

        cancel = function(self)
            self.cancelled = true
        end,

        run = function(self)
            if self.cancelled then
                return true
            end
            return self.fn(self.state)
        end,
    },
    private {
        getter {
            state = {},
            cancelled = false,
        },
    }
}

class "TaskQueue" {
    public {
        update = function(self)
            if self.updating then
                -- prevents tasks with callbacks that result in TaskQueue:update being called being recursive
                return
            end
            self.updating = true
            
            if #self.queue > 0 then
                local task = self.queue[1]
                local done = task:run()
                if type(done) ~= 'boolean' then
                    error('task of kind "'..task.kind..'" did not return a boolean - task must return true to stop or false to continue')
                end
                if done then
                    table.remove(self.queue, 1)
                end
            end

            self.updating = false
        end,

        length = function(self)
            return #self.queue
        end,

        submit = function(self, ...)
            for _, task in ipairs{...} do
                table.insert(self.queue, typeGuard('TaskQueueTask', task)) 
            end
        end,

        cancelTasksOfKind = function(self, ...)
            local kinds = Set.ofType('string', ...)
            for _, task in ipairs(self.queue) do
                if kinds:has(task.kind) then
                    task:cancel()
                end
            end
        end,

        blockingDrain = function(self)
            while self:length() > 0 do
                self:update()
            end            
        end,

        cancelAll = function(self)
            for _, task in ipairs(self.queue) do
                task:cancel()
            end
            self:blockingDrain()
        end,
    },
    private {
        queue = {},
        updating = false,
    }
}
