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

-- offline analyzer for macroTorch [cpDamage] entries (phase 28, plan 03).
-- Reads a SuperMacro.lua SavedVariables file given on the command line,
-- extracts the MACRO_TORCH_LOG block with string/comment aware bracket
-- matching, executes it in an empty sandbox and hands the parsed message
-- ring to the caller (Task 1 scope ends at the messages list). The strict
-- decoder, statistics, report, json archive and the full self-test land in
-- Tasks 2..4 of this plan on top of this chain.
-- Lua 5.0 dialect (D-15): no length operator, no table-form string.gsub
-- replacement, no %q JSON output, math mod via the % operator, args read
-- straight off the arg table. Self-contained, no external dependencies.

local MAX_FILE_BYTES = 32 * 1024 * 1024
local MAX_ENTRIES = 50000
local PREFIX = '[cpDamage] '

-- flag literals are spelled via concatenation so no string in this file
-- contains an adjacent hyphen pair (the parenthesis gate strips line
-- comments before short strings, so an in-string double hyphen would eat
-- the rest of its line and trip the bracket balance)
local FLAG_SELFTEST = '-' .. '-selftest'
local FLAG_JSON_OUT = '-' .. '-json-out'

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

-- field-level validation against the fixed 11-field encoder contract:
-- spell is one of claw/shred/bite, dmg and e are positive numbers,
-- energyPool/cp/t/batch are numbers, bleedCount is an integer in 0..3,
-- crit/isOoc/isBehind are booleans when present. Missing nullable fields
-- take the documented defaults (crit stays nil - undetectable crit on
-- exotic clients - while isOoc and isBehind fall back to false). Returns a
-- tonumber-normalized entry table when every field passes, else nil.
local function validateEntry(obj)
    if type(obj) ~= 'table' then
        return nil
    end
    local spell = obj['spell']
    if spell ~= 'claw' and spell ~= 'shred' and spell ~= 'bite' then
        return nil
    end
    local dmg = obj['dmg']
    local e = obj['e']
    if type(dmg) ~= 'number' or dmg <= 0 or type(e) ~= 'number' or e <= 0 then
        return nil
    end
    local energyPool = obj['energyPool']
    local cp = obj['cp']
    local t = obj['t']
    local batch = obj['batch']
    if type(energyPool) ~= 'number' or type(cp) ~= 'number' or
            type(t) ~= 'number' or type(batch) ~= 'number' then
        return nil
    end
    local bleedCount = obj['bleedCount']
    if type(bleedCount) ~= 'number' or bleedCount < 0 or bleedCount > 3 or
            bleedCount ~= math.floor(bleedCount) then
        return nil
    end
    local crit = obj['crit']
    if crit ~= nil and type(crit) ~= 'boolean' then
        return nil
    end
    local isOoc = obj['isOoc']
    if isOoc == nil then
        isOoc = false
    elseif type(isOoc) ~= 'boolean' then
        return nil
    end
    local isBehind = obj['isBehind']
    if isBehind == nil then
        isBehind = false
    elseif type(isBehind) ~= 'boolean' then
        return nil
    end
    return {
        spell = spell,
        dmg = tonumber(dmg),
        crit = crit,
        e = tonumber(e),
        energyPool = tonumber(energyPool),
        bleedCount = tonumber(bleedCount),
        isOoc = isOoc,
        isBehind = isBehind,
        cp = tonumber(cp),
        t = tonumber(t),
        batch = tonumber(batch),
    }
end

