local js = require"js"
local sleep = require"sleep"
local terminal = require"terminal"
local colors = require"ansicolors"

local user_task = nil
local editor = nil

local _print = terminal.print

local function _report_err(...)
    _print(colors("%{bright red}Script error:%{reset} "), ...)
end

local function run_code()
    local src = editor:getValue()

    local env = {print=_print}
    setmetatable(env, {__index = _G})

    local maybe_code, compile_err = load(src, "=(user)", 't', env)

    if not maybe_code then
        _print(colors("%{bright red}Compile error:%{reset}"), compile_err)
    else
        if user_task then
            user_task:cancel()
            user_task = nil
        end
        user_task = sleep.sleeper:new(maybe_code, _report_err)
        user_task:launch()
    end
end

local function setup_editor()
    editor = js.global.ace:edit("editor")

    editor:setTheme("ace/theme/monokai")
    editor.session:setMode("ace/mode/lua")

    js.global.editor = editor

    local document = js.global.document
    local run_btn = document:getElementById("run-btn")

    run_btn.onclick = function () run_code() end
end

setup_editor()
