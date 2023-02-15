include "rasterio/gdal.pxi"

from rasterio.apps._translate cimport GDALTranslate, GDALTranslateOptions, GDALTranslateOptionsNew, GDALTranslateOptionsFree

dtype_dict = {
    'Byte': 'Byte'
}

cdef GDALTranslateOptions* create_translate_options(bands=None,
                                                    input_format=None,
                                                    output_format=None,
                                                    configuration_options=None,
                                                    scale=None,
                                                    output_dtype=None) except NULL:
    options = []
    if output_dtype:
        options += ['-ot', str(dtype_dict[output_dtype])]
    if scale:
        try:
            iter(scale[0])
        except:
            options += ['-scale', str(scale[0]), str(scale[1])]
        else:
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

cpdef translate(src_ds,
                dst_ds,
                bands=None,
                input_format=None,
                output_format=None,
                configuration_options=None,
                scale=None,
                output_dtype=None):
    GDALAllRegister()

    cdef GDALDatasetH src_ds_ptr = NULL

    src_ds_ptr = GDALOpen(src_ds.encode('utf-8'), GA_ReadOnly)
    if src_ds_ptr == NULL:
        raise RuntimeError('Dataset is NULL')
    dst_ds_bytes = dst_ds.encode('utf-8')
    cdef char* dst_ds_enc = dst_ds_bytes


    cdef int pbUsageError = <int> 0
    cdef GDALDatasetH dst_hds = NULL
    cdef GDALTranslateOptions* gdal_translate_options = create_translate_options(bands, input_format,
                                                                                 output_format, configuration_options,
                                                                                 scale,
                                                                                 output_dtype)
    with nogil:
        dst_hds = GDALTranslate(dst_ds_enc, src_ds_ptr, gdal_translate_options, &pbUsageError)
        if dst_hds == NULL:
            raise RuntimeError('Destination dataset is null!')
        GDALClose(dst_hds)
        GDALClose(src_ds_ptr)
        GDALTranslateOptionsFree(gdal_translate_options)
    return dst_ds
