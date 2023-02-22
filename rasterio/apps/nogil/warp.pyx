include "rasterio/gdal.pxi"

from rasterio.apps._warp cimport GDALWarpAppOptions, GDALWarpAppOptionsFree, GDALWarp, GDALWarpAppOptionsNew

cdef GDALWarpAppOptions* create_warp_options(char** argv) nogil:
    cdef GDALWarpAppOptions* warp_options
    warp_options = GDALWarpAppOptionsNew(argv, NULL)
    return warp_options

cdef GDALDatasetH warp(char* source_filename, char* dest_filename, GDALWarpAppOptions* warp_options) nogil:
    GDALAllRegister()

    cdef GDALDatasetH source_hds
    source_hds = GDALOpen(source_filename, GA_ReadOnly)

    cdef GDALDatasetH* source_datasets_list
    source_datasets_list = <GDALDatasetH*> CPLMalloc(1 * sizeof(GDALDatasetH))
    source_datasets_list[0] = source_hds

    cdef int pbUsageError
    cdef int src_count = 1

    cdef GDALDatasetH dest_hds
    dest_hds = GDALWarp(dest_filename, NULL, src_count, source_datasets_list, warp_options, &pbUsageError)

    GDALClose(dest_hds)
    GDALClose(source_datasets_list[0])
    CPLFree(source_datasets_list)
    GDALWarpAppOptionsFree(warp_options)

    GDALDestroyDriverManager()