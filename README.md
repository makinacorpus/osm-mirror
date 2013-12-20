OpenStreetMap Mirror
====================

Up-to-date OpenStreetMap tile server, with various map styles.


Main Purpose
------------

* Provide an easy way to setup the full stack ;
* Targetted for small areas (e.g. cities) ;
* One configuration file to handle ;
* Small preview page app using Leaflet.

![Preview](./capture.jpg)


Install
-------

Requirements

* Ubuntu 12.04 LTS
* 2 CPUs
* 2Go RAM
* 10Go disk
* Fast Internet connection

Just run the following commands :

    curl https://raw.github.com/makinacorpus/osm-mirror/master/install.sh > install.sh
    chmod +x install.sh
    sudo ./install.sh

A lot of data will be downloaded (Approx. 1Go).

You will be prompted for an extent (xmin,ymin,xmax,ymax). The default one is the city of Albi.
Use the [OpenStreetMap extent tool](http://www.openstreetmap.org/export#map=17/43.92751/2.14760) for help.

A planned task will be setup to **overwrite** the whole database with up-to-date
OpenStreetMap data, every month.



Change extent
-------------

Edit the ``EXTENT`` value in ``/etc/default/openstreetmap-conf``.


Update the configuration :

    sudo ./update-conf.sh


Refresh the data on the new extent :

    sudo ./update-data.sh


Add new style
-------------

Copy the whole folder into ``styles/``. Name the ``.xml`` file with the same
name as the folder.

Update the configuration :

    sudo ./update-conf.sh


Credits
-------

* [OSM Carto](https://github.com/gravitystorm/openstreetmap-carto), by gravitystorm
* [OSM Bright](https://github.com/mapbox/osm-bright), by MapBox


Authors
-------

* Frédéric Bonifas
* Mathieu Leplâtre

[![Makina Corpus](http://depot.makina-corpus.org/public/logo.gif)](http://makinacorpus.com)
