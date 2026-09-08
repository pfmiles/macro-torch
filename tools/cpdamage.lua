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

-- offline analyzer for macroTorch [cpDamage] entries (phase 28, skeleton).
-- Reads a SuperMacro.lua SavedVariables file given on the command line,
-- extracts the MACRO_TORCH_LOG block with string/comment aware bracket
-- matching, executes the block in an empty sandbox, filters the [cpDamage]
-- prefixed messages, decodes the JSON bodies and prints one entry line per
-- sample plus entry and bad-line counts. The statistics, curve fitting and
-- report layers land in 28-03 on top of this skeleton.
-- Lua 5.0 dialect (D-15): no length operator, no table-form string.gsub
-- replacement, no %q JSON output, math mod via the % operator, args read
-- straight off the arg table. Self-contained, no external dependencies.

local MAX_FILE_BYTES = 32 * 1024 * 1024
local MAX_ENTRIES = 50000
local PREFIX = '[cpDamage] '

-- read a whole file as one string; refuse files over 32MB (DoS ceiling).
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

-- count the line number of a byte offset; used for error reporting only.
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
-- return the full 'MACRO_TORCH_LOG = { ... }' segment text. The brace
-- matching skips string literals (with backslash, quote and \ddd escapes),
-- line comments and block comments, because the JSON bodies stored inside
-- the strings are full of braces and quotes - a bare brace count would
-- necessarily mismatch. Returns nil plus an error message (with line number
-- inside) when the block is absent or unbalanced.
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
        elseif byte == 34 or byte == 39 then
            -- string literal with escape awareness: a backslash skips the
            -- next byte so \" and \ddd forms can never fake a closing quote
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
-- env argument. Both paths return a function that runs the block with an
-- empty environment table (no io/os/dofile or any other global), so the
-- extracted SavedVariables segment can never execute host code.
local load_chunk = loadstring or load

function loadBlockSandboxed(block)
    if not load_chunk then
        return nil, 'no chunk loader in this interpreter'
    end
    local env = {}
    if loadstring and setfenv then
        local fn, loadErr = loadstring(block)
        if not fn then
            return nil, loadErr
        end
        setfenv(fn, env)
        local ran, runErr = pcall(fn)
        if not ran then
            return nil, runErr
        end
        return env
    end
    local fn, loadErr = load(block, '@sv_block', 't', env)
    if not fn then
        return nil, loadErr
    end
    local ran, runErr = pcall(fn)
    if not ran then
        return nil, runErr
    end
    return env
end

-- run the extracted block in the sandbox and read the messages list off the
-- two key forms the client serializer may produce (MACRO_TORCH_LOG and
-- MACRO_TORCH_LOG["messages"]). A nil or empty MACRO_TORCH_LOG yields an
-- empty list with a friendly note instead of a crash.
function getMessages(block)
    local env, envErr = loadBlockSandboxed(block)
    if not env then
        return nil, 'sandbox run failed: ' .. tostring(envErr)
    end
    local root = env.MACRO_TORCH_LOG
    if root == nil then
        return {}, 'MACRO_TORCH_LOG is nil in this file (cleared before the last save)'
    end
    if type(root) ~= 'table' then
        return {}, 'MACRO_TORCH_LOG is not a table in this file'
    end
    if next(root) == nil then
        return {}, 'MACRO_TORCH_LOG is an empty table in this file'
    end
    local messages = root['messages']
    if messages == nil then
        messages = root.messages
    end
    if type(messages) ~= 'table' then
        return {}, 'MACRO_TORCH_LOG has no messages list'
    end
    return messages
end

-- minimal recursive-descent JSON decoder (phase 28 skeleton): exactly six
-- forms (object, array, string, number, true, false, null), a nesting depth
-- cap against hostile input, and nil plus an error message on any malformed
-- body. Only ever fed by the in-game encoder, so the fixed field set and the
-- \u00XX escape form are the interop contract.
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
                    table.insert(out, '"')
                    pos = pos + 2
                elseif esc == 92 then
                    table.insert(out, '\\')
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
        return tonumber(string.sub(str, from, pos - 1))
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

-- numbers print as plain integers when integral, else at two decimals, so
-- the report alignment stays identical across Lua versions (tostring of
-- floats differs between versions; RESEARCH 6 cross-version alignment).
local function formatNum(v)
    if v == math.floor(v) then
        return string.format('%.0f', v)
    end
    return string.format('%.2f', v)
