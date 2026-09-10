--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]] --

-- offline analyzer for macroTorch [cpBuild] / [cpBuildT] entries (phase 30,
-- plan 03, route A). Reads a SuperMacro.lua SavedVariables file given on
-- the command line, extracts the MACRO_TORCH_LOG block with string/comment
-- aware bracket matching, executes it in an empty sandbox and hands the
-- parsed message ring to the caller. The harness above is copied from
-- tools/cpdamage.lua, which stays byte-untouched (D-07); the recognition,
-- statistics and report layers below consume the two terse cpBuild line
-- families only: '[cpBuild] skill t=... cp=... e=...' cast samples and
-- '[cpBuildT] ok t=...' / '[cpBuildT] fail' window results.
-- Lua 5.0 dialect (D-15): no length operator, no table-form string.gsub
-- replacement, no %q JSON output, math mod via the % operator, args read
-- straight off the arg table. Self-contained, no external dependencies.

local MAX_FILE_BYTES = 32 * 1024 * 1024
local MAX_ENTRIES = 50000

-- cpBuild recognition prefixes (D-08): the two emitters this script parses
-- are Druid.lua cpBuildLogEvent ('[cpBuild] skill t=... cp=... e=...') and
-- the phase 30 DKI timer ('[cpBuildT] ok t=...' / '[cpBuildT] fail'). The
-- two prefix checks are disjoint by construction: a [cpBuildT] line can
-- never match PREFIX_BUILD because the tenth characters differ (a space
-- versus the T in [cpBuildT]), and equally on the longer prefix, so
-- neither family can swallow the other.
local PREFIX_BUILD = '[cpBuild] '
local PREFIX_T = '[cpBuildT] '

-- chain-break threshold in seconds (D-08): adjacent [cpBuild] casts with a
-- t gap over this value span combat boundaries or a relog, so the interval
-- is excluded from the k statistics. A file-header constant, not a game
-- option.
local BREAK_THRESHOLD = 30

-- dual pass-rate cutoffs (D-08): P(T <= D_rake - 1) with D_rake defaulting
-- to 9s, plus the Savagery snapshot row at 0.9 of the same duration. Both
-- rows are always reported.
local DRAKE_DEFAULT = 9
local SAVAGERY_FACTOR = 0.9

-- flag literals are spelled via concatenation so no string in this file
-- contains an adjacent hyphen pair (the parenthesis gate strips line
-- comments before short strings, so an in-string double hyphen would eat
-- the rest of its line and trip the bracket balance)
local FLAG_SELFTEST = '-' .. '-selftest'
local FLAG_JSON_OUT = '-' .. '-json-out'
local FLAG_RAKE_DUR = '-' .. '-rake-dur'

-- k histogram buckets (D-08 locked intervals): label count is edge count
-- plus one, and the 1.5s edge is the judgment line. Chain-broken intervals
-- never reach these buckets.
local K_BUCKET_EDGES = { 1.5, 2, 3, 5, 10 }
local K_BUCKET_LABELS = { '[<1.5)', '[1.5,2)', '[2,3)', '[3,5)', '[5,10)', '[>=10)' }

-- T histogram buckets: planner-chosen edges surrounding the 8s / 7.1s
-- pass cutoffs; retune here if the client thresholds ever move.
local T_BUCKET_EDGES = { 4, 6, 8, 10, 12 }
local T_BUCKET_LABELS = { '[<4)', '[4,6)', '[6,8)', '[8,10)', '[10,12)', '[>=12)' }

-- count a contiguous 1..n array with ipairs (Lua 5.0 has no length
-- operator; the message ring and the entry lists are always contiguous
-- because the client trims them with table.remove)
function countList(list)
    local n = 0
    for _ in ipairs(list) do
        n = n + 1
    end
    return n
end

-- read a whole file as one string; refuse files over 32MB (DoS ceiling)
function readAll(path)
    local file = io.open(path, 'r')
    if not file then
        return nil
    end
    local size = file:seek('end')
    if size and size > MAX_FILE_BYTES then
        file:close()
        return nil
    end
    file:seek('set')
    local text = file:read('*a')
    file:close()
    return text
end

-- count the line number of a byte offset; used for error reporting only
local function lineNumberOf(text, pos)
    local count = 1
    local from = 1
    while true do
        local nl = string.find(text, '\n', from, true)
        if not nl or nl >= pos then
            break
        end
        count = count + 1
        from = nl + 1
    end
    return count
end

