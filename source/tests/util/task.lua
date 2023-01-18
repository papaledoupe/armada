local lu <const> = import 'lib/luaunit/luaunit'
import 'util/task'

class "CountingTask" extends "TaskQueueTask" {
    public {
        __construct = function(self, args)
            args = args or {}
            local start = args.start or 0
            local limit = args.limit
            local kind = args.kind or 'CountingTask'
            self.TaskQueueTask{
                kind = kind,
                initialState = {count = start or 0},
                run = function(state)
                    state.count = state.count + 1
                    return limit ~= nil and state.count == limit
                end,
            }
        end,

        getCount = function(self)
            return self.state.count
        end,
    }
}

TestTaskQueue = {

    testRunsTasksToCompletionOnUpdate = function()
        local t1 = CountingTask.new{start=1, limit=4}
        local t2 = CountingTask.new{start=3, limit=4}

        local q = TaskQueue.new()
        lu.assertEquals(q:length(), 0)
        q:submit(t1)
        lu.assertEquals(q:length(), 1)
        q:submit(t2)
        lu.assertEquals(q:length(), 2)

        lu.assertEquals(t1:getCount(), 1)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 2)

        q:update()
        lu.assertEquals(t1:getCount(), 2)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 2)

        q:update()
        lu.assertEquals(t1:getCount(), 3)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 2)

        q:update()
        lu.assertEquals(t1:getCount(), 4)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 1)

        q:update()
        lu.assertEquals(t1:getCount(), 4)
        lu.assertEquals(t2:getCount(), 4)
        lu.assertEquals(q:length(), 0)

        q:update()
        lu.assertEquals(t1:getCount(), 4)
        lu.assertEquals(t2:getCount(), 4)
    end,


    testCancelTaskInflight = function()
        local t1 = CountingTask.new{kind='1', start=1, limit=4}
        local t2 = CountingTask.new{kind='2', start=3, limit=4}

        local q = TaskQueue.new()
        q:submit(t1, t2)

        q:update()
        lu.assertEquals(t1:getCount(), 2)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 2)

        q:cancelTasksOfKind('1')
        q:update()
        lu.assertEquals(t1:getCount(), 2)
        lu.assertEquals(t2:getCount(), 3)
        lu.assertEquals(q:length(), 1)

        q:update()
        lu.assertEquals(t1:getCount(), 2)
        lu.assertEquals(t2:getCount(), 4)
        lu.assertEquals(q:length(), 0)
    end,

    testCancelTasksOfMultipleKinds = function()
        local t1 = CountingTask.new{kind='1', start=1, limit=2}
        local t2 = CountingTask.new{kind='2', start=1, limit=2}
        local t3 = CountingTask.new{kind='3', start=1, limit=2}

        local q = TaskQueue.new()
        q:submit(t1, t2, t3)

        q:cancelTasksOfKind('1', '3')
        q:blockingDrain()
        lu.assertEquals(t1:getCount(), 1)
        lu.assertEquals(t2:getCount(), 2)
        lu.assertEquals(t3:getCount(), 1)
    end,

    testBlockingDrain = function()
        local t1 = CountingTask.new{kind='1', start=1, limit=5}
        local t2 = CountingTask.new{kind='2', start=3, limit=10}

        local q = TaskQueue.new()
        q:submit(t1)
        q:submit(t2)

        q:blockingDrain()
        lu.assertEquals(t1:getCount(), 5)
        lu.assertEquals(t2:getCount(), 10)
        lu.assertEquals(q:length(), 0)
    end,

    testCancelAll = function()
        local c1 = CountingTask.new()
        local c2 = CountingTask.new()
        local c3 = CountingTask.new()
        
        local q = TaskQueue.new()
        q:submit(c1, c2, c3)
        q:update()
        q:update()

        q:cancelAll()
        lu.assertEquals(c1:getCount(), 2)
        lu.assertEquals(c2:getCount(), 0)
        lu.assertEquals(c3:getCount(), 0)
    end,

    testQueueInstancesAreSegregated = function()
        -- checking that it's safe that a table is assigned directly to field and not in constructor
        -- how does it end up with a different instance?
        -- dunno, but it does.

        local q1 = TaskQueue.new()
        local q2 = TaskQueue.new()
        q1:submit(CountingTask.new())

        lu.assertEquals(q1:length(), 1)
        lu.assertEquals(q2:length(), 0)
    end,

    testRecursiveTaskPrevented = function()
        local calls = 0
        local q = TaskQueue.new()
        local t = TaskQueueTask.new{
            kind = 'recursion',
            run = function()
                calls = calls + 1
                q:update()
                return false
            end,
        }
        q:submit(t)

        q:update()
        lu.assertEquals(calls, 1)
        q:update()
        lu.assertEquals(calls, 2)
    end,

    testTaskWithoutBooleanReturnIsError = function()
        local q = TaskQueue.new()
        local t = TaskQueueTask.new{
            kind = 'nothing',
            run = function()
                
            end,
        }
        q:submit(t)
        lu.assertErrorMsgContains(
            'task of kind "nothing" did not return a boolean - task must return true to stop or false to continue', 
            function() 
                q:update()
            end
        )
    end,
}
