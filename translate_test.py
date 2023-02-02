import os

import parallelbar
from rasterio.apps.warp import warp

from rasterio.apps.translate import translate

os.environ['CPL_LOG'] = '/dev/null'


def warp_wrapper(kwargs):
    return warp(**kwargs)


warp_params = [{
    'src_ds': f'/Users/leonid/Documents/development/grib-tiler/test/samples/GRIB input samples/test/gfs_{i}.grib2',
    'dst_ds': f'/Users/leonid/Documents/development/grib-tiler/test/samples/GRIB input samples/test/crs/gfs_{i}.tiff',
    'output_crs': 'EPSG:3575',
    'output_format': 'GTiff',
    'overwrite': True
} for i in range(1, 679)]

tasks = [('/Users/leonid/Documents/development/grib-tiler/test/samples/GRIB input samples/input/gfs_test.grib2',
          f'/Users/leonid/Documents/development/grib-tiler/test/samples/GRIB input samples/test/gfs_{i}.grib2',
          [i]) for i in range(1, 697)]

if __name__ == '__main__':
    parallelbar.progress_map(warp_wrapper, warp_params, n_cpu=6)
