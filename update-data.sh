#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

OSM_MIRROR_CONF=/etc/default/openstreetmap-conf

STYLES_PATH=/etc/mapnik-osm-data/makina

source $OSM_MIRROR_CONF

function echo_step () {
    echo -e "\e[92m\e[1m$1\e[0m"
}


#.......................................................................

output=/tmp/data.osm

if [ -f $output ]; then
    echo_step "Re-use previously downloaded data..."
else
    echo_step "Download OpenStreetMap data..."
    wget http://www.overpass-api.de/api/xapi?map?bbox=${EXTENT} -O ${output}
fi


#.......................................................................

echo_step "Load into database..."

sudo -n -u postgres -s -- osm2pgsql -d ${DB_NAME} --extra-attributes --create --expire-tiles 9-14 -o /tmp/expire.list ${output}
if [ $? -eq 0 ]; then
    rm ${output}

    for style in `ls $STYLES_PATH`; do
        cat /tmp/expire.list | awk '{split($0,a,"/"); print a[2],a[3],a[1]}' | render_list --map=$style --socket=/var/run/renderd/renderd.sock
    done;

    echo_step "Done."
fi