-- locate the MACRO_TORCH_LOG marker, walk to the first opening brace and
-- return the full 'MACRO_TORCH_LOG = { ... }' segment text as one string.
-- A 'nil' declaration on the way means the log was cleared before the last
-- save and reports 'empty log declared' instead. The brace walk is a
-- character state machine over four surfaces (plain code, line comments,
-- block comments, strings) so the JSON bodies stored inside the strings -
-- which are full of braces and quotes - can never shift the balance count.
-- Short strings honour the backslash escape (which covers \\, \", \' and
-- the \ddd decimal form: a backslash always skips the following byte, and
-- decimal digits can never fake a closing quote), and long strings of the
-- [=[ ... ]=] family are skipped whole, mirroring the bracket-check strip
-- order. Returns nil plus an error message (with the line number inside)
-- when the block is absent or unbalanced.
function extractMacroTorchLog(text)
    if not text then
        return nil, 'empty file text'
    end
    local len = string.len(text)
    local markerAt = string.find(text, 'MACRO_TORCH_LOG', 1, true)
    if not markerAt then
        return nil, 'no MACRO_TORCH_LOG marker in the file'
    end
    local pos = markerAt
    local line = lineNumberOf(text, markerAt)
    while pos <= len do
        local byte = string.byte(text, pos)
        if byte == 10 then
            line = line + 1
            pos = pos + 1
        elseif byte == 123 then
            break
        elseif byte == 110 and string.sub(text, pos, pos + 2) == 'nil' then
            return nil, 'empty log declared'
        else
            pos = pos + 1
        end
    end
    if pos > len then
        return nil, 'no opening brace after the MACRO_TORCH_LOG marker'
    end
    local startLine = line
    local depth = 0
    while pos <= len do
        local byte = string.byte(text, pos)
        local nextByte = string.byte(text, pos + 1)
        if byte == 10 then
            line = line + 1
            pos = pos + 1
        elseif byte == 45 and nextByte == 45 and
                string.byte(text, pos + 2) == 91 and string.byte(text, pos + 3) == 91 then
            -- block comment: skip to the closing ]] (comments do not nest)
            local closeAt = string.find(text, ']]', pos + 4, true)
            if not closeAt then
                return nil, 'unterminated block comment at line ' .. tostring(line)
            end
            pos = closeAt + 2
        elseif byte == 45 and nextByte == 45 then
            -- line comment: skip to the next newline
            pos = pos + 2
            while pos <= len do
                if string.byte(text, pos) == 10 then
                    break
                end
                pos = pos + 1
            end
        elseif byte == 91 then
            -- possible long string opener ([=[ ... ]=] with any run of
            -- equal signs): braces inside long strings must not count
            local eqCount = 0
            local scanPos = pos + 1
            while string.byte(text, scanPos) == 61 do
                eqCount = eqCount + 1
                scanPos = scanPos + 1
            end
            if string.byte(text, scanPos) == 91 then
                local closeTag = ']' .. string.rep('=', eqCount) .. ']'
                local closeAt = string.find(text, closeTag, scanPos + 1, true)
                if not closeAt then
                    return nil, 'unterminated long string at line ' .. tostring(line)
                end
                pos = closeAt + string.len(closeTag)
            else
                pos = pos + 1
            end
        elseif byte == 34 or byte == 39 then
            -- short string literal: a backslash skips the following byte so
            -- escaped quotes can never fake the closing quote
            local quote = byte
            pos = pos + 1
            while pos <= len do
                local sbyte = string.byte(text, pos)
                if sbyte == 92 then
                    pos = pos + 2
                elseif sbyte == quote then
                    break
                else
                    pos = pos + 1
                end
            end
            if pos > len then
                return nil, 'unterminated string at line ' .. tostring(line)
            end
            pos = pos + 1
        else
            if byte == 123 then
                depth = depth + 1
            elseif byte == 125 then
                depth = depth - 1
                if depth == 0 then
                    return string.sub(text, markerAt, pos)
                end
            end
            pos = pos + 1
        end
    end
    return nil, 'unbalanced braces in the MACRO_TORCH_LOG block (opened at line ' ..
        tostring(startLine) .. ')'
end

-- interpreter shim: 5.0/5.1 provide loadstring, 5.2+ provide load with the
-- environment argument. Both paths run the block against an empty
-- environment table (no io/os/dofile or any other global) so the extracted
-- SavedVariables segment can never execute host code.
local load_chunk = loadstring or load

function loadBlockSandboxed(block)
    if not load_chunk then
        return nil, 'no chunk loader in this interpreter'
    end
    local env = {}
    local fn, loadErr = nil, nil
    if loadstring ~= nil then
        -- Lua 5.0 / 5.1 path: compile the segment with loadstring, then pin
        -- the chunk environment to the empty sandbox table. The pcall wrap
        -- plus the function-type check reports a syntax error as a message
        -- instead of crashing the analyzer.
        local ok, compiled, compileErr = pcall(loadstring, block)
        if not ok or type(compiled) ~= 'function' then
            return nil, 'block compile failed: ' .. tostring(compileErr or compiled)
        end
        if setfenv ~= nil then setfenv(compiled, env) end
        fn = compiled
    else
        -- Lua 5.2+ path: load takes the environment table directly.
        fn, loadErr = load(block, '@sv_block', 't', env)
        if not fn then
            return nil, 'block compile failed: ' .. tostring(loadErr)
        end
    end
    local ran, runErr = pcall(fn)
    if not ran then
        return nil, runErr
    end
    return env
