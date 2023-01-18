local lu <const> = import 'lib/luaunit/luaunit'
import 'util/string'

TestStringUtils = {

    testStartsWith = function()
        lu.assertTrue(util.string.startsWith('boo', 'b'))
        lu.assertFalse(util.string.startsWith('foo', 'b'))
    end,

    testStringTemplateExtension = function()
        lu.assertEquals("foo" % {}, "foo")
        lu.assertEquals("foo" % {a=1}, "foo")

        local str = "my ${adjective} template" % {adjective = "cool"}
        lu.assertEquals(str, "my cool template")

        str = "I have ${n} hats (yes, ${n})" % {n=2, m=3}
        lu.assertEquals(str, "I have 2 hats (yes, 2)")

        str = "array-like ${1} also ${2}" % {'tables', 'work'}
        lu.assertEquals(str, "array-like tables also work")
    end,

    testStringSplitWhitespaceByDefault = function()
        lu.assertEquals(util.string.split('split this   str\
            ing'), {'split', 'this', 'str', 'ing'})
    end,

    testStringSplitByDefinedSeparator = function()
        lu.assertEquals(util.string.split('cfooccbarcc', 'c'), {'foo', 'bar'})
    end,

    testStringSplitByNewLine = function()
        lu.assertEquals(util.string.split([[
l1
l2
]], '\n'), {'l1', 'l2'})
    end,

    testIndentedMultilineString = function()
        local str = -[[discarded
        |hello
        | world
  discarded
        |  indented
        |
        ]]

        lu.assertEquals(str, [[hello
 world
  indented
]])
    end,
}
