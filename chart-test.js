
var system = {
    settings: {
	light: {direction: 1.0,
		width: 0.3,
		distance: 1,
		intensity: 1.0,
		bg_intensity: 0.2,
		bg_noise: 0.05,
		fg_noise: 0.05
	    },
	sensor_noise: 0.05,
	servo_speed: 1,
	sample_rate: 100,
	plot_divisor: 20
    },
    state: {
	orientation: 0.0,
	setpoint: 0.0,
	sensor_value: 0.0,
	_light_noise: 0.0
    }
};

var charts = {}

/* Wrap a value in radians so that it lies within [-PI,PI] */
function angle_wrap(a)
{
    if (Math.abs(a) > Math.PI) {
	a = a - 2*Math.sign(a)*Math.PI;
    }

    return a;
}

function urand(a)
{
    return a * (Math.random() - 0.5);
}

/* simple mid-point numerical integration */
function integrate(f, start, end, steps)
{
    var d = end-start;
    var k = d/steps

    return Array.from(Array(steps).keys(),
	    (i) => f((i+0.5)*k + start)
	    ).reduce((acc, v) => acc+v)/steps;
}

function sensitivity(system, angle)
{
    var rel_angle = angle_wrap(angle-system.state.orientation);

    if (Math.abs(rel_angle) > Math.PI/2) {
	return 0;
    } else {
	var s = Math.cos(rel_angle);
	return s*s;
    }
}

function incident_light(system, angle)
{
    var max_angle = Math.atan(system.settings.light.width / system.settings.light.distance / 2);

    var ambient = urand(system.settings.light.bg_noise) + system.settings.light.bg_intensity;

    var relative_angle = angle_wrap(angle - system.settings.light.direction);
    var source = 0;

    if (Math.abs(relative_angle) <= max_angle) {
	source = Math.cos(relative_angle) * (system.state._light_noise + system.settings.light.intensity);
    }

    return ambient + source;
}

function update_sim(sys)
{
    var error = angle_wrap(sys.state.orientation - sys.state.setpoint);

    sys.state.orientation = angle_wrap(sys.state.orientation
		+ Math.sign(error) * sys.settings.servo_speed * sys.settings.sample_rate);

    sys.state._light_noise = urand(sys.settings.light.fg_noise)

    sys.state.sensor_value = integrate((a) => incident_light(sys, a)*sensitivity(sys, a),
			 -Math.PI, Math.PI, 100) + urand(sys.settings.sensor_noise);
}

var polar_samples = 180
var graph_theta = Array.from(Array(polar_samples).keys()).map(
		    (t) => ((t/(polar_samples/2)) - 1)*Math.PI);

function rad2deg(r)
{
    return (r/Math.PI)*180;
}

function update_plots(sys)
{
    var this_sensitivity = graph_theta.map((t) => [sensitivity(sys, t), rad2deg(t)]);
    var this_incident = graph_theta.map((t) => [incident_light(sys, t), rad2deg(t)]);


    charts.sensor_angles.setOption({
	series: [{
	    coordinateSystem: 'polar',
	    name: 'Sensitivity',
	    type: 'line',
	    data: this_sensitivity
	},
	{
	    coordinateSystem: 'polar',
	    name: 'Incident light',
	    type: 'line',
	    data: this_incident
	}]
    });

    charts.sensor_sequence.shift();
    charts.sensor_sequence.push(sys.state.sensor_value);
    var N = charts.sensor_sequence.length;
    var k = charts.sample_counter;
    charts.sample_counter += 1;

    charts.sensor_timeseries.setOption({
	xAxis: {data:Array.from(Array(N).keys()).map((i) => i+k)},
	series: [{
	    name: 'Noise',
	    type: 'line',
	    data: charts.sensor_sequence
	}]
    });
}

function setup_charts()
{
    var container = document.getElementById('graphs');



    var sensor_timeseries = document.createElement('div');
    container.appendChild(sensor_timeseries)

    var orientation_simeseries = document.createElement('div');
    container.appendChild(orientation_simeseries)
    var sensor_angles = document.createElement('div');
    container.appendChild(sensor_angles)

    charts.sensor_angles =  echarts.init(sensor_angles);
    charts.sensor_timeseries =  echarts.init(sensor_timeseries);
    charts.orientation_simeseries =  echarts.init(orientation_simeseries);

    charts.sensor_sequence = Array.from(Array(100).keys()).map((i) => 0);
    charts.sample_counter = 0;

    charts.sensor_angles.setOption({
	title: {
	    text: 'Light reception / sensitivity'
	},
	polar: {},
	tooltip: {
	    trigger: 'axis',
	    axisPointer: {
		type: 'cross'
	    },
	    formatter: '{a0}: {c0}<br/>{a1}: {c1}'
	},
	angleAxis: {
	    type: 'value',
	    startAngle: 0
	},
	radiusAxis: {}
    });

    charts.sensor_timeseries.setOption({
	title: {
	    text: 'Sensor value'
	},
	tooltip: {},
	yAxis: {},
	xAxis: {data:Array.from(Array(25).keys())},
    });
}

function setup_all()
{
    var counter = 0;

    setup_charts()

    system._interval_id = window.setInterval(function () {
	update_sim(system)
	if ((counter % system.settings.plot_divisor) == 0) {
	    update_plots(system);
	    counter = 1;
	} else {
	    counter += 1;
	}
    },
    1000/system.sample_rate);
}

setup_all()
