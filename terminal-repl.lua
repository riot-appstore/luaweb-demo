-- Coroutine based IO
local IOHandler = {}
IOHandler.__index = IOHandler
setmetatable(IOHandler, IOHandler)

function IOHandler:new(process, outputfunc)
    return setmetatable({process=process, outfunc=outputfunc}, IOHandler)
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
    -- for readinf (i.e. that it is blocked on IOHandler:read. The only
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
            self.outfunc(outdata)
        end
    end
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
            if #l ~= 0 then
                l = l.."\n"
            end
            return l
        end

        maybe_code, compile_err = load(get_multiline)
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

local function main()
    local re = coroutine.create(_repl)
    io_h = IOHandler:new(re, io.write)

    --r = nil
    io_h:pump(nil)
    while 1 do
        local r = io.read()
        io_h:pump(r)
    end
end
--term:on('data', handledata)

local function setup_terminal()
    local js = require "js"


    local buf = {}

    local document = js.global.document
    local term_el = document:getElementById("terminal")
    local term = js.new(js.global.Terminal)

    term:open(term_el)

    local re = coroutine.create(_repl)
    io_h = IOHandler:new(re, function(d) term:write(d) end)

    term:on("data", function (this, d)
            table.insert(buf, d)
            term:write(d)
            if d == "\r" then
                term:write("\n")
                line = table.concat(buf)
                buf = {}
                io_h:pump(line)
            end
        end)

    io_h:pump(nil)
end

setup_terminal()
