# Bounded compatibility regressions for the CVE-2025-46819 lexer backport.
# These tests do not exercise the large-memory arithmetic boundaries.
start_server {tags {"scripting"}} {
    test {Lua lexer - long strings preserve delimiter matching} {
        set result [r eval {
            local results = {}
            for _, sep in ipairs({'', '=', '==', string.rep('=', 4096)}) do
                local fn = assert(loadstring('return [' .. sep .. '[x]' .. sep .. ']'))
                results[#results + 1] = fn()
            end
            return results
        } 0]
        assert_equal {x x x x} $result
    }

    test {Lua lexer - long comments preserve delimiter matching} {
        r eval {
            for _, sep in ipairs({'', '=', '==', string.rep('=', 4096)}) do
                local fn = assert(loadstring('--[' .. sep .. '[comment]' .. sep .. ']\nreturn 42'))
                assert(fn() == 42)
            end
            return 'OK'
        } 0
    } {OK}

    test {Lua lexer - mismatched closing delimiters remain string content} {
        r eval {return [==[left]=]right]==]} 0
    } {left]=]right}

    test {Lua lexer - malformed and unfinished delimiters report errors} {
        set errors [r eval {
            local _, malformed = loadstring('return [=x')
            local _, unfinished_string = loadstring('return [=[x')
            local _, unfinished_comment = loadstring('--[=[x')
            return {malformed, unfinished_string, unfinished_comment}
        } 0]
        assert_match {*invalid long string delimiter*} [lindex $errors 0]
        assert_match {*unfinished long string*} [lindex $errors 1]
        assert_match {*unfinished long comment*} [lindex $errors 2]
        assert_equal PONG [r ping]
    }

    test {Lua lexer - configured legacy mode rejects deprecated nesting} {
        set error [r eval {
            local _, err = loadstring('return [[a[[b]]c]]')
            return err
        } 0]
        assert {[string first {nesting of [[...]] is deprecated} $error] >= 0}
    }

    test {Lua lexer - equals delimiters allow bracket content and normalize newlines} {
        set result [r eval {
            local nested = assert(loadstring('return [=[a[[b]]c]=]'))
            local newlines = assert(loadstring('return [=[\r\nfirst\r\nsecond\rthird\nfourth]=]'))
            return {nested(), newlines()}
        } 0]
        assert_equal {a[[b]]c} [lindex $result 0]
        assert_equal "first\nsecond\nthird\nfourth" [lindex $result 1]
    }
}
