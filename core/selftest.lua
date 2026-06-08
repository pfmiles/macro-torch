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

-- ============================================================
-- Module 1: SelfTest table initialization
-- ============================================================
-- [CITED: CONTEXT.md D-01, D-03, D-05]
-- _selfTestRan is a session flag: set on first run, cleared on reload UI
-- SelfTest.tests holds all registered test items as {name, fn, isOptional}
macroTorch.SelfTest = {
    tests = {}
}
macroTorch._selfTestRan = nil

-- ============================================================
-- Module 2: SelfTest:register(name, fn, isOptional)
-- ============================================================
-- [CITED: CONTEXT.md D-03, D-05]
-- Registers a self-test item. isOptional defaults to false.
-- Optional test failures produce warnings (yellow), core test failures produce errors (red).
function macroTorch.SelfTest:register(name, fn, isOptional)
    table.insert(self.tests, {
        name = name,
        fn = fn,
        isOptional = isOptional or false
    })
end

-- ============================================================
-- Module 3: SelfTest:run()
-- ============================================================
-- [CITED: CONTEXT.md D-01, D-05; RESEARCH Pitfall 5]
-- Runs all registered tests with pcall isolation. Each test failure is captured
-- and reported. Successful tests produce no output. Failed core tests are reported
-- in red, optional test failures in yellow. A summary line is always output.
function macroTorch.SelfTest:run()
    -- D-01: session flag prevents repeated output on zone transitions
    if macroTorch._selfTestRan then
        return
    end
    macroTorch._selfTestRan = true

    local passed, failed, warnings = 0, 0, 0
    local failedNames = {}
    local warningNames = {}

    for _, test in ipairs(self.tests) do
        local success, err = pcall(test.fn)
        if success then
            passed = passed + 1
            -- D-05: success items are silent -- no log output
        else
            if test.isOptional then
                warnings = warnings + 1
                table.insert(warningNames, test.name)
            else
                failed = failed + 1
                table.insert(failedNames, test.name)
            end
            -- RESEARCH Pitfall 5: capture detailed error with tostring(err)
            local category = test.isOptional and "WARN" or "FAIL"
            macroTorch.show("[macro-torch] " .. category .. ": " .. test.name .. " - " .. tostring(err),
                test.isOptional and 'yellow' or 'red')
        end
    end

    -- D-05: summary line in white
    macroTorch.show(string.format("[macro-torch] Self-test: %d passed, %d failed, %d warnings",
        passed, failed, warnings), 'white')

    -- D-05: list failed core items in red
    for _, name in ipairs(failedNames) do
        macroTorch.show("[macro-torch] FAIL: " .. name, 'red')
    end

    -- D-05: list warning (optional) items in yellow
    for _, name in ipairs(warningNames) do
        macroTorch.show("[macro-torch] WARN: " .. name, 'yellow')
    end
end

-- ============================================================
-- Module 4: /mt SLASH command
-- ============================================================
-- [CITED: CONTEXT.md D-02, D-10]
-- /mt is the unified entry point for the future mt-script DSL.
-- Phase 3: no arguments runs self-test; with arguments shows reserved notice.
SLASH_MT1 = "/mt"
SlashCmdList["MT"] = function(msg)
    local trimmed = msg and string.gsub(msg, "^%s*(.-)%s*$", "%1") or ""
    if trimmed == "" then
        macroTorch.SelfTest:run()
    else
        macroTorch.show("[macro-torch] /mt: mt-script DSL is reserved for a future phase. Use /mt without arguments to run self-test.", 'yellow')
    end
end