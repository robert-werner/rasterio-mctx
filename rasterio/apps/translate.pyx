include "rasterio/gdal.pxi"

from rasterio.apps._translate cimport GDALTranslate, GDALTranslateOptions, GDALTranslateOptionsNew, GDALTranslateOptionsFree

DTYPES = {
    'Byte': 'Byte'
}

RESAMPLE_ALGS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALTranslateOptions* create_translate_options(bands=None,
                                                    input_format=None,
                                                    output_format=None,
                                                    resample_algo='bilinear',
                                                    configuration_options=None,
                                                    scale=None,
                                                    output_dtype=None) except NULL:
    options = []
    if resample_algo:
        options += RESAMPLE_ALGS.get(resample_algo, ['-r', str(resample_algo)])
    if output_dtype:
        options += ['-ot', str(DTYPES[output_dtype])]
    if scale:
        for _scale in scale:
            options += ['-scale', str(_scale[0]), str(_scale[1])]
    if input_format:
        options += ['-if', str(input_format)]
    if output_format:
        options += ['-of', str(output_format)]
    if bands:
        if isinstance(bands, list):
            for band in bands:
                options += ['-b', str(band)]
        if isinstance(bands, str) or isinstance(bands, int):
            options += ['-b', str(bands)]
    if configuration_options:
        for configuration_option in configuration_options:
            options += ['-co', configuration_option]
    enc_str_options = " ".join(options).encode('utf-8')
    cdef char** enc_str_options_ptr = CSLParseCommandLine(enc_str_options)

    cdef GDALTranslateOptions* translate_options = NULL
    with nogil:
         translate_options = GDALTranslateOptionsNew(enc_str_options_ptr, NULL)
    return translate_options

cdef GDALDatasetH _translate(src_ds,
                dst_ds,
                bands=None,
                input_format=None,
                output_format=None,
                resample_algo='bilinear',
                configuration_options=None,
                scale=None,
                output_dtype=None) except NULL:
    GDALAllRegister()

    cdef GDALDatasetH src_hds_ptr = NULL
    src_ds_bytes = src_ds.encode('utf-8')
    cdef char *src_ds_ptr = src_ds_bytes
    with nogil:
        src_hds_ptr = GDALOpen(src_ds_ptr, GA_ReadOnly)

    cdef GDALTranslateOptions* gdal_translate_options = create_translate_options(bands=bands,
                                                                                 input_format=input_format,
                                                                                 output_format=output_format,
                                                                                 resample_algo=resample_algo,
                                                                                 configuration_options=configuration_options,
                                                                                 scale=scale,
                                                                                 output_dtype=output_dtype)
    dst_ds_bytes = dst_ds.encode('utf-8')
    cdef char* dst_ds_ptr = dst_ds_bytes
    cdef int pbUsageError = <int> 0
    cdef GDALDatasetH dst_hds = NULL

    with nogil:
        dst_hds = GDALTranslate(dst_ds_ptr, src_hds_ptr, gdal_translate_options, &pbUsageError)
    try:
        return dst_hds
    finally:
        GDALClose(dst_hds)
        GDALClose(src_hds_ptr)
        GDALTranslateOptionsFree(gdal_translate_options)
        GDALDestroyDriverManager()


def translate(src_ds,
              dst_ds,
              bands=None,
              input_format=None,
              output_format=None,
              resample_algo='bilinear',
              configuration_options=None,
              scale=None,
              output_dtype=None):
    _translate(src_ds,
               dst_ds,
               bands,
               input_format,
               output_format,
               resample_algo,
               configuration_options,
               scale,
               output_dtype)