end

-- run the extracted block in the sandbox and read the message list off the
-- MACRO_TORCH_LOG table handed back by the environment. Returns a package:
-- { ok = true, messages = table } on success, or { ok = false, reason = }
-- when the log is nil / cleared / not a table / has no messages list
-- (friendly notes - the caller prints the reason and exits 0 because an
-- empty log is not an error). A sandbox execution failure returns nil plus
-- the error string instead; the caller treats that as a hard error (exit 1)
-- because the file did not execute as a Lua table block.
function getMessages(block)
    local env, envErr = loadBlockSandboxed(block)
    if not env then
        return nil, tostring(envErr)
    end
    local root = env.MACRO_TORCH_LOG
    if root == nil then
        return { ok = false, reason = 'MACRO_TORCH_LOG is nil in this file (cleared before the last save)' }
    end
    if type(root) ~= 'table' then
        return { ok = false, reason = 'MACRO_TORCH_LOG is not a table in this file' }
    end
    if next(root) == nil then
        return { ok = false, reason = 'MACRO_TORCH_LOG is an empty table in this file' }
    end
    local messages = root['messages']
    if messages == nil then
        messages = root.messages
    end
    if type(messages) ~= 'table' then
        return { ok = false, reason = 'MACRO_TORCH_LOG has no messages list' }
    end
    return { ok = true, messages = messages }
end

