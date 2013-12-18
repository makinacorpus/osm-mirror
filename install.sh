#!/bin/bash

OSM_MIRROR_CONF=/etc/default/openstreetmap-conf


function echo_step () {
    echo -e "\e[92m\e[1m$1\e[0m"
}


function echo_error () {
    echo -e "\e[91m\e[1m$1\e[0m"
}



echo_step "Upgrade operating system..."

apt-get update > /dev/null
apt-get install -y python-software-properties
apt-add-repository -y ppa:git-core/ppa
apt-add-repository -y ppa:ubuntugis/ppa
apt-get update > /dev/null

apt-get dist-upgrade -y




echo_step "Install necessary components..."

apt-get install -y libgdal1 gdal-bin

export DEBIAN_FRONTEND=noninteractive
apt-get install -y libapache2-mod-tile




if [ ! -f README.md ]; then
   echo_step "Downloading resources..."
   git clone --depth=50 --branch=master https://github.com/makinacorpus/osm-mirror.git /tmp/osm-mirror
   rm -f /tmp/osm-mirror/install.sh
   shopt -s dotglob nullglob
   mv /tmp/osm-mirror/* .
fi



echo_step "Configure instance..."

if [[ -z "$EXTENT" ]]
    read -e -p "Enter extent (xmin,ymin,xmax,ymax):  " -i "2.04,43.88,2.22,43.98" EXTENT
fi

cat << _EOF_ > $OSM_MIRROR_CONF
DB_NAME="gis"
DB_USER="gisuser"
DB_PASSWORD="corpus"
EXTENT="${EXTENT}"
_EOF_

source $OSM_MIRROR_CONF




echo_step "Configure database..."

sudo -n -u postgres -s -- psql -d ${DB_NAME} -f /usr/share/postgresql/9.1/contrib/postgis-2.0/legacy.sql
sudo -n -u postgres -s -- psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
sudo -n -u postgres -s -- psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"
sudo -n -u postgres -s -- psql -d ${DB_NAME} -c "CREATE EXTENSION postgis;"
sudo -n -u postgres -s -- psql -d ${DB_NAME} -c "GRANT ALL ON spatial_ref_sys, geometry_columns, raster_columns TO ${DB_USER};"

cat << _EOF_ >> /etc/postgresql/9.1/main/pg_hba.conf
# Automatically added by OSM installation :
local    ${DB_NAME}     ${DB_USER}                 trust
_EOF_


echo_step "Load OpenStreetMap data..."

# TODO : setup cron



echo_step "Configure map styles..."

mkdir -p /etc/mapnik-osm-data/makina
cp -R styles/* /etc/mapnik-osm-data/makina

# TODO : install fonts

cat << _EOF_ > /etc/renderd.conf
[renderd]
stats_file=/var/run/renderd/renderd.stats
socketname=/var/run/renderd/renderd.sock
num_threads=4

[mapnik]
plugins_dir=/usr/lib/mapnik/2.0/input
font_dir=/usr/share/fonts/truetype/ttf-dejavu
font_dir_recurse=false

[osm]
URI=/osm/
XML=/etc/mapnik-osm-data/osm.xml
DESCRIPTION=This is the standard osm mapnik style

[grayscale]
URI=/grayscale/
XML=/etc/mapnik-osm-data/makina/grayscale/grayscale.xml
DESCRIPTION=Grayscale

[bright]
URI=/bright/
XML=/etc/mapnik-osm-data/makina/bright/bright.xml
DESCRIPTION=Bright
_EOF_



echo_step "Deploy preview map..."

cp -R preview/* /var/www/osm



echo_step "Restart services..."

/etc/init.d/postgresql restart
/etc/init.d/renderd restart
/etc/init.d/apache2 restart


echo_step "Done."
