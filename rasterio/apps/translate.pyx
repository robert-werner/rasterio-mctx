include "rasterio/gdal.pxi"

from rasterio._err cimport exc_wrap_pointer
from rasterio.apps._translate cimport GDALTranslate, GDALTranslateOptions, GDALTranslateOptionsNew, GDALTranslateOptionsFree

DTYPES = {
    'Byte': 'Byte'
}

RESAMPLE_ALGORITHMS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALTranslateOptions* create_translate_options(bands_list=None,
                                                    input_format=None,
                                                    output_format=None,
                                                    resample_algorithm='bilinear',
                                                    configuration_options=None,
                                                    min_max_list=None,
                                                    output_dtype=None):
    translate_options_list = []
    if resample_algorithm:
        translate_options_list += RESAMPLE_ALGORITHMS.get(resample_algorithm, ['-r', str(resample_algorithm)])
    if output_dtype:
        translate_options_list += ['-ot', str(DTYPES[output_dtype])]
    if min_max_list:
        for _scale in min_max_list:
            translate_options_list += ['-scale', str(_scale[0]), str(_scale[1])]
    if input_format:
        translate_options_list += ['-if', str(input_format)]
    if output_format:
        translate_options_list += ['-of', str(output_format)]
    if bands_list:
        if isinstance(bands_list, list):
            for band in bands_list:
                translate_options_list += ['-b', str(band)]
        if isinstance(bands_list, str) or isinstance(bands_list, int):
            translate_options_list += ['-b', str(bands_list)]
    if configuration_options:
        for configuration_option in configuration_options:
            translate_options_list += ['-co', configuration_option]
    str_joined_options = " ".join(translate_options_list).encode('utf-8')
    cdef char** enc_str_options_ptr = CSLParseCommandLine(str_joined_options)

    cdef GDALTranslateOptions* translate_options = NULL
    translate_options = GDALTranslateOptionsNew(enc_str_options_ptr, NULL)
    return translate_options

cpdef translate(source_filename,
                             dest_filename,
                             bands_list=None,
                             input_format=None,
                             output_format=None,
                             resample_algorithm='bilinear',
                             configuration_options=None,
                             min_max_list=None,
                             output_dtype=None):
    GDALAllRegister()

    cdef GDALDatasetH source_dataset = exc_wrap_pointer(GDALOpen(source_filename.encode('utf-8'), GA_ReadOnly))

    cdef GDALTranslateOptions* gdal_translate_options = create_translate_options(bands_list=bands_list,
                                                                                 input_format=input_format,
                                                                                 output_format=output_format,
                                                                                 resample_algorithm=resample_algorithm,
                                                                                 configuration_options=configuration_options,
                                                                                 min_max_list=min_max_list,
                                                                                 output_dtype=output_dtype)

    cdef int pbUsageError = <int> 0

    dest_dataset = exc_wrap_pointer(GDALTranslate(dest_filename.encode('utf-8'), source_dataset, gdal_translate_options, &pbUsageError))

    GDALClose(dest_dataset)
    GDALClose(source_dataset)
    GDALTranslateOptionsFree(gdal_translate_options)
    GDALDestroyDriverManager()

    return dest_filename
