var bounds = L.latLngBounds([SETTINGS.extent[1], SETTINGS.extent[0]],
                            [SETTINGS.extent[3], SETTINGS.extent[2]]);

var map = L.map('map', {maxBounds: bounds});

var options = {
    attribution: '&copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors',
    maxZoom: 20
};

var baselayers = {};
for (var k in SETTINGS.layers) {
    baselayers[k] = L.tileLayer(SETTINGS.layers[k], options);
}
baselayers[k].addTo(map);

L.control.layers.minimap(baselayers, [], {
    position: 'bottomright',
    collapsed: false
}).addTo(map);

map.fitBounds(bounds);