-- strict recursive-descent JSON decoder (D-13): exactly six forms (object,
-- array, string, number, true, false, null), a nesting depth cap against
-- hostile input, and nil plus an error message on any malformed body.
-- Numbers pass two Lua 5.0 legal pre-check patterns (plain and scientific
-- notation, no capture groups - a capture followed by a quantifier is a
-- malformed pattern on 5.0/5.1) with tonumber under pcall as the final
-- gate. String escapes are exactly the interop set the in-game encoder
-- produces: quote, backslash, slash and \n/\r/\t plus the four-hex \u00XX
-- form; no decimal \ddd escapes (the client never writes them).
function decodeJson(str)
    if type(str) ~= 'string' then
        return nil, 'decode input is not a string'
    end
    local pos = 1
    local len = string.len(str)
    local function skipWs()
        while pos <= len do
            local byte = string.byte(str, pos)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
                pos = pos + 1
            else
                return
            end
        end
    end
    local function parseString()
        pos = pos + 1
        local out = {}
        while pos <= len do
            local byte = string.byte(str, pos)
            if byte == 34 then
                pos = pos + 1
                return table.concat(out)
            elseif byte == 92 then
                local esc = string.byte(str, pos + 1)
                if esc == 34 then
                    -- string.char(34) keeps this file free of bare double
                    -- quote bytes inside short strings, which the bracket
                    -- gate's strip order would otherwise mis-pair
                    table.insert(out, string.char(34))
                    pos = pos + 2
                elseif esc == 92 then
                    table.insert(out, '\\')
                    pos = pos + 2
                elseif esc == 47 then
                    table.insert(out, '/')
                    pos = pos + 2
                elseif esc == 110 then
                    table.insert(out, '\n')
                    pos = pos + 2
                elseif esc == 114 then
                    table.insert(out, '\r')
                    pos = pos + 2
                elseif esc == 116 then
                    table.insert(out, '\t')
                    pos = pos + 2
                elseif esc == 117 then
                    local code = tonumber(string.sub(str, pos + 2, pos + 5), 16)
                    if not code then
                        return nil, 'bad hex escape in string'
                    end
                    table.insert(out, string.char(code))
                    pos = pos + 6
                else
                    return nil, 'unknown escape in string'
                end
            elseif byte < 32 then
                return nil, 'raw control byte in string'
            else
                table.insert(out, string.sub(str, pos, pos))
                pos = pos + 1
            end
        end
        return nil, 'unterminated string'
    end
    local function parseNumber()
        local from = pos
        if string.byte(str, pos) == 45 then
            pos = pos + 1
        end
        while pos <= len do
            local byte = string.byte(str, pos)
            if byte >= 48 and byte <= 57 then
                pos = pos + 1
            else
                break
            end
        end
        if string.byte(str, pos) == 46 then
            pos = pos + 1
            while pos <= len do
                local byte = string.byte(str, pos)
                if byte >= 48 and byte <= 57 then
                    pos = pos + 1
                else
                    break
                end
            end
        end
        local expByte = string.byte(str, pos)
        if expByte == 101 or expByte == 69 then
            pos = pos + 1
            local signByte = string.byte(str, pos)
            if signByte == 43 or signByte == 45 then
                pos = pos + 1
            end
            while pos <= len do
                local byte = string.byte(str, pos)
                if byte >= 48 and byte <= 57 then
                    pos = pos + 1
                else
                    break
                end
            end
        end
        if pos == from then
            return nil, 'malformed number'
        end
        local token = string.sub(str, from, pos - 1)
        local plainOk = string.find(token, '^-?%d+%.?%d*$')
        local sciOk = string.find(token, '^-?%d+%.?%d*[eE][+-]?%d+$')
        if not plainOk and not sciOk then
            return nil, 'malformed number'
        end
        local okNum, num = pcall(tonumber, token)
        if not okNum or num == nil then
            return nil, 'malformed number'
        end
        return num
    end
    local parseValue
    local parseObject
    local parseArray
    parseValue = function(depth)
        if depth > 16 then
            return nil, 'nesting depth cap exceeded'
        end
        skipWs()
        local byte = string.byte(str, pos)
        if not byte then
            return nil, 'unexpected end of input'
        end
        if byte == 123 then
            return parseObject(depth + 1)
        end
        if byte == 91 then
            return parseArray(depth + 1)
        end
        if byte == 34 then
            return parseString()
        end
        if byte == 116 then
            if string.sub(str, pos, pos + 3) == 'true' then
                pos = pos + 4
                return true
            end
            return nil, 'bad token'
        end
        if byte == 102 then
            if string.sub(str, pos, pos + 4) == 'false' then
                pos = pos + 5
                return false
            end
            return nil, 'bad token'
        end
        if byte == 110 then
            if string.sub(str, pos, pos + 3) == 'null' then
                pos = pos + 4
                return nil, nil
            end
            return nil, 'bad token'
        end
        if byte == 45 or (byte >= 48 and byte <= 57) then
            return parseNumber()
        end
        return nil, 'unexpected character'
    end
    parseObject = function(depth)
        pos = pos + 1
        local obj = {}
        skipWs()
        if string.byte(str, pos) == 125 then
            pos = pos + 1
            return obj
        end
        while true do
            skipWs()
            if string.byte(str, pos) ~= 34 then
                return nil, 'expected string key'
            end
            local key = parseString()
            if not key then
                return nil, 'malformed object key'
            end
            skipWs()
            if string.byte(str, pos) ~= 58 then
                return nil, 'expected colon after key'
            end
            pos = pos + 1
            local value, valueErr = parseValue(depth)
            if valueErr then
                return nil, valueErr
            end
            obj[key] = value
            skipWs()
            local byte = string.byte(str, pos)
            if byte == 44 then
                pos = pos + 1
            elseif byte == 125 then
                pos = pos + 1
                return obj
            else
                return nil, 'expected comma or closing brace'
            end
        end
    end
    parseArray = function(depth)
        pos = pos + 1
        local arr = {}
        skipWs()
        if string.byte(str, pos) == 93 then
            pos = pos + 1
            return arr
        end
        local index = 0
        while true do
            local value, valueErr = parseValue(depth)
            if valueErr then
                return nil, valueErr
            end
            index = index + 1
            arr[index] = value
            skipWs()
            local byte = string.byte(str, pos)
            if byte == 44 then
                pos = pos + 1
            elseif byte == 93 then
                pos = pos + 1
                return arr
            else
                return nil, 'expected comma or closing bracket'
            end
        end
    end
    local value, valueErr = parseValue(0)
    if valueErr then
        return nil, valueErr
    end
    skipWs()
    if pos <= len then
        return nil, 'trailing characters after value'
    end
    return value
end

-- strict JSON scalar encoder, isomorphic with the in-game
-- macroTorch.jsonEncodeScalar contract: nil -> null, booleans -> true /
-- false, strings escaped (backslash, double quote and every control byte
-- below 32 as the uppercase \u00XX form), numbers rendered through the
-- stable cross-version representation (integral values as plain integers,
-- everything else at four decimals) so archives compare cleanly between
-- interpreter generations.
function encodeScalar(v)
    if v == nil then
        return 'null'
    end
    local tv = type(v)
    if tv == 'boolean' then
        if v then
            return 'true'
        end
        return 'false'
    end
    if tv == 'number' then
        if v == math.floor(v) then
            return string.format('%.0f', v)
        end
        return string.format('%.4f', v)
    end
    if tv == 'string' then
        local escaped = string.gsub(v, '[\1-\31\\"]', function(c)
            local byte = string.byte(c)
            if byte == 92 then
                return '\\\\'
            end
            if byte == 34 then
                return '\\"'
            end
            return string.format('\\u00%02X', byte)
        end)
        return '"' .. escaped .. '"'
    end
    return 'null'
end