-- messages -> validated entries (D-13 recognition chain): exact 11-char
-- [cpDamage] prefix check (everything else is skipped silently), prefix
-- strip, decode under pcall, then field validation. Malformed lines and
-- invalid field sets are counted and skipped - a bad sample never aborts
-- the batch (T-28-03). A 50k entry cap truncates hostile logs with a
-- once-per-run warning (T-28-02). Tracks the min/max batch keys for the
-- report layer. Returns entries (tonumber-normalized), badLines,
-- invalidFields, truncated and the batch range.
function parseEntries(messages)
    local entries = {}
    local badLines = 0
    local invalidFields = 0
    local truncated = false
    local minBatch = nil
    local maxBatch = nil
    local entryCount = 0
    local prefixLen = string.len(PREFIX)
    local total = countList(messages)
    for i = 1, total do
        local line = messages[i]
        if type(line) == 'string' and string.sub(line, 1, prefixLen) == PREFIX then
            if entryCount >= MAX_ENTRIES then
                if not truncated then
                    truncated = true
                    io.write('warning: entry cap ' .. tostring(MAX_ENTRIES) ..
                        ' reached, remaining lines ignored\n')
                end
                break
            end
            local body = string.sub(line, prefixLen + 1)
            local ok, decoded = pcall(decodeJson, body)
            if not ok or decoded == nil then
                badLines = badLines + 1
            else
                local entry = validateEntry(decoded)
                if entry == nil then
                    invalidFields = invalidFields + 1
                else
                    table.insert(entries, entry)
                    entryCount = entryCount + 1
                    if minBatch == nil or entry.batch < minBatch then
                        minBatch = entry.batch
                    end
                    if maxBatch == nil or entry.batch > maxBatch then
                        maxBatch = entry.batch
                    end
                end
            end
        end
    end
    return { entries = entries, badLines = badLines, invalidFields = invalidFields,
        truncated = truncated, minBatch = minBatch, maxBatch = maxBatch }
end

-- stats section (D-17..D-20): three pure functions plus the per-batch
-- grouping. Every function reads entries as-is, never mutates them, and
-- builds fresh result tables (idempotent). All iteration is explicit - the
-- report path never relies on pairs ordering.

-- one bucket per spell and bleedCount tier for claw/shred (4 tiers per
-- spell plus an aggregate bucket). Column semantics locked here to avoid
-- execution ambiguity:
--   avgDmg  = per-tier damage mean, sumDmg / n                     (D-18 avg dmg)
--   avgEff  = mean of the per-sample dmg/e ratios: each sample is
--             divided first, summed, then divided by n              (D-18 avg dmg / e)
--   avgRaw  = raw single-cast damage mean, sumDmg / n with no
--             energy division at all                                (D-18 per-tier single avg)
-- Buckets with zero samples keep nil average fields; the report layer
-- renders those as '-' (Task 4).
function buildClawShredBuckets(entries)
    local spells = { 'claw', 'shred' }
    local acc = {}
    for si = 1, 2 do
        local sp = spells[si]
        acc[sp] = {}
        for tier = 0, 3 do
            acc[sp][tier] = { n = 0, sumDmg = 0, sumEff = 0 }
        end
    end
    local agg = { n = 0, sumDmg = 0, sumEff = 0 }
    local total = countList(entries)
    for i = 1, total do
        local e = entries[i]
        if e.spell == 'claw' or e.spell == 'shred' then
            local b = acc[e.spell][e.bleedCount]
            b.n = b.n + 1
            b.sumDmg = b.sumDmg + e.dmg
            b.sumEff = b.sumEff + e.dmg / e.e
            agg.n = agg.n + 1
            agg.sumDmg = agg.sumDmg + e.dmg
            agg.sumEff = agg.sumEff + e.dmg / e.e
        end
    end
    local function finalize(b)
        if b.n == 0 then
            return { n = 0, avgDmg = nil, avgEff = nil, avgRaw = nil }
        end
        return {
            n = b.n,
            avgDmg = b.sumDmg / b.n,
            avgEff = b.sumEff / b.n,
            avgRaw = b.sumDmg / b.n,
        }
    end
    local buckets = {}
    for si = 1, 2 do
        local sp = spells[si]
        local ob = {}
        for tier = 0, 3 do
            ob[tier] = finalize(acc[sp][tier])
        end
        buckets[sp] = ob
    end
    return { buckets = buckets, aggregate = finalize(agg) }
end

