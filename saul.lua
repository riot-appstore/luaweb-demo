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


local saul = {"__index"=find_device, "types"=code2devtype2}

function saul.find_type(t)
    error("Not implemented")
end

setmetatable(saul, saul)

static const luaL_Reg funcs[] = {
  {"find_type", find_type},
  {"types", all_types},
  {"__index", _index},
}