-- recursive JSON writer for the result document: contiguous 1..n tables
-- serialise as arrays, every other table as an object keyed through
-- encodeScalar. Depth capped against accidental self-reference.
function encodeValue(v, depth)
    depth = depth or 1
    if depth > 16 then
        return 'null'
    end
    if type(v) ~= 'table' then
        return encodeScalar(v)
    end
    local total = 0
    local nMax = 0
    local numericCount = 0
    for k, _ in pairs(v) do
        total = total + 1
        if type(k) == 'number' and k >= 1 and k == math.floor(k) then
            numericCount = numericCount + 1
            if k > nMax then
                nMax = k
            end
        end
    end
    if numericCount == total and numericCount == nMax then
        local parts = {}
        for i = 1, nMax do
            table.insert(parts, encodeValue(v[i], depth + 1))
        end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local parts = {}
    for k, val in pairs(v) do
        table.insert(parts, encodeScalar(k) .. ':' .. encodeValue(val, depth + 1))
    end
    return '{' .. table.concat(parts, ',') .. '}'
end
-- cpBuild recognition layer (plan 30-03): parseSamples consumes the terse
-- space-separated line families instead of the [cpDamage] JSON bodies. The
-- chain shape replicates the parseEntries recognition template from
-- cpdamage (exact prefix check via string.sub against the prefix length,
-- pcall-guarded body parse, badLines counter, MAX_ENTRIES cap with a
-- once-per-run truncation warning, silent skip of every other line). A bad
-- sample never aborts the batch (T-30-08).

-- split a body string on single spaces; consecutive spaces produce empty
-- tokens which the field checks reject downstream
local function splitSpaces(body)
    local parts = {}
    local from = 1
    local len = string.len(body)
    while true do
        local sp = string.find(body, ' ', from, true)
        if not sp then
            table.insert(parts, string.sub(body, from))
            break
        end
        table.insert(parts, string.sub(body, from, sp - 1))
        from = sp + 1
        if from > len then
            break
        end
    end
    return parts
end

-- tokenNumber(token, key): the token must start with the two-char key
-- ('t=', 'cp=' or 'e=') and the rest must be a Lua 5.0-legal decimal
-- number (plain or scientific form, the same pre-check pattern discipline
-- as decodeJson) with tonumber under pcall as the final gate. Returns the
-- number or nil.
local function tokenNumber(token, key)
    if string.sub(token, 1, 2) ~= key then
        return nil
    end
    local val = string.sub(token, 3)
    local plainOk = string.find(val, '^%d+%.?%d*$')
    local sciOk = string.find(val, '^%d+%.?%d*[eE][+-]?%d+$')
    if not plainOk and not sciOk then
        return nil
    end
    local okNum, num = pcall(tonumber, val)
    if not okNum or num == nil then
        return nil
    end
    return num
end

-- parse one [cpBuild] body per the fixed field-order contract of
-- cpBuildLogEvent (Druid.lua): skill token first (non-empty, no spaces),
-- then the literal t= pair, then cp=, then e=, space-separated in that
-- exact order. Returns a sample record or nil.
local function parseCastBody(body)
    local parts = splitSpaces(body)
    if countList(parts) ~= 4 then
        return nil
    end
    if parts[1] == '' then
        return nil
    end
    local t = tokenNumber(parts[2], 't=')
    local cp = tokenNumber(parts[3], 'cp=')
    local e = tokenNumber(parts[4], 'e=')
    if t == nil or cp == nil or e == nil then
        return nil
    end
    return { skill = parts[1], t = t, cp = cp, e = e }
end

-- parse one [cpBuildT] ok body: exactly 'ok t=<number>'; returns the
-- seconds number or nil ('fail' is matched as an exact string by the
-- caller, anything else under the prefix is malformed)
local function parseTOkBody(body)
    local parts = splitSpaces(body)
    if countList(parts) ~= 2 then
        return nil
    end
    if parts[1] ~= 'ok' then
        return nil
    end
    return tokenNumber(parts[2], 't=')
end

