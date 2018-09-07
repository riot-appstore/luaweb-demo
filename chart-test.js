
var system =
    settings: {
	light: {direction: 1.0,
		width: 0.2,
		distance: 2,
		intensity: 1.0,
		bg_intensity: 0.2,
		bg_noise: 0.05,
		fg_noise: 0.05
	    },
	sensor_noise: 0.05,
	servo_speed: 1,
	sample_rate: 100,
	plot_divisor: 10
    }
    state: {
	orientation: 0.0,
	setpoint: 0.0,
	sensor_value: 0.0
	_light_noise: 0.0
    }
};

var charts = {}

/* Wrap a value in radians so that it lies within [-PI,PI] */
function angle_wrap(a)
{
    if (Math.abs(a) > Math.PI) {
	a = a - Math.sign(a)*Math.PI;
    }

    return a;
}

function urand(a)
{
    return s * (Math.random() - 0.5);
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

    sys.state.orientation = angle_wrap(sys.orientation
		+ Math.sign(error) * sys.settings.servo_speed * sys.settings.sample_rate);

    sys.state._light_noise = urand(sys.settings.light.fg_noise)

    sys.state.sensor_value = integrate((a) => incident_light(sys, a)*sensitivity(sys, a),
			 -Math.PI, Math.PI, 100) + urand(sys.settings.sensor_noise);
}

function update_plots(sys)
{

}

function setup_charts()
{
    var container = document.getElementById('graphs');

    var sensor_angles = document.createElement('div');
    container.appendChild(sensor_angles)

    var sensor_timeseries = document.createElement('div');
    container.appendChild(sensor_timeseries)

    var orientation_simeseries = document.createElement('div');
    container.appendChild(orientation_simeseries)

    charts.sensor_angles =  echarts.init(sensor_angles);
    charts.sensor_timeseries =  echarts.init(sensor_timeseries);
    charts.orientation_simeseries =  echarts.init(orientation_simeseries);

    charts.sensor_angles.setOption({
	title: {
	    text: 'Light reception / sensitivity'
	},
	tooltip: {},
	legend: {
	    data:['Sensor', "Light source"]
	},
	yAxis: {},
	xAxis: {data:Array.from(Array(25).keys())},
	series: [{
	    name: 'Noise',
	    type: 'line',
	    data: randomsequence
	}]
    });
}

var randomsequence = Array.from({length: 25}, () => Math.random());

// specify chart configuration item and data
var option = {
    title: {
	text: 'Random noise'
    },
    tooltip: {},
    legend: {
	data:['Sales']
    },
    yAxis: {},
    xAxis: {data:Array.from(Array(25).keys())},
    series: [{
	name: 'Noise',
	type: 'line',
	data: randomsequence
    }]
};

// use configuration item and data specified to show chart
myChart.setOption(option);

var k = 0;

window.setInterval(function(){
    k = k+1;
    randomsequence.shift();
    randomsequence.push(Math.random());
    myChart.setOption({
	xAxis: {data:Array.from(Array(25).keys()).map((i) => i+k)},
	series: [{
	    name: 'Noise',
	    type: 'line',
	    data: randomsequence
	}]});
}, 500);
