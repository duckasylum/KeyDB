# CVE-2025-46819 regressions adapted from Redis 6.2 commit
# ef22554057e50c67d0f8d0ede39483358356321f (BSD-3-Clause).
# Separate servers and released temporary references reduce peak memory.
# Requires --large-memory; run serially on a machine with sufficient RAM.
start_server {tags {"scripting large-memory external:skip"}} {
    test {Lua lexer boundary - one-GiB separator preserves string content} {
        r eval {
            local s = string.rep('=', 1024 * 1024)
            local t = {} for i = 1, 1024 do t[i] = s end
            local sep = table.concat(t)
            collectgarbage('collect')
            local code = table.concat({'return [', sep, '[x]', sep, ']'})
            sep, t, s = nil, nil, nil
            collectgarbage('collect')
            local fn = assert(loadstring(code))
            return #fn()
        } 0
    } {1}
}

start_server {tags {"scripting large-memory external:skip"}} {
    test {Lua lexer boundary - line overflow reports a clean lexer error} {
        r eval {
            local s = string.rep('\n', 1024 * 1024)
            local t = {} for i = 1, 2048 do t[i] = s end
            local lines = table.concat(t)
            t, s = nil, nil
            collectgarbage('collect')
            local fn, err = loadstring(lines)
            assert(fn == nil)
            return err
        } 0
    } {*chunk has too many lines}
}