-- messages -> cpBuild samples (D-08 recognition chain): exact prefix
-- checks against PREFIX_BUILD and PREFIX_T (mutually exclusive by
-- construction - see the header note), prefix strip, pcall-guarded body
-- parse. Cast lines yield { skill, t, cp, e } records, 'ok t=' lines yield
-- ok window seconds, 'fail' lines increment failCount. Malformed lines
-- under either prefix increment badLines and are skipped - a bad sample
-- never aborts the batch. Everything else is skipped silently. A 50k cap
-- truncates hostile logs with a once-per-run warning. Returns casts
-- (ordered), okTs (ordered), failCount, badLines and truncated.
function parseSamples(messages)
    local casts = {}
    local okTs = {}
    local failCount = 0
    local badLines = 0
    local truncated = false
    local entryCount = 0
    local buildPrefixLen = string.len(PREFIX_BUILD)
    local tPrefixLen = string.len(PREFIX_T)
    local total = countList(messages)
    for i = 1, total do
        local line = messages[i]
        if type(line) == 'string' then
            local isBuild = string.sub(line, 1, buildPrefixLen) == PREFIX_BUILD
            local isT = string.sub(line, 1, tPrefixLen) == PREFIX_T
            if isBuild or isT then
                if entryCount >= MAX_ENTRIES then
                    if not truncated then
                        truncated = true
                        io.write('warning: entry cap ' .. tostring(MAX_ENTRIES) ..
                            ' reached, remaining lines ignored\n')
                    end
                    break
                end
                if isBuild then
                    local body = string.sub(line, buildPrefixLen + 1)
                    local okCast, castRec = pcall(parseCastBody, body)
                    if not okCast or castRec == nil then
                        badLines = badLines + 1
                    else
                        table.insert(casts, castRec)
                        entryCount = entryCount + 1
                    end
                else
                    local body = string.sub(line, tPrefixLen + 1)
                    if body == 'fail' then
                        failCount = failCount + 1
                        entryCount = entryCount + 1
                    else
                        local okT, tVal = pcall(parseTOkBody, body)
                        if not okT or tVal == nil then
                            badLines = badLines + 1
                        else
                            table.insert(okTs, tVal)
                            entryCount = entryCount + 1
                        end
                    end
                end
            end
        end
    end
    return { casts = casts, okTs = okTs, failCount = failCount,
        badLines = badLines, truncated = truncated }
end

-- statistics layer (D-08): four pure functions. Every function reads its
-- inputs as-is, never mutates them, builds fresh result tables and
-- iterates explicitly - the report path never relies on pairs ordering.

-- index of the first bucket whose edge is above v; edges are ascending
-- and the result is 1..edgeCount+1
local function bucketIndex(edges, v)
    local total = countList(edges)
    for i = 1, total do
        if v < edges[i] then
            return i
        end
    end
    return total + 1
end

-- fresh label/count bucket list for one label set
local function emptyBuckets(labels)
    local buckets = {}
    for i = 1, countList(labels) do
        buckets[i] = { label = labels[i], count = 0 }
    end
    return buckets
end

-- k = inter-cast interval between adjacent [cpBuild] casts (D-08). The
-- chain-break rule: a gap over BREAK_THRESHOLD or not positive spans
-- combat boundaries or a relog, counts as one break and the interval is
-- EXCLUDED from every k statistic. Returns { samples, mean, breaks,
-- below15, buckets = list of { label, count } }; mean stays nil when no
-- interval is counted.
function buildKStats(casts)
    local buckets = emptyBuckets(K_BUCKET_LABELS)
    local samples = 0
    local sum = 0
    local breaks = 0
    local below15 = 0
    local total = countList(casts)
    for i = 1, total - 1 do
        local k = casts[i + 1].t - casts[i].t
        if k > BREAK_THRESHOLD or k <= 0 then
            breaks = breaks + 1
        else
            samples = samples + 1
            sum = sum + k
            if k < 1.5 then
                below15 = below15 + 1
            end
            local idx = bucketIndex(K_BUCKET_EDGES, k)
            buckets[idx].count = buckets[idx].count + 1
        end
    end
    local mean = nil
    if samples > 0 then
        mean = sum / samples
    end
    return { samples = samples, mean = mean, breaks = breaks,
        below15 = below15, buckets = buckets }
end

-- T = bite-to-full-build window seconds (D-08): the mean over the ok
-- samples, the sample count and a distribution histogram over the
-- T_BUCKET_EDGES bands.
function buildTStats(okTs)
    local buckets = emptyBuckets(T_BUCKET_LABELS)
    local samples = 0
    local sum = 0
    local total = countList(okTs)
    for i = 1, total do
        local t = okTs[i]
        samples = samples + 1
        sum = sum + t
        local idx = bucketIndex(T_BUCKET_EDGES, t)
        buckets[idx].count = buckets[idx].count + 1
    end
    local mean = nil
    if samples > 0 then
        mean = sum / samples
    end
    return { samples = samples, mean = mean, buckets = buckets }
end

