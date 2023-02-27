include "rasterio/gdal.pxi"

cimport numpy as np

from rasterio._err cimport exc_wrap_int, exc_wrap_pointer

cpdef min_max(source_filename):
    GDALAllRegister()

    cdef double[2] min_max_arr

    cdef GDALDatasetH source_dataset = exc_wrap_pointer(GDALOpen(source_filename.encode('utf-8'), GA_ReadOnly))

    cdef GDALRasterBandH source_raster_band = GDALGetRasterBand(source_dataset, 1)


    try:
        exc_wrap_int(GDALComputeRasterMinMax(source_raster_band, <int> 1, min_max_arr))
    finally:
        GDALClose(source_dataset)
        GDALDestroyDriverManager()

        return min_max_arr