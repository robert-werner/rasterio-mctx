import multiprocessing
import os

from rasterio._err cimport exc_wrap_pointer
from concurrent import futures

include "rasterio/gdal.pxi"

from rasterio.apps._vrt cimport GDALBuildVRT, GDALBuildVRTOptions, GDALBuildVRTOptionsNew, GDALBuildVRTOptionsFree

RESAMPLE_ALGORITHMS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALBuildVRTOptions* create_build_vrt_options(files_as_bands=None,
                                                   resample_algorithm='bilinear',
                                                   bands_list=None,
                                                   add_alpha_channel=None,
                                                   source_nodata=None,
                                                   dest_nodata=None,
                                                   vrt_resolution='highest',
                                                   allow_projection_difference=True) except NULL:
    vrt_options_list = []
    if allow_projection_difference:
        vrt_options_list += ['-allow_projection_difference']
    if vrt_resolution:
        vrt_options_list += ['-r', str(vrt_resolution)]
    if files_as_bands:
        vrt_options_list += ['-separate']
    if bands_list:
        if isinstance(bands_list, list):
            for band in bands_list:
                vrt_options_list += ['-b', str(band)]
        if isinstance(bands_list, str) or isinstance(bands_list, int):
            vrt_options_list += ['-b', str(bands_list)]
    if add_alpha_channel:
        vrt_options_list += ['-addalpha']
    if resample_algorithm:
        vrt_options_list += RESAMPLE_ALGORITHMS.get(resample_algorithm, ['-r', str(resample_algorithm)])
    if source_nodata:
        if isinstance(source_nodata, int):
            vrt_options_list += ['-srcnodata', str(source_nodata)]
        if isinstance(source_nodata, list) or isinstance(source_nodata, tuple):
            vrt_options_list += ['-srcnodata', f'{" ".join([str(nodata) for nodata in source_nodata])}']
    if dest_nodata is not None:
        if isinstance(dest_nodata, int):
            vrt_options_list += ['-vrtnodata', str(dest_nodata)]
        if isinstance(dest_nodata, list) or isinstance(dest_nodata, tuple):
            vrt_options_list += ['-vrtnodata', f'{" ".join([str(nodata) for nodata in dest_nodata])}']

    str_joined_options = " ".join(vrt_options_list).encode('utf-8')
    cdef char** c_vrt_options_list = CSLParseCommandLine(str_joined_options)

    cdef GDALBuildVRTOptions* build_vrt_options = NULL
    build_vrt_options = GDALBuildVRTOptionsNew(c_vrt_options_list, NULL)
    return build_vrt_options

cpdef build_vrt(source_filenames,
                dest_filename,
                bands_list=None,
                resample_algorithm='bilinear',
                files_as_bands=True,
                allow_projection_difference=True,
                add_alpha_channel=None,
                source_nodata=None,
                dest_nodata=None,
                vrt_resolution='highest'):
    GDALAllRegister()

    cdef GDALBuildVRTOptions* build_vrt_options = NULL
    build_vrt_options = create_build_vrt_options(files_as_bands=files_as_bands,
                                                 bands_list=bands_list,
                                                 resample_algorithm=resample_algorithm,
                                                 allow_projection_difference=allow_projection_difference,
                                                 add_alpha_channel=add_alpha_channel,
                                                 source_nodata=source_nodata,
                                                 dest_nodata=dest_nodata,
                                                 vrt_resolution=vrt_resolution)

    cdef int source_filenames_list_idx = 0
    cdef char *c_source_filename = NULL
    cdef GDALDatasetH* source_datasets = NULL

    source_datasets = <GDALDatasetH *> CPLMalloc(
        <int> len(source_filenames) * sizeof(GDALDatasetH)
    )

    for source_filename_idx in range(len(source_filenames)):
        source_datasets[<int>source_filename_idx] = exc_wrap_pointer(GDALOpen(source_filenames[source_filename_idx].encode('utf-8'), GA_ReadOnly))

    cdef int progressbar_usage_error

    dest_dataset = GDALBuildVRT(dest_filename.encode('utf-8'), len(source_filenames), source_datasets, NULL, build_vrt_options, &progressbar_usage_error)

    try:
        exc_wrap_pointer(dest_dataset)
    finally:
        for source_filename_idx in range(len(source_filenames)):
            GDALClose(source_datasets[<int> source_filename_idx])
        GDALBuildVRTOptionsFree(build_vrt_options)
        GDALClose(dest_dataset)

        GDALDestroyDriverManager()
        return dest_filename

