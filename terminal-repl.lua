-- Coroutine based IO

local function repeatf(f)
    return function(...) while true do f(...) end end
end

local IOHandler = {}
IOHandler.__index = IOHandler
setmetatable(IOHandler, IOHandler)

function IOHandler:new(process, output_func)
    return setmetatable({process=process, output_func=output_func}, IOHandler)
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
    while true do
        local exit_st, outdata = coroutine.resume(self.process, inputdata)
        inputdata = nil
        if not exit_st then
            return
        elseif outdata == true then
            break
        elseif outdata then
            self.output_func(outdata)
        end
    end
end

function IOHandler:__shr(process, other)
    -- Compose this handler with another one
    IOHandler:new(self.process,
        function ()
            local in1 = self.pump(other)
        end
    ))


    pump(process, IOHandler:read(), function(d) )
end

local function xload(f)
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

local function _rep()
    IOHandler:write("L> ")
    local ln = IOHandler:read()

    if not ln then
        IOHandler:write("Exit interpreter\n")
        return ""
    elseif ln == "\n" then
        IOHandler:write(nil)
    end
    -- Try to see if we have an expression
    local maybe_code, compile_err = load("return "..ln)
    -- Try to see if we have a single-line statement
    if not maybe_code then
        maybe_code, compile_err = load(ln)
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

        maybe_code, compile_err = xload(get_multiline)
    end

    if not maybe_code then
        IOHandler:write("Compile error:")
        IOHandler:write(compile_err)
        IOHandler:write("\n")
    else
        local success, msg_or_ret = pcall(maybe_code)
        if not success then
            IOHandler:write("Runtime error: " .. msg_or_ret .. "\n")
        elseif msg_or_ret ~= nil then
            IOHandler:write(tostring(msg_or_ret) .. "\n")
        end
    end
end

local function _repl()
    while true do
        _rep()
    end
end

-- make a line buffer with newline conversion
local function line_buffer(io_task)
    local input_bufferer = coroutine.create(
        function ()
            local linebuf = {}
            while true do
                local char_in = IOHandler:read()
                table:insert(linebuf, char_in == '\r' and "\n" or char_in)
                if char_in == '\r' then
                    IOHandler:write(table.concat(linebuf))
                    linebuf = {}
                end
            end
        end)

   return IOHandler:new(input_bufferer)
end

local lf_wrapper(f)
    return function (d) f(string.gsub(d, "\n", "\r\n")) end
end

local function setup_terminal()
    local js = require "js"

    local document = js.global.document
    local term_el = document:getElementById("terminal")
    local term = js.new(js.global.Terminal)

    term:open(term_el)

    local repl_task = IOHandler:new(coroutine.create(_repl))
    local line_buffer_task = line_buffer(repl_task)
    local outf = lf_wrapper(function(d) term:write(d) end)

    term:on("data", function (this, d)
            line_buffer_task:pump(d, outf)
        end)

    line_buffer_task:pump(nil, outf)
end

setup_terminal()