-- OOC tier table (D-19): only samples with isOoc == true AND isBehind ==
-- true enter this table (front-position shred is unusable, so face samples
-- never vote). Bucketed by bleedCount 0..3 per spell; the metric is the
-- single-cast average damage and the sample count.
function buildOocTiers(entries)
    local spells = { 'claw', 'shred' }
    local acc = {}
    for si = 1, 2 do
        local sp = spells[si]
        acc[sp] = {}
        for tier = 0, 3 do
            acc[sp][tier] = { n = 0, sumDmg = 0 }
        end
    end
    local total = countList(entries)
    for i = 1, total do
        local e = entries[i]
        if (e.spell == 'claw' or e.spell == 'shred') and e.isOoc and e.isBehind then
            local b = acc[e.spell][e.bleedCount]
            b.n = b.n + 1
            b.sumDmg = b.sumDmg + e.dmg
        end
    end
    local buckets = {}
    for si = 1, 2 do
        local sp = spells[si]
        local ob = {}
        for tier = 0, 3 do
            local b = acc[sp][tier]
            if b.n == 0 then
                ob[tier] = { n = 0, avgDmg = nil }
            else
                ob[tier] = { n = b.n, avgDmg = b.sumDmg / b.n }
            end
        end
        buckets[sp] = ob
    end
    return { buckets = buckets }
end

-- bite marginal-conversion least squares (D-20): 5cp bite samples only.
-- x uses the two locked formulas: regular samples x = energyPool - 35, OOC
-- samples x = energyPool - 0 (the full pool converts). Single-pass
-- accumulation of n/sx/sy/sxx/sxy (all doubles, Lua 5.0), then
-- b = (n*sxy - sx*sy) / den with den = n*sxx - sx*sx, a = (sy - b*sx) / n.
-- Guards: n < 3 yields the mean only with a warning; a zero denominator
-- (all x equal) declares no slope. dmg/energyPool hygiene was already
-- enforced at parse time, so no re-checking here.
function computeBiteRegression(entries)
    local n = 0
    local sx = 0
    local sy = 0
    local sxx = 0
    local sxy = 0
    local sumDmg = 0
    local xMin = nil
    local xMax = nil
    local total = countList(entries)
    for i = 1, total do
        local e = entries[i]
        if e.spell == 'bite' and e.cp == 5 then
            local x = e.energyPool
            if not e.isOoc then
                x = e.energyPool - 35
            end
            n = n + 1
            sx = sx + x
            sy = sy + e.dmg
            sxx = sxx + x * x
            sxy = sxy + x * e.dmg
            sumDmg = sumDmg + e.dmg
            if xMin == nil or x < xMin then
                xMin = x
            end
            if xMax == nil or x > xMax then
                xMax = x
            end
        end
    end
    if n < 3 then
        if n == 0 then
            return { usable = false, reason = 'n<3', n = 0, avgDmg = nil }
        end
        return { usable = false, reason = 'n<3', n = n, avgDmg = sumDmg / n }
    end
    local den = n * sxx - sx * sx
    if den == 0 then
        return { usable = false, reason = 'zero denominator (all x equal)', n = n }
    end
    local b = (n * sxy - sx * sy) / den
    local a = (sy - b * sx) / n
    return { usable = true, n = n, a = a, b = b, xRange = { min = xMin, max = xMax } }
end

-- D-17 first layer: group entries by numeric batch key, iterate the batches
-- ascending via an explicit sort (no pairs ordering), and run the three
-- stat passes per batch. Returns an array of per-batch tables; the caller
-- re-runs the same passes over the whole list for the aggregate layer.
function buildPerBatchStats(entries)
    local byBatch = {}
    local total = countList(entries)
    for i = 1, total do
        local e = entries[i]
        local list = byBatch[e.batch]
        if list == nil then
            list = {}
            byBatch[e.batch] = list
        end
        table.insert(list, e)
    end
    local keys = {}
    for k, _ in pairs(byBatch) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return a < b
    end)
    local out = {}
    for i = 1, countList(keys) do
        local batchEntries = byBatch[keys[i]]
        table.insert(out, {
            batch = keys[i],
            n = countList(batchEntries),
            clawShred = buildClawShredBuckets(batchEntries),
            oocTiers = buildOocTiers(batchEntries),
            bite = computeBiteRegression(batchEntries),
        })
    end
    return out
