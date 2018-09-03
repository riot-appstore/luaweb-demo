// based on prepared DOM, initialize echarts instance
var myChart = echarts.init(document.getElementById('graphs'));


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
