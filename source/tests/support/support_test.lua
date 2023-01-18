local lu <const> = import 'lib/luaunit/luaunit'
import 'tests/support/class_mock'
local classMock <const> = testSupport.classMock
import 'util/oo'
local typeGuard <const> = util.oo.typeGuard
local instanceOf <const> = util.oo.instanceOf

class "Mocked" {
    public {
        a = 'string',
        f = function(self)
            return 'a is '..self.a
        end,
    }
}
class "SomethingElse" {}

local mock = nil

TestClassMock = {

    setUp = function()
        mock = classMock("Mocked", {
            a = 'fake',
            f = function(self)
                return 'mocked a is '..self.a
            end,
        })
    end,

    testMockPassesAsInstance = function()
        lu.assertFalse(instanceOf("SomethingElse", mock))
        lu.assertTrue(instanceOf("Mocked", mock))
        typeGuard("Mocked", mock)
    end,

    testMockReturnsMockData = function()
        lu.assertEquals(mock.a, 'fake')
        lu.assertEquals(mock:f(), 'mocked a is fake')
    end,

    testMockedFieldsMutable = function()
        mock.a = 'changed'
        lu.assertEquals(mock.a, 'changed')
        lu.assertEquals(mock:f(), 'mocked a is changed')
    end,

    testMockErrorAccessingUnmockedField = function()
        lu.assertErrorMsgContains('attempted to read undefined key b on mock of Mocked', function()
            _ = mock.b
        end)
    end,

    testMockErrorWritingUnmockedField = function()
        lu.assertErrorMsgContains('attempted to write undefined key b on mock of Mocked', function()
            mock.b = 1
        end)
    end,

    testMockErrorCallingUnmockedFunction = function()
        lu.assertErrorMsgContains('attempted to read undefined key g on mock of Mocked', function()
            mock:g()
        end)
    end,
}
