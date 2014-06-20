#!/bin/bash

function echo_step () {
    echo -e "\e[92m\e[1m$1\e[0m"
}

function echo_error () {
    echo -e "\e[91m\e[1m$1\e[0m"
}


OSM_MIRROR_CONF=/etc/default/openstreetmap-conf
RENDERD_CONF=/etc/renderd.conf
STYLES_PATH=/etc/mapnik-osm-data/makina
PREVIEW_CONF=/var/www/conf.js

source $OSM_MIRROR_CONF

#.......................................................................

echo_step "Deploy map styles..."

if [ ! -d styles ]; then
    echo_error "Styles folder missing"
    exit 6
fi

mkdir -p $STYLES_PATH
cp -R styles/* $STYLES_PATH


#.......................................................................

echo_step "Update renderd configuration..."


cat << _EOF_ > $RENDERD_CONF
[renderd]
stats_file=/var/run/renderd/renderd.stats
socketname=/var/run/renderd/renderd.sock
num_threads=4

[mapnik]
plugins_dir=/usr/lib/mapnik/2.2/input
font_dir=/usr/share/fonts/truetype/ttf-dejavu
font_dir_recurse=false

_EOF_


for style in `ls ./styles/`; do
    cat << _EOF_ >> $RENDERD_CONF
[$style]
URI=/$style/
XML=$STYLES_PATH/$style/$style.xml
DESCRIPTION=$style

_EOF_
done;


#.......................................................................

echo_step "Update map preview configuration..."

cat << _EOF_ > $PREVIEW_CONF
var SETTINGS = {
    extent: [${EXTENT}],
    layers: {
_EOF_

for style in `ls ./styles/`; do
cat << _EOF_ >> $PREVIEW_CONF
'/$style/{z}/{x}/{y}.png': '/$style/{z}/{x}/{y}.png',
_EOF_
done;

cat << _EOF_ >> $PREVIEW_CONF
}
};
_EOF_


#.......................................................................

echo_step "Restart services..."

/etc/init.d/apache2 restart
/etc/init.d/renderd restart

echo_step "Done."
