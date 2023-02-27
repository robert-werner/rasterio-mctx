include "rasterio/gdal.pxi"

from rasterio._err cimport exc_wrap_pointer

cpdef min_max(source_filename):
    GDALAllRegister()

    cdef double min_max_arr[2]

    cdef GDALDatasetH source_dataset = exc_wrap_pointer(GDALOpen(source_filename.encode('utf-8'), GA_ReadOnly))

    cdef GDALRasterBandH raster_band = GDALGetRasterBand(source_dataset, 1)