end

-- output section (D-16/D-21/D-15): terminal report, decision lines, json
-- archive and the full self-test.

-- rendering helpers: nil averages render as '-', damage at two decimals,
-- efficiencies and slopes at four (RESEARCH 6 cross-version alignment)
local function fmtDmg(v)
    if v == nil then
        return '-'
    end
    return string.format('%.2f', v)
end

local function fmtEff(v)
    if v == nil then
        return '-'
    end
    return string.format('%.4f', v)
end

-- three families of ready-to-use catAtk tuning lines (D-21):
--   1. per bleedCount tier: which builder wins on avg dmg/e
--   2. per OOC tier (behind-position samples only): which skill wins on
--      single-cast average damage
--   3. bite marginal b vs the best builder efficiency anywhere in the
--      claw/shred tier tables (the source tier is named): decides whether
--      to discharge extra energy before biting
function decisionLines(stats)
    local lines = {}
    local cs = stats.clawShred
    local spells = { 'claw', 'shred' }
    local bestEff = nil
    local bestEffSource = nil
    for tier = 0, 3 do
        local head = 'Tier ' .. tostring(tier) .. ' (bleedCount ' .. tostring(tier) .. '): '
        local cn = cs.buckets.claw[tier].n
        local sn = cs.buckets.shred[tier].n
        if cn == 0 or sn == 0 then
            table.insert(lines, head .. 'no samples')
        elseif cs.buckets.shred[tier].avgEff > cs.buckets.claw[tier].avgEff then
            table.insert(lines, head .. 'SHRED is more efficient (' ..
                fmtEff(cs.buckets.shred[tier].avgEff) .. ' dmg/energy vs CLAW ' ..
                fmtEff(cs.buckets.claw[tier].avgEff) .. ') - use Shred')
        else
            table.insert(lines, head .. 'CLAW is more efficient (' ..
                fmtEff(cs.buckets.claw[tier].avgEff) .. ' dmg/energy vs SHRED ' ..
                fmtEff(cs.buckets.shred[tier].avgEff) .. ') - use Claw')
        end
        for si = 1, 2 do
            local sp = spells[si]
            local b = cs.buckets[sp][tier]
            if b.n > 0 and (bestEff == nil or b.avgEff > bestEff) then
                bestEff = b.avgEff
                bestEffSource = sp .. ' tier ' .. tostring(tier)
            end
        end
    end
    local oc = stats.oocTiers
    for tier = 0, 3 do
        local head = 'OOC tier ' .. tostring(tier) .. ' (behind): '
        local cn = oc.buckets.claw[tier].n
        local sn = oc.buckets.shred[tier].n
        if cn == 0 or sn == 0 then
            table.insert(lines, head .. 'no samples')
        elseif oc.buckets.shred[tier].avgDmg > oc.buckets.claw[tier].avgDmg then
            table.insert(lines, head .. 'use SHRED (single-cast avg ' ..
                fmtDmg(oc.buckets.shred[tier].avgDmg) .. ' vs CLAW ' ..
                fmtDmg(oc.buckets.claw[tier].avgDmg) .. ')')
        else
            table.insert(lines, head .. 'use CLAW (single-cast avg ' ..
                fmtDmg(oc.buckets.claw[tier].avgDmg) .. ' vs SHRED ' ..
                fmtDmg(oc.buckets.shred[tier].avgDmg) .. ')')
        end
    end
    local reg = stats.biteRegression
    if reg.usable then
        if reg.b < 0 then
            table.insert(lines, 'bite at 5cp: b=' .. fmtEff(reg.b) ..
                ' - no positive marginal bite damage - check sample mix')
        elseif bestEff == nil then
            table.insert(lines, 'bite at 5cp: b=' .. fmtEff(reg.b) ..
                ' - no builder samples to compare against')
        elseif reg.b > bestEff then
            table.insert(lines, 'bite at 5cp: b=' .. fmtEff(reg.b) ..
                ' vs best builder ' .. fmtEff(bestEff) .. ' dmg/energy (' .. bestEffSource ..
                '): b > builder - bite at 35 without discharge (prefer saving energy for bite conversion)')
        else
            table.insert(lines, 'bite at 5cp: b=' .. fmtEff(reg.b) ..
                ' vs best builder ' .. fmtEff(bestEff) .. ' dmg/energy (' .. bestEffSource ..
                '): b <= builder - discharge extra energy with the best builder before biting')
        end
    else
        local line = 'bite at 5cp: ' .. reg.reason .. ' (n=' .. tostring(reg.n)
        if reg.avgDmg ~= nil then
            line = line .. ', avg dmg ' .. fmtDmg(reg.avgDmg)
        end
        table.insert(lines, line .. ')')
    end
    return lines
