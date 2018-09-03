--[[
Build pipelines for stream data processing.
]]

local p = {}

function p.forever(f)
    -- Make a function that executes f() in an endless loop.
    return function(...) while true do f(...) end end
end

IOHandler = {}
IOHandler.__index = IOHandler
setmetatable(IOHandler, IOHandler)

function IOHandler:new(process, sink)
    return setmetatable({process=process, sink=sink}, IOHandler)
end

function p.make_mapper(f)
    -- create a memoryless transformation
    return p.forever(function() IOHandler:write(f(IOHandler:read())) end)
end

function IOHandler:write(s)
    -- Send data "s" to the next pipeline element.
    coroutine.yield(s)
end

function IOHandler:read()
    -- "blocks" until there is data available for reading. In reality it does
    -- not block, but rather yields the current coroutine.
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

p.IOHandler = IOHandler

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

p.IOSink = IOSink

-- return p
package.preload.piping = function() return p end
