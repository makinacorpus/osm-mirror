#!/usr/bin/env python
import os
import logging

try:
    from mapnik import *
except ImportError:
    from mapnik2 import *


SRS = "+proj=lcc +lat_1=49 +lat_2=44 +lat_0=46.5 +lon_0=3 +x_0=700000 +y_0=6600000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


style = 'osm'
stylefile = os.path.join('styles', style, '%s.xml' % style)
output = 'output.png'
extension = output.rsplit('.', 1)[-1]
output_tif = output.replace(extension, 'tif')
width = 8000
height = 8000
extent = (2.04, 43.88, 2.22, 43.98)


def main():
    map = Map(width, height)
    load_map(map, stylefile)

    wgs84 = Projection('+proj=latlong +datum=WGS84')
    projection = Projection(SRS)
    env = ProjTransform(wgs84, projection)
    bbox = env.forward(Box2d(*extent))
    map.zoom_to_box(bbox)

    logger.info('Map extent: %s' % map.envelope())
    logger.info('Map center: %s' % map.envelope().center())
    logger.info('At current scale of %s...' % map.scale())
    logger.info('Map scale denominator: %s' % map.scale_denominator())

    render_to_file(map, output, extension)

    opts = ' -ot Byte -co COMPRESS=JPEG -co JPEG_QUALITY=100'
    base_cmd = 'gdal_translate %s %s -a_srs "%s" %s'
    cmd = base_cmd % (output, output_tif, SRS, opts)
    os.system(cmd)


if __name__ == '__main__':
    main()