end

-- one claw/shred tier table: header plus two rows per bleedCount tier
-- (claw, shred); columns n / avg dmg / avg dmg / e / single-cast avg, an
-- explicit 0..3 loop and a (low n) tag on thin tiers (0 < n < 10, D-18)
local function printClawShredTable(cs)
    io.write('  bleed  spell   n  avg dmg   avg dmg/e  single-cast avg\n')
    local spells = { 'claw', 'shred' }
    for tier = 0, 3 do
        for si = 1, 2 do
            local sp = spells[si]
            local b = cs.buckets[sp][tier]
            local tag = ''
            if b.n > 0 and b.n < 10 then
                tag = ' (low n)'
            end
            io.write(string.format('  %d     %-6s %3d  %8s  %10s  %8s%s\n',
                tier, sp, b.n, fmtDmg(b.avgDmg), fmtEff(b.avgEff), fmtDmg(b.avgRaw), tag))
        end
    end
end

-- OOC tier table (behind-position samples only, D-19): single-cast average
-- damage per tier
local function printOocTable(oc)
    io.write('  OOC (behind): bleed  spell   n  single-cast avg dmg\n')
    local spells = { 'claw', 'shred' }
    for tier = 0, 3 do
        for si = 1, 2 do
            local sp = spells[si]
            local b = oc.buckets[sp][tier]
            io.write(string.format('  %13d  %-6s %3d  %8s\n',
                tier, sp, b.n, fmtDmg(b.avgDmg)))
        end
    end
end

-- bite regression section (D-20): usable fits print n / a / b / x range
-- plus the two x formulas; guarded fits print the reason and skip the
-- slope output
local function printBiteLine(reg)
    if reg.usable then
        io.write('  bite regression (5cp): n=' .. tostring(reg.n) ..
            '  dmg = ' .. fmtDmg(reg.a) .. ' + ' .. fmtEff(reg.b) ..
            ' * x  x in [' .. fmtDmg(reg.xRange.min) .. ' .. ' ..
            fmtDmg(reg.xRange.max) .. ']\n')
        io.write('  model: x = energyPool - 35 (regular) or energyPool - 0 (OOC)\n')
    elseif reg.reason == 'n<3' then
        io.write('  bite regression (5cp): ' .. reg.reason .. ' (n=' .. tostring(reg.n) .. ')')
        if reg.avgDmg ~= nil then
            io.write('  avg dmg ' .. fmtDmg(reg.avgDmg))
        end
        io.write('\n')
    else
        io.write('  bite regression (5cp): ' .. reg.reason .. ' (n=' .. tostring(reg.n) .. ')\n')
    end
end