end

local function valStr(v)
    if v == nil then
        return 'null'
    end
    if type(v) == 'number' then
        return formatNum(v)
    end
    return tostring(v)
end

-- one [cpDamage] entry in the fixed 11-field order (D-07); the order is part
-- of the encode/decode interop contract.
local function printEntry(entry)
    io.write('spell: ' .. valStr(entry['spell']) ..
        ' | dmg: ' .. valStr(entry['dmg']) ..
        ' | crit: ' .. valStr(entry['crit']) ..
        ' | e: ' .. valStr(entry['e']) ..
        ' | energyPool: ' .. valStr(entry['energyPool']) ..
        ' | bleedCount: ' .. valStr(entry['bleedCount']) ..
        ' | isOoc: ' .. valStr(entry['isOoc']) ..
        ' | isBehind: ' .. valStr(entry['isBehind']) ..
        ' | cp: ' .. valStr(entry['cp']) ..
        ' | t: ' .. valStr(entry['t']) ..
        ' | batch: ' .. valStr(entry['batch']) .. '\n')
end

-- iterate the messages list: exact [cpDamage] prefix filter, strip, decode
-- each JSON body under pcall and print. Malformed lines are counted and
-- skipped, never abort the batch (T-28-03); a 50k entry cap truncates
-- hostile logs with a warning (T-28-02). Returns entry and bad counts.
local function printDamageEntries(messages)
    local prefixLen = string.len(PREFIX)
    local index = 1
    local entryCount = 0
    local badCount = 0
    local truncWarned = false
    while messages[index] ~= nil do
        local line = messages[index]
        index = index + 1
        if type(line) == 'string' and string.sub(line, 1, prefixLen) == PREFIX then
            if entryCount >= MAX_ENTRIES then
                truncWarned = true
                break
            end
            local body = string.sub(line, prefixLen + 1)
            local ok, decoded, decErr = pcall(decodeJson, body)
            if ok and decErr == nil and type(decoded) == 'table' then
                printEntry(decoded)
                entryCount = entryCount + 1
            else
                badCount = badCount + 1
            end
        end
    end
    if truncWarned then
        io.write('warning: entry cap ' .. tostring(MAX_ENTRIES) ..
            ' reached, remaining lines ignored\n')
    end
    return entryCount, badCount
end

-- CLI entry: read -> extract -> sandbox -> filter -> decode -> print.
-- The selftest and json-out branches are placeholders kept for 28-03,
-- where the statistics/report layers and the full self-test land. The flag
-- literals are spelled via concatenation so no string in this file contains
-- an adjacent hyphen pair (the parenthesis gate strips line comments before
-- strings, so an in-string double hyphen would eat the rest of the line).
local FLAG_SELFTEST = '-' .. '-selftest'
local FLAG_JSON_OUT = '-' .. '-json-out'

function main(arg)
    if not arg or not arg[1] then
        io.write('usage: lua tools/cpdamage.lua <path/to/WTF/Account/<acc>/SavedVariables/SuperMacro.lua>\n')
        io.write('  ' .. FLAG_SELFTEST .. '  placeholder (lands in the full analyzer build, 28-03)\n')
        io.write('  ' .. FLAG_JSON_OUT .. '  placeholder (lands in the full analyzer build, 28-03)\n')
        os.exit(1)
    end
    if arg[1] == FLAG_SELFTEST then
        io.write('selftest runs in the full analyzer build\n')
        return
    end
    if arg[1] == FLAG_JSON_OUT then
        io.write(FLAG_JSON_OUT .. ' output lands in the full analyzer build\n')
        return
    end
    local text = readAll(arg[1])
    if not text then
        io.write('cannot read file (missing or over 32MB): ' .. tostring(arg[1]) .. '\n')
        return
    end
    local block, extractErr = extractMacroTorchLog(text)
    if not block then
        io.write('extract failed: ' .. tostring(extractErr) .. '\n')
        return
    end
    local messages, note = getMessages(block)
    if not messages then
        io.write(note .. '\n')
        return
    end
    if note then
        io.write('note: ' .. note .. '\n')
    end
    local entryCount, badCount = printDamageEntries(messages)
    io.write('entries: ' .. tostring(entryCount) .. '\n')
    if badCount > 0 then
        io.write('warning: ' .. tostring(badCount) ..
            ' malformed [cpDamage] lines skipped\n')
    end
end

main(arg)