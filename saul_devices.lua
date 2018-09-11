
local s = require"saul"
local js = require "js"

s.add_device{
	name="Servomotor",
	type="ACT_SERVO",
	read = function (self)
			return 0
		  end,
	write = function (self, v)
			js.global.system.state.setpoint = v
		  end
	}

s.add_device{
	name="TSL4531",
	type="SENSE_LIGHT",
	read = function (self)
			return js.global.system.state.sensor_value
		  end,
	write = function (self, v)
			return
		  end
	}


s.add_device{
	name="lsource",
	type="CLASS_UNDEF",
	read = function (self)
			return 0
		  end,
	write = function (self, v)
			js.global.system.settings.light.direction = v
		  end
	}