-- terminal report (D-16/D-17): one section per batch (claw/shred tier
-- table, OOC tier table, bite line), an aggregate section over the whole
-- sample, the decision lines and a tail with the drop counters. All loops
-- iterate bleedCount 0..3 and batches in ascending order explicitly.
function printReport(res)
    local sep = string.rep('=', 64)
    local batches = res.batches
    for bi = 1, countList(batches) do
        local b = batches[bi]
        io.write(sep .. '\n')
        io.write('batch ' .. tostring(b.batch) .. ' (' .. tostring(b.n) .. ' samples)\n')
        printClawShredTable(b.clawShred)
        printOocTable(b.oocTiers)
        printBiteLine(b.bite)
    end
    io.write(sep .. '\n')
    io.write('aggregate (all batches)\n')
    printClawShredTable(res.aggregate.clawShred)
    printOocTable(res.aggregate.oocTiers)
    printBiteLine(res.aggregate.biteRegression)
    io.write('decisions:\n')
    for i = 1, countList(res.decisions) do
        io.write('  ' .. res.decisions[i] .. '\n')
    end
    if res.dropped.badLines > 0 then
        io.write('warning: ' .. tostring(res.dropped.badLines) ..
            ' malformed [cpDamage] lines skipped\n')
    end
    if res.dropped.invalidFields > 0 then
        io.write('warning: ' .. tostring(res.dropped.invalidFields) ..
            ' entries dropped for invalid fields\n')
    end
    if res.truncated then
        io.write('warning: entry cap ' .. tostring(MAX_ENTRIES) ..
            ' reached, remaining lines ignored\n')
    end
end

-- json result archive (D-16): encodeValue builds the whole document from
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