-- dual pass rates (D-08): P(T <= D_rake - 1) on the rakeDur row and the
-- Savagery-adjusted P(T <= 0.9 * D_rake - 1) on the savagery row. Every ok
-- window at or below the cutoff passes; fail windows count as not attained
-- (D-04 bypass 1), so the denominator is the ok count plus the fail count.
-- rate stays nil when the denominator is zero. drake falls back to
-- DRAKE_DEFAULT when tonumber fails; both rows are always computed and
-- reported.
function calculatePassRates(okTs, failCount, drake)
    local d = tonumber(drake)
    if d == nil then
        d = DRAKE_DEFAULT
    end
    local denominator = countList(okTs) + failCount
    local function tally(cutoff)
        local passed = 0
        local total = countList(okTs)
        for i = 1, total do
            if okTs[i] <= cutoff then
                passed = passed + 1
            end
        end
        local rate = nil
        if denominator > 0 then
            rate = passed / denominator
        end
        return { passed = passed, denominator = denominator, rate = rate }
    end
    local rakeRow = tally(d - 1)
    local savRow = tally(d * SAVAGERY_FACTOR - 1)
    return {
        rakeDur = { d = d, cutoff = d - 1, passed = rakeRow.passed,
            denominator = rakeRow.denominator, rate = rakeRow.rate },
        savagery = { d = d * SAVAGERY_FACTOR, cutoff = d * SAVAGERY_FACTOR - 1,
            passed = savRow.passed, denominator = savRow.denominator,
            rate = savRow.rate },
    }
end

-- per-skill cast counts: a fresh table keyed by the lowercased skill token
-- (the client emits Claw / Shred / Rake; any other token is counted too,
-- never discarded) plus the grand total.
function perSkillCasts(casts)
    local skills = {}
    local total = 0
    local n = countList(casts)
    for i = 1, n do
        local name = string.lower(casts[i].skill)
        if skills[name] == nil then
            skills[name] = 1
        else
            skills[name] = skills[name] + 1
        end
        total = total + 1
    end
    return { skills = skills, total = total }
end

-- output section (D-08): terminal report, json archive, usage and the CLI
-- entry.

-- rendering helper: nil pass rates render as '-', rates as percentages
local function fmtRate(row)
    if row.rate == nil then
        return '-'
    end
    return string.format('%.1f%%', row.rate * 100)
end

-- terminal report: source line, per-skill cast counts, the k statistics
-- (mean, samples, breaks, below-1.5 share, six bucket lines), the T
-- statistics (mean, sample count, six bucket lines), the dual pass-rate
-- lines (both cutoffs always printed, D-08), the ok/fail window matrix and
-- the dropped-line / truncation warnings.
function printReport(res)
    local sep = string.rep('=', 64)
    io.write(sep .. '\n')
    io.write('cpBuild report\n')
    io.write('source: ' .. tostring(res.source) .. '\n')
    local cc = res.castCounts
    io.write('cast counts:\n')
    io.write('  claw  ' .. tostring(cc.claw) .. '\n')
    io.write('  shred ' .. tostring(cc.shred) .. '\n')
    io.write('  rake  ' .. tostring(cc.rake) .. '\n')
    io.write('  total ' .. tostring(cc.total) .. '\n')
    local ks = res.kStats
    io.write('k stats (inter-cast interval):\n')
    if ks.samples == 0 then
        io.write('  no intervals (need 2 or more chained casts)\n')
    else
        io.write(string.format('  mean %.2f s over %d intervals, %d chain breaks, %d below 1.5s (%.0f%%)\n',
            ks.mean, ks.samples, ks.breaks, ks.below15, 100 * ks.below15 / ks.samples))
    end
    io.write('  buckets: ')
    for i = 1, countList(ks.buckets) do
        io.write(ks.buckets[i].label .. ' ' .. tostring(ks.buckets[i].count) .. '  ')
    end
    io.write('\n')
    local ts = res.tStats
    io.write('T stats (bite to full build window):\n')
    if ts.samples == 0 then
        io.write('  no ok windows\n')
    else
        io.write(string.format('  mean T = %.2f s over %d windows\n', ts.mean, ts.samples))
    end
    io.write('  buckets: ')
    for i = 1, countList(ts.buckets) do
        io.write(ts.buckets[i].label .. ' ' .. tostring(ts.buckets[i].count) .. '  ')
    end
    io.write('\n')
    local pr = res.passRates
    io.write('pass rates:\n')
    io.write(string.format('  rakeDur  d=%.1f cutoff=%.1f: %s (%d / %d)\n',
        pr.rakeDur.d, pr.rakeDur.cutoff, fmtRate(pr.rakeDur),
        pr.rakeDur.passed, pr.rakeDur.denominator))
    io.write(string.format('  savagery d=%.1f cutoff=%.1f: %s (%d / %d)\n',
        pr.savagery.d, pr.savagery.cutoff, fmtRate(pr.savagery),
        pr.savagery.passed, pr.savagery.denominator))
    local wm = res.windowMatrix
    io.write(string.format('window matrix: ok %d / fail %d\n', wm.ok, wm.fail))
    if res.dropped.badLines > 0 then
        io.write('warning: ' .. tostring(res.dropped.badLines) ..
            ' malformed [cpBuild] / [cpBuildT] lines skipped\n')
    end
    if res.truncated then
        io.write('warning: entry cap ' .. tostring(MAX_ENTRIES) ..
            ' reached, remaining lines ignored\n')
    end
