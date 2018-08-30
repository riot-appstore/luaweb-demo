-- Coroutine based IO

local function forever(f)
    return function(...) while true do f(...) end end
end

local cc = coroutine.create

local IOHandler = {}
IOHandler.__index = IOHandler
setmetatable(IOHandler, IOHandler)

function IOHandler:new(process, sink)
    return setmetatable({process=process, sink=sink}, IOHandler)
end

function make_mapper(f)
    -- create a memoryless transformation
    return forever(function() IOHandler:write(f(IOHandler:read())) end)
end

function IOHandler:write(s)
    coroutine.yield(s)
end

function IOHandler:read()
    while true do
        local indata = coroutine.yield(true)
        if indata then
            return indata
        end
    end
end

function IOHandler:pump(inputdata)
    -- Push data to the coroutine and resume it until it asks for more data.
    -- Each time we enter this function we can assume that the thread is ready
    -- for reading (i.e. that it is blocked on IOHandler:read. The only
    -- exception is at startup. For this reason pump() must be called with
    -- a nil argument at startup.
    if inputdata == nil then
        self.sink:pump(nil) -- force the next process to advance
    end
    while true do
        local exit_st, outdata = coroutine.resume(self.process, inputdata)
        inputdata = nil
        if not exit_st then
            return
        elseif outdata == true then
            break
        elseif outdata then
            self.sink:pump(outdata)
        end
    end
end

function IOHandler:__shl(process)
    -- Compose this handler with another one
    return IOHandler:new(process, self)
end

local IOSink = {}
IOSink.__index = IOSink
IOSink.__shl = IOHandler.__shl
setmetatable(IOSink, IOSink)

function IOSink:new(output_func)
    return setmetatable({output_func=output_func}, IOSink)
end

function IOSink:pump(inputdata)
    if inputdata then
        self.output_func(inputdata)
    end
end

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
    IOHandler:write("L> ")
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
                IOHandler:write("L.. ");
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
        IOHandler:write("Compile error:")
        IOHandler:write(compile_err)
        IOHandler:write("\n")
    else
        --debug.setupvalue(maybe_code)
        local success, msg_or_ret = pcall(maybe_code)
        if not success then
            IOHandler:write("Runtime error: " .. msg_or_ret .. "\n")
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

local lf_wrapper = make_mapper(function (d) return string.gsub(d, "\n", "\r\n") end)

local function setup_terminal()
    local js = require "js"

    local document = js.global.document
    local term_el = document:getElementById("terminal")
    local term = js.new(js.global.Terminal)

    term:open(term_el)

    local sink = IOSink:new(function(d) term:write(d) end)
    local process = sink << cc(lf_wrapper) << cc(_repl) << cc(line_buffer)

    term:on("data", function (this, d)
            term:write(d == '\r' and "\r\n" or d)
            process:pump(d)
        end)

    process:pump(nil)
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
setup_terminal()
