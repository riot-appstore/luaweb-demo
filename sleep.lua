-- Emulate a sleep function.
-- Instead of sleeping, this makes the current thread yield
-- Super hacky, but should get us going fast. Ideally this should use "piping"

js = require"js"

local sleep = {}

function sleep.sleep(s)
    -- Call this from within a thread to send it to sleep.
    coroutine.yield(s)
end


local sleeper = {}
sleeper.__index = sleeper

function sleeper:_launch()
    local exit_st, delay_or_err = coroutine.resume(self.coro)
    if not self.cancel_request and exit_st and delay_or_err then
        self.timer_id = js.global.window:setTimeout(function () sleeper._launch(self) end, delay_or_err*1000)
    else
        self.timer_id = nil
        if not exit_st and self.onerror then
            self:onerror(delay_or_err)
        end
    end
end

function sleeper:launch()
    self.cancel_request = nil
    self:_launch()
end

function sleeper:new(f, error_cb)
    -- Create a thread from a function f that can call sleep.sleep(s)
    return setmetatable({coro=coroutine.create(f), onerror=error_cb}, sleeper)
end

function sleeper:cancel()
    -- cancel a task
    self.cancel_request = true
    tid = self.timer_id
    if tid then
        js.global.window:clearTimeout(tid)
    end
end


sleep.sleeper = sleeper

local riot = {sleep=sleep.sleep}

-- return sleep
package.preload.sleep = function() return sleep end
package.preload.riot = function() return riot end