end

-- json result archive (D-08): encodeValue builds the whole document from
-- the res table through encodeScalar (the same scalar contract as the
-- in-game encoder). An io.open failure prints the error and exits 1.
function writeJsonOut(path, res)
    local file = io.open(path, 'w')
    if not file then
        io.write('cannot open json output file for writing: ' .. tostring(path) .. '\n')
        os.exit(1)
    end
    file:write(encodeValue(res), '\n')
    file:close()
end

-- usage text with the three subcommand forms; any form may also carry the
-- rake duration override flag plus a number of seconds
function printUsage()
    io.write('usage: lua tools/cpbuild.lua <path/to/SuperMacro.lua>\n')
    io.write('usage: lua tools/cpbuild.lua <path/to/SuperMacro.lua> ' ..
        FLAG_JSON_OUT .. ' <file>\n')
    io.write('usage: lua tools/cpbuild.lua ' .. FLAG_SELFTEST .. '\n')
    io.write('any form may also carry ' .. FLAG_RAKE_DUR ..
        ' <seconds> to override the rake duration (default ' .. tostring(DRAKE_DEFAULT) .. ')\n')
end

-- CLI entry: parse the arguments, then either run the self-test battery or
-- the full read -> extract -> sandbox -> parse -> stats -> report chain
-- with the optional json archive. The first non-flag argument is the
-- SavedVariables path; the json-out target, the rake duration override and
-- the selftest mode ride the flag constants. The self-test path touches no
-- external files.
function main(args)
    if not args or not args[1] then
        printUsage()
        os.exit(1)
    end
    local selftestMode = false
    local jsonOutPath = nil
    local svPath = nil
    local drake = DRAKE_DEFAULT
    local i = 1
    while args[i] ~= nil do
        local a = args[i]
        if a == FLAG_SELFTEST then
            selftestMode = true
            i = i + 1
        elseif a == FLAG_JSON_OUT then
            if args[i + 1] == nil then
                io.write('error: ' .. FLAG_JSON_OUT .. ' requires a file path\n')
                printUsage()
                os.exit(1)
            end
            jsonOutPath = args[i + 1]
            i = i + 2
        elseif a == FLAG_RAKE_DUR then
            if args[i + 1] == nil then
                io.write('error: ' .. FLAG_RAKE_DUR .. ' requires a number of seconds\n')
                printUsage()
                os.exit(1)
            end
            local dur = tonumber(args[i + 1])
            if dur == nil then
                io.write('error: ' .. FLAG_RAKE_DUR .. ' expects a numeric value, got: ' ..
                    tostring(args[i + 1]) .. '\n')
                printUsage()
                os.exit(1)
            end
            drake = dur
            i = i + 2
        else
            if svPath ~= nil then
                io.write('error: unexpected extra argument: ' .. tostring(a) .. '\n')
                printUsage()
                os.exit(1)
            end
            svPath = a
            i = i + 1
        end
    end
    if selftestMode then
        runSelftest()
        return
    end
    if svPath == nil then
        printUsage()
        os.exit(1)
    end
    local text = readAll(svPath)
    if not text then
        io.write('cannot read file (missing or over 32MB): ' .. tostring(svPath) .. '\n')
        os.exit(1)
    end
    local block, extractErr = extractMacroTorchLog(text)
    if not block then
        if extractErr == 'empty log declared' then
            io.write(extractErr .. '\n')
            os.exit(0)
        end
        io.write('extract failed: ' .. tostring(extractErr) .. '\n')
        os.exit(1)
    end
    local pack, sandboxErr = getMessages(block)
    if not pack then
        io.write('cannot execute extracted SV block: ' .. tostring(sandboxErr) .. '\n')
        os.exit(1)
    end
    if not pack.ok then
        io.write(pack.reason .. '\n')
        os.exit(0)
    end
    local parsed = parseSamples(pack.messages)
    local castCounts = perSkillCasts(parsed.casts)
    local res = {
        generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        source = svPath,
        castCounts = {
            claw = castCounts.skills.claw or 0,
            shred = castCounts.skills.shred or 0,
            rake = castCounts.skills.rake or 0,
            total = castCounts.total,
        },
        kStats = buildKStats(parsed.casts),
        tStats = buildTStats(parsed.okTs),
        passRates = calculatePassRates(parsed.okTs, parsed.failCount, drake),
        windowMatrix = { ok = countList(parsed.okTs), fail = parsed.failCount },
        dropped = { badLines = parsed.badLines },
        truncated = parsed.truncated,
    }
    printReport(res)
    if jsonOutPath ~= nil then
        writeJsonOut(jsonOutPath, res)
        io.write('json result written to ' .. jsonOutPath .. '\n')
    end
    os.exit(0)
end

main(arg)
