#!/bin/bash

OSM_MIRROR_CONF=/etc/default/openstreetmap-conf


function echo_step () {
    echo -e "\e[92m\e[1m$1\e[0m"
}

function echo_error () {
    echo -e "\e[91m\e[1m$1\e[0m"
}


#.......................................................................

trusty=$(grep "Ubuntu 14.04" /etc/issue | wc -l)

if [ ! $trusty -eq 1 ] ; then
    echo_error "Unsupported operating system. Aborted."
    exit 5
fi


#.......................................................................

echo_step "Configure instance..."

if [[ -z "$EXTENT" ]]; then
    read -e -p "Enter extent (xmin,ymin,xmax,ymax):  " -i "2.04,43.88,2.22,43.98" EXTENT
fi

cat << _EOF_ > $OSM_MIRROR_CONF
DB_NAME="gis"
DB_USER="gisuser"
DB_PASSWORD="corpus"
EXTENT="${EXTENT}"
_EOF_

source $OSM_MIRROR_CONF


#.......................................................................

echo_step "Upgrade operating system..."

apt-get update > /dev/null
apt-get install -y software-properties-common
add-apt-repository -y ppa:kakrueger/openstreetmap
apt-get update > /dev/null

apt-get dist-upgrade -y


#.......................................................................

echo_step "Install necessary components..."

apt-get install -y git curl wget libgdal1h gdal-bin mapnik-utils unzip

locale-gen en_US en_US.UTF-8
locale-gen fr_FR fr_FR.UTF-8
dpkg-reconfigure locales

export DEBIAN_FRONTEND=noninteractive
apt-get install -y libapache2-mod-tile


#.......................................................................

if [ ! -f README.md ]; then
   echo_step "Downloading installer source..."
   git clone --recursive --depth=50 --branch=trusty https://github.com/makinacorpus/osm-mirror.git /tmp/osm-mirror
   rm -f /tmp/osm-mirror/install.sh
   shopt -s dotglob nullglob
   cp -R /tmp/osm-mirror/* .
fi


#.......................................................................

echo_step "Configure database..."

sudo -n -u postgres -s -- psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
sudo -n -u postgres -s -- psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"
sudo -n -u postgres -s -- psql -d ${DB_NAME} -c "CREATE EXTENSION postgis;"
sudo -n -u postgres -s -- psql -d ${DB_NAME} -c "GRANT ALL ON spatial_ref_sys, geometry_columns, raster_columns TO ${DB_USER};"

cat << _EOF_ >> /etc/postgresql/9.3/main/pg_hba.conf
# Automatically added by OSM installation :
local    ${DB_NAME}     ${DB_USER}                 trust
host     ${DB_NAME}     ${DB_USER}   127.0.0.1/32  trust
_EOF_

echo_step "Restart service..."

/etc/init.d/postgresql restart


#.......................................................................

OSM_DATA=/usr/share/mapnik-osm-data/world_boundaries

if [ ! -f $OSM_DATA/10m-land.shp ]; then
    echo_step "Load world boundaries data..."
    mkdir -p $OSM_DATA

    zipfile=/tmp/ne_10m_populated_places.zip
    curl -L -o "$zipfile" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip"
    unzip -qqu $zipfile -d /tmp
    rm $zipfile
    mv /tmp/ne_10m_populated_places.* $OSM_DATA/
    ogr2ogr $OSM_DATA/ne_10m_populated_places_fixed.shp $OSM_DATA/ne_10m_populated_places.shp
    
    zipfile=/tmp/simplified-land-polygons-complete-3857.zip
    curl -L -o "$zipfile" "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip"
    unzip -qqu $zipfile simplified-land-polygons-complete-3857/simplified_land_polygons.{shp,shx,prj,dbf,cpg} -d /tmp
    rm $zipfile
    mv /tmp/simplified-land-polygons-complete-3857/simplified_land_polygons.* $OSM_DATA/


    zipfile=/tmp/land-polygons-split-3857.zip
    curl -L -o "$zipfile" "http://data.openstreetmapdata.com/land-polygons-split-3857.zip"
    unzip -qqu $zipfile -d /tmp
    rm $zipfile
    mv /tmp/land-polygons-split-3857/land_polygons.* $OSM_DATA/

    zipfile=/tmp/coastline-good.zip
    curl -L -o "$zipfile" "http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip"
    unzip -qqu $zipfile -d /tmp
    rm $zipfile
    mv /tmp/coastline-good.* $OSM_DATA/

    zipfile=/tmp/10m-land.zip
    curl -L -o "$zipfile" "http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip"
    unzip -qqu $zipfile -d /tmp
    rm $zipfile
    mv /tmp/10m-land.* $OSM_DATA/
    
    tarfile=/tmp/shoreline_300.tar.bz2
    curl -L -o "$tarfile" "http://tile.openstreetmap.org/shoreline_300.tar.bz2"
    tar -xf $tarfile -C /tmp
    rm $tarfile
    mv /tmp/shoreline_300.* $OSM_DATA/
    
    tarfile=/tmp/world_boundaries-spherical.tgz
    curl -L -o "$tarfile" "http://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz"
    tar -xf $tarfile -C /tmp
    rm $tarfile
    mv /tmp/world_boundaries/builtup_area.* $OSM_DATA/

    zipfile=/tmp/ne_110m_admin_0_boundary_lines_land.zip
    curl -L -o "$zipfile" "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip"
    unzip -qqu $zipfile -d /tmp
    rm $zipfile
    mv /tmp/ne_110m_admin_0_boundary_lines_land.* $OSM_DATA/

    
    shapeindex --shape_files \
    $OSM_DATA/simplified_land_polygons.shp \
    $OSM_DATA/land_polygons.shp \
    $OSM_DATA/coastline-good.shp \
    $OSM_DATA/10m-land.shp \
    $OSM_DATA/shoreline_300.shp \
    $OSM_DATA/ne_10m_populated_places_fixed.shp \
    $OSM_DATA/builtup_area.shp \
    $OSM_DATA/ne_110m_admin_0_boundary_lines_land.shp
    
fi


#.......................................................................

echo_step "Deploy preview map..."

rm /var/www/index.html
cp -R preview/* /var/www/


#.......................................................................

echo_step "Setup monthly update in root crontab..."

croncmd="`pwd`/update-data.sh 2> /var/log/openstreetmap-errors"
cronjob="0 2 1 * * $croncmd"
( crontab -u root -l 2> /dev/null | grep -v "$croncmd" ; echo "$cronjob" ) | crontab -u root -


#.......................................................................

./update-data.sh

# Grant rights on OSM tables
/usr/bin/install-postgis-osm-user.sh ${DB_NAME} www-data 2> /dev/null
/usr/bin/install-postgis-osm-user.sh ${DB_NAME} gisuser 2> /dev/null

#.......................................................................

./update-conf.sh

#.......................................................................

echo_step "Install done."
