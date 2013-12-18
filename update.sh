#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


OSM_MIRROR_CONF=/etc/default/openstreetmap-conf

source $OSM_MIRROR_CONF

output=/tmp/data.osm
wget http://www.overpass-api.de/api/xapi?map?bbox=${EXTENT} -O ${output}
sudo -n -u postgres -s -- osm2pgsql -d ${DB_NAME} --extra-attributes ${output}
rm ${output}
