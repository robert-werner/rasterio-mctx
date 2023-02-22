include "rasterio/gdal.pxi"

from rasterio.apps._translate cimport GDALTranslate, GDALTranslateOptions, GDALTranslateOptionsNew, GDALTranslateOptionsFree


cdef GDALTranslateOptions* create_translate_options(char** argv) nogil:
    cdef GDALTranslateOptions* translate_options
    translate_options = GDALTranslateOptionsNew(argv, NULL)
    return translate_options

cdef GDALDatasetH translate(char* source_filename, char* dest_filename, GDALTranslateOptions* translate_options) nogil:
    GDALAllRegister()

    cdef GDALDatasetH source_hds
    source_hds = GDALOpen(source_filename, GA_ReadOnly)

    cdef GDALDatasetH dest_hds
    cdef int pbUsageError
    dest_hds = GDALTranslate(dest_filename, source_hds, translate_options, &pbUsageError)

    GDALClose(dest_hds)
    GDALClose(source_hds)
    GDALTranslateOptionsFree(translate_options)

    GDALDestroyDriverManager()