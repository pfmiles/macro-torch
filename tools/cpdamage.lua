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

-- usage text with the three subcommand forms
function printUsage()
    io.write('usage: lua tools/cpdamage.lua <path/to/SuperMacro.lua>\n')
    io.write('usage: lua tools/cpdamage.lua <path/to/SuperMacro.lua> ' ..
        FLAG_JSON_OUT .. ' <file>\n')
    io.write('usage: lua tools/cpdamage.lua ' .. FLAG_SELFTEST .. '\n')
end

-- CLI entry (Task 1 scope): parse the arguments, then read -> extract ->
-- sandbox -> messages. The first non-flag argument is the SavedVariables
-- path; the json-out target and the selftest mode ride the flag constants.
-- Task 4 replaces the selftest placeholder with the full battery and wires
-- the parse/statistics/report chain behind this point.
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
        io.write('full selftest lands in Task 4\n')
        os.exit(0)
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
    io.write('macrotorch log: ' .. tostring(countList(pack.messages)) .. ' messages loaded\n')
    os.exit(0)
end

main(arg)