-- full self-test battery (D-15 runtime carrier): one SV-form fixture built
-- entirely inside this script (no external file reads or writes, no
-- .planning/samples references), rounded through extract / getMessages /
-- parseEntries, plus direct unit tests on the decoder, the bucket math,
-- the regression constants and the decision lines. Any failure prints a
-- FAIL line and exits 1; a clean run prints the ALL PASSED banner and
-- exits 0. The fixture serializes double quotes through string.char(34)
-- so no bare quote byte can confuse the bracket gate's strip order.
function runSelftest()
    local passed = 0
    local function check(cond, label)
        if cond then
            passed = passed + 1
        else
            io.write('selftest: FAIL - ' .. label .. '\n')
            os.exit(1)
        end
    end
    local DQ = string.char(34)
    local function ntext(v)
        if v == math.floor(v) then
            return string.format('%.0f', v)
        end
        return tostring(v)
    end
    local function btext(v)
        if v then
            return 'true'
        end
        return 'false'
    end
    -- fixed 11-field JSON body in the U-03 emitter order
    -- (spell dmg crit e energyPool bleedCount isOoc isBehind cp t batch)
    local function body(spell, dmg, crit, e, pool, bleed, ooc, behind, cp, t, batch)
        return '{"spell":"' .. spell .. '","dmg":' .. ntext(dmg) ..
            ',"crit":' .. btext(crit) .. ',"e":' .. ntext(e) ..
            ',"energyPool":' .. ntext(pool) .. ',"bleedCount":' .. ntext(bleed) ..
            ',"isOoc":' .. btext(ooc) .. ',"isBehind":' .. btext(behind) ..
            ',"cp":' .. ntext(cp) .. ',"t":' .. ntext(t) ..
            ',"batch":' .. ntext(batch) .. '}'
    end
    -- one messages ring line the way the client writes it: [N] = "body"
    -- with the inner double quotes backslash-escaped
    local function line(n, raw)
        local escaped = string.gsub(raw, DQ, '\\' .. DQ)
        return '\t\t[' .. tostring(n) .. '] = ' .. DQ .. escaped .. DQ .. ',\n'
    end
    local fix = 'MACRO_TORCH_LOG = {\n' ..
        '\t["messages"] = {\n'
    fix = fix .. line(1, '[cpDamage] ' .. body('claw', 210, false, 45, 60, 0, false, true, 2, 100.1, 1000))
    fix = fix .. line(2, '[cpDamage] ' .. body('claw', 262, false, 45, 55, 1, false, true, 1, 103.4, 1000))
    fix = fix .. line(3, '[cpDamage] ' .. body('claw', 318, true, 45, 70, 2, false, true, 3, 106.7, 1000))
    fix = fix .. line(4, '[cpDamage] ' .. body('shred', 390, false, 60, 80, 1, false, true, 2, 110.0, 2000))
    fix = fix .. line(5, '[cpDamage] ' .. body('shred', 410, true, 60, 90, 3, false, true, 4, 112.5, 2000))
    fix = fix .. line(6, '[cpDamage] ' .. body('bite', 415, false, 35, 45, 1, false, true, 5, 115.0, 2000))
    fix = fix .. line(7, '[cpDamage] ' .. body('bite', 430, true, 35, 60, 2, false, true, 5, 118.2, 2000))
    fix = fix .. line(8, '[cpDamage] ' .. body('bite', 445, false, 35, 85, 1, true, true, 5, 121.0, 3000))
    fix = fix .. line(9, '[cpDamage] {"spell":"claw","dmg":210,')
    fix = fix .. line(10, '[cpBuild] Claw t=1.0 cp=2 e=55')
    fix = fix .. '\t},\n}\n'
    local EXPECT_LINE1 = '[cpDamage] {\\"spell\\":\\"claw\\",\\"dmg\\":210,\\"crit\\":false,\\"e\\":45,\\"energyPool\\":60,\\"bleedCount\\":0,\\"isOoc\\":false,\\"isBehind\\":true,\\"cp\\":2,\\"t\\":100.1,\\"batch\\":1000}'
    check(string.find(fix, EXPECT_LINE1, 1, true) ~= nil,
        'fixture line 1 carries the hand-written 11-field literal byte for byte')
    local block, extractErr = extractMacroTorchLog(fix)
    check(block ~= nil, 'fixture extraction succeeds (' .. tostring(extractErr) .. ')')
    local pack, packErr = getMessages(block)
    check(pack ~= nil and pack.ok, 'fixture sandbox run succeeds (' .. tostring(packErr) .. ')')
    check(pack ~= nil and pack.ok and countList(pack.messages) == 10,
        'fixture message count is 10')
    local pr = parseEntries(pack.messages)
    check(countList(pr.entries) == 8, 'fixture yields 8 valid entries')
    check(pr.badLines == 1, 'fixture yields exactly 1 bad line')
    check(pr.invalidFields == 0, 'fixture yields 0 invalid-field drops')
    check(pr.truncated == false, 'fixture does not truncate')
    local cs = buildClawShredBuckets(pr.entries)
    check(cs.buckets.claw[0].n == 1 and cs.buckets.claw[1].n == 1 and
        cs.buckets.claw[2].n == 1 and cs.buckets.claw[3].n == 0,
        'claw tier sample counts are 1/1/1/0')
    check(cs.buckets.shred[0].n == 0 and cs.buckets.shred[1].n == 1 and
        cs.buckets.shred[2].n == 0 and cs.buckets.shred[3].n == 1,
        'shred tier sample counts are 0/1/0/1')
    check(cs.aggregate.n == 5, 'claw/shred aggregate count is 5')
    check(math.abs(cs.buckets.claw[0].avgEff - 210 / 45) < 0.001,
        'claw tier 0 avgEff equals 210 / 45')
    check(math.abs(cs.buckets.claw[1].avgEff - 262 / 45) < 0.001,
        'claw tier 1 avgEff equals 262 / 45')
    check(math.abs(cs.buckets.claw[2].avgEff - 318 / 45) < 0.001,
        'claw tier 2 avgEff equals 318 / 45')
    check(math.abs(cs.buckets.shred[1].avgEff - 390 / 60) < 0.001,
        'shred tier 1 avgEff equals 390 / 60')
    check(math.abs(cs.buckets.shred[3].avgEff - 410 / 60) < 0.001,
        'shred tier 3 avgEff equals 410 / 60')
    check(cs.buckets.claw[0].avgDmg == 210 and cs.buckets.claw[0].avgRaw == 210,
        'claw tier 0 avgDmg and avgRaw are both 210')
    local oc = buildOocTiers(pr.entries)
    check(oc.buckets.claw[0].n == 0 and oc.buckets.shred[3].n == 0,
        'OOC tier table stays empty for non-OOC claw/shred samples')
    local fr = computeBiteRegression(pr.entries)
    check(fr.usable and fr.n == 3, 'fixture bite regression is usable with 3 pooled samples')
    local ctrl = {
        { spell = 'bite', dmg = 100, cp = 5, energyPool = 35, isOoc = false },
        { spell = 'bite', dmg = 120, cp = 5, energyPool = 45, isOoc = false },
        { spell = 'bite', dmg = 140, cp = 5, energyPool = 55, isOoc = false },
    }
    local rc = computeBiteRegression(ctrl)
    check(rc.usable and math.abs(rc.b - 2) < 0.001 and math.abs(rc.a - 100) < 0.001,
        'controlled regression fits b=2 and a=100')
    check(rc.xRange.min == 0 and rc.xRange.max == 20,
        'controlled regression x range is 0..20')
    local mObj = decodeJson('{"s":"a\\nb","n":12.5,"neg":-3,"t":true,"f":false,"z":null}')
    check(type(mObj) == 'table' and mObj['s'] == 'a' .. '\n' .. 'b',
        'decoder object and string escape round trip')
    check(mObj['n'] == 12.5 and mObj['neg'] == -3, 'decoder number forms')
    check(mObj['t'] == true and mObj['f'] == false, 'decoder boolean forms')
    check(mObj['z'] == nil, 'decoder null form yields a nil value')
    local mArr = decodeJson('[1,"two",false]')
    check(type(mArr) == 'table' and mArr[1] == 1 and mArr[2] == 'two' and mArr[3] == false,
        'decoder array form')
    local mSci = decodeJson('1.5e2')
    check(mSci == 150, 'decoder scientific number form')
    local mSlash = decodeJson('{"p":"a\\/b"}')
    check(mSlash['p'] == 'a/b', 'decoder forward slash escape')
    local mUni = decodeJson('{"u":"\\u0041"}')
    check(mUni['u'] == 'A', 'decoder unicode escape')
    local bad1, badErr1 = decodeJson('{"a":')
    check(bad1 == nil and badErr1 ~= nil, 'malformed JSON returns nil plus an error')
    local bad2, badErr2 = decodeJson('nope')
    check(bad2 == nil and badErr2 ~= nil, 'non-JSON token returns nil plus an error')
    local statsRef = {
        clawShred = cs,
        oocTiers = oc,
        biteRegression = fr,
    }
    local decs = decisionLines(statsRef)
    check(countList(decs) > 0, 'decision lines are generated')
    check(string.sub(decs[1], 1, 6) == 'Tier 0', 'first decision line opens with the tier 0 bucket')
    io.write('selftest: ALL ' .. tostring(passed) .. ' PASSED\n')
    os.exit(0)
