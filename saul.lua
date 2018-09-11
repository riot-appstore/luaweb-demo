-- Emulate SAUL devices.
-- This tries to expose the same api as the "saul" lua module in RIOT.

local code2devtype = {
    "ACT_ANY",
    "ACT_DIMMER",
    "ACT_LED_RGB",
    "ACT_MOTOR",
    "ACT_SERVO",
    "ACT_SWITCH",
    "CLASS_ANY",
    "CLASS_UNDEF",
    "SENSE_ACCEL",
    "SENSE_ANALOG",
    "SENSE_ANY",
    "SENSE_BTN",
    "SENSE_CO2",
    "SENSE_COLOR",
    "SENSE_COUNT",
    "SENSE_DISTANCE",
    "SENSE_GYRO",
    "SENSE_HUM",
    "SENSE_LIGHT",
    "SENSE_MAG",
    "SENSE_OBJTEMP",
    "SENSE_OCCUP",
    "SENSE_PRESS",
    "SENSE_TEMP",
    "SENSE_TVOC",
    "SENSE_UV",
}

local devtype2code = {}

for k, v in ipairs(code2devtype) do
    devtype2code[v] = k
end


-- The C module in RIOT has a cache to keep the devices while the user
-- code holds a reference. Here we just keep all devices alive all the time.

local Device = {}

function Device:get_name()
    return self.name;
end

function Device:get_type()
    return self.type;
end

Device.__index = Device

local devices = {}

local saul = {__index=devices, types=code2devtype, _devices = devices}

function saul.find_type(t)
    error("Not implemented")
end

-- Add a device with fields {name, type, read_fn, write_fn}
function saul.add_device(dev)
    saul._devices[dev.name] = setmetatable(dev, Device)
end

setmetatable(saul, saul)

package.preload.saul = function() return saul end
