local lu <const> = import 'lib/luaunit/luaunit'
import 'lib/simploo/simploo'

class "WithGetters" {
    public {
        __construct = function(self, a, b)
            self.a = a
            self.b = b
        end,
    },
    private {
        a = 0,
        getter {
            b = '',
        },
    }
}

TestSimplooExtensions = {

    testGetter = function()
        local instance = WithGetters.new(2, "banana")
        lu.assertErrorMsgContains('accessing private member', function() _ = instance.a end)
        lu.assertEquals("banana", instance.b)
    end,

}