end

-- usage text with the three subcommand forms
function printUsage()
    io.write('usage: lua tools/cpdamage.lua <path/to/SuperMacro.lua>\n')
    io.write('usage: lua tools/cpdamage.lua <path/to/SuperMacro.lua> ' ..
        FLAG_JSON_OUT .. ' <file>\n')
    io.write('usage: lua tools/cpdamage.lua ' .. FLAG_SELFTEST .. '\n')
end

-- CLI entry: parse the arguments, then either run the self-test battery or
-- the full read -> extract -> sandbox -> decode -> stats -> report chain
-- with the optional json archive. The first non-flag argument is the
-- SavedVariables path; the json-out target and the selftest mode ride the
-- flag constants. The self-test path touches no external files.
function main(args)
    if not args or not args[1] then
        printUsage()
        os.exit(1)
    end
    local selftestMode = false
    local jsonOutPath = nil
    local svPath = nil
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
    local parsed = parseEntries(pack.messages)
    local statsRef = {
        clawShred = buildClawShredBuckets(parsed.entries),
        oocTiers = buildOocTiers(parsed.entries),
        biteRegression = computeBiteRegression(parsed.entries),
    }
    local res = {
        generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        source = svPath,
        batches = buildPerBatchStats(parsed.entries),
        aggregate = {
            clawShred = statsRef.clawShred,
            oocTiers = statsRef.oocTiers,
            biteRegression = statsRef.biteRegression,
        },
        decisions = decisionLines(statsRef),
        dropped = { badLines = parsed.badLines, invalidFields = parsed.invalidFields },
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
