-- Coroutine based IO

local p = require"piping"
local IOHandler = p.IOHandler
local IOSink = p.IOSink

local colors = require"ansicolors"

local cc = coroutine.create

local function xload(f, chunkname, mode, env)
    -- Stupid version of load to work around the fact that we cannot yield from
    -- inside the load() call (cannot yield across C-api calls)
    local lines = {}
    while true do
        local l = f()
        if #l == 0 or l == "\n" then
            break
        end
        table.insert(lines, l)
    end

    lines = table.concat(lines)

    return load(lines)
end

local function _rep(env)
    -- READ-EVAL-PRINT step
    IOHandler:write(colors("%{bright blue}L> %{reset}"))
    local ln = IOHandler:read()

    if not ln then
        IOHandler:write("Exit interpreter\n")
        return ""
    elseif ln == "\n" then
        IOHandler:write(nil)
    end
    -- Try to see if we have an expression
    local maybe_code, compile_err = load("return "..ln, "=(load)", 't', env)
    -- Try to see if we have a single-line statement
    if not maybe_code then
        maybe_code, compile_err = load(ln, "=(load)", 't', env)
    end
    -- Try a multiline statement
    if not maybe_code then
        local first_time = true
        local function get_multiline()
            local l
            if first_time then
                first_time = false
                l = ln
            else
                IOHandler:write(colors("%{bright blue}L.. %{reset}"));
                l = IOHandler:read()
            end
            --[[
            if #l ~= 0 then
                l = l.."\n"
            end
            -]]
            return l
        end

        maybe_code, compile_err = xload(get_multiline, "=(load)", 't', env)
    end

    if not maybe_code then
        IOHandler:write(colors("%{bright red}Compile error:%{reset}"))
        IOHandler:write(compile_err)
        IOHandler:write("\n")
    else
        --debug.setupvalue(maybe_code)
        local success, msg_or_ret = pcall(maybe_code)
        if not success then
            IOHandler:write(colors("%{red}Runtime error:%{reset} ") .. msg_or_ret .. "\n")
        elseif msg_or_ret ~= nil then
            IOHandler:write(tostring(msg_or_ret) .. "\n")
        end
    end
end

local function term_print(...)
    for i, v in ipairs(table.pack(...)) do
        IOHandler:write(tostring(v))
    end
    IOHandler:write("\n")
end

local function _repl(env)
    -- REP-Loop
    if env == nil then
        --env = _G
        env = {print=term_print}
        setmetatable(env, {__index = _G})
    end

    while true do
        _rep(env)
    end
end

local function line_buffer()
    -- make a line buffer with newline conversion
    local linebuf = {}
    while true do
        local char_in = IOHandler:read()
        table.insert(linebuf, char_in == '\r' and "\n" or char_in)
        if char_in == '\r' then
            IOHandler:write(table.concat(linebuf))
            linebuf = {}
        end
    end
end

local lf_wrapper = p.make_mapper(function (d) return string.gsub(d, "\n", "\r\n") end)

local terminal = {}

function terminal.setup()
    local js = require "js"

    local document = js.global.document
    local term_el = document:getElementById("terminal")
    local term = js.new(js.global.Terminal)

    term:open(term_el)

    local sink = IOSink:new(function(d) term:write(d) end)
    local process = sink << cc(lf_wrapper) << cc(_repl) << cc(line_buffer)

    term:on("data", function (this, d)
            -- hacky hack to have echo, must be fixed more elegantly
            term:write(d == '\r' and "\r\n" or d)
            process:pump(d)
        end)

    process:enter()

    -- I hate to have to call :enter each time
    terminal._sink = sink << cc(lf_wrapper)
    terminal._sink:enter()
end

function terminal.print(...)
    s = terminal._sink
    for i, v in ipairs(table.pack(...)) do
        s:pump(tostring(v))
    end
     s:pump("\n")
end

--[[
sink = IOSink:new(function(d) io.write(d); io.flush() end)
process = sink << cc(lf_wrapper) << cc(_repl) << cc(line_buffer)

process:pump(nil)

while true do
    b = io.read().."\r"
    for c in b:gmatch"." do
        process:pump(c)
    end

end
]]

terminal.setup()

package.preload.terminal = function() return terminal end

