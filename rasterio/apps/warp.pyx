import os
include "rasterio/gdal.pxi"

from rasterio._err cimport exc_wrap_pointer
from rasterio.apps._warp cimport GDALWarpAppOptions, GDALWarpAppOptionsFree, GDALWarp, GDALWarpAppOptionsNew


RESAMPLE_ALGORITHMS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALWarpAppOptions* create_warp_app_options(output_crs=None,
                                                 warp_memory_limit=None,
                                                 multi_mode=False,
                                                 multi_threads=os.cpu_count(),
                                                 cutline_filename=None,
                                                 cutline_layer=None,
                                                 crop_to_cutline=None,
                                                 input_format=None,
                                                 output_format=None,
                                                 overwrite=None,
                                                 source_nodata=None,
                                                 output_nodata=None,
                                                 set_source_color_interp=None,
                                                 resample_algorithm='bilinear',
                                                 flush_to_disk=None,
                                                 configuration_options=None,
                                                 target_extent_bbox=None,
                                                 target_extent_crs=None,
                                                 overview_level='NONE'):
    warp_app_options_list = []
    if overview_level:
        warp_app_options_list += ['-ovr', str(overview_level)]
    if target_extent_bbox:
        warp_app_options_list += ['-te', ' '.join(list(map(str, target_extent_bbox)))]
        if target_extent_crs:
            warp_app_options_list += ['-te_srs', f'"{target_extent_crs}"']
    if output_crs:
        warp_app_options_list += ['-t_srs', f'"{output_crs}"']
    if input_format:
        warp_app_options_list += ['-if', str(input_format)]
    if output_format:
        warp_app_options_list += ['-of', str(output_format)]
    if warp_memory_limit:
        warp_app_options_list += ['-wm', str(warp_memory_limit)]
    if flush_to_disk:
        warp_app_options_list += ['-wo', 'WRITE_FLUSH=YES']
    if multi_mode:
        warp_app_options_list += ['-multi']
        if multi_threads:
            warp_app_options_list += ['-wo', f'NUM_THREADS={multi_threads}']
    if cutline_filename:
        warp_app_options_list += ['-cutline', str(cutline_filename)]
        if crop_to_cutline:
            warp_app_options_list += ['-crop_to_cutline']
        if cutline_layer:
            warp_app_options_list += ['-cl', str(cutline_layer)]
    if overwrite:
        warp_app_options_list += ['-overwrite']
    if source_nodata:
        warp_app_options_list += ['-srcnodata', str(source_nodata)]
    if output_nodata:
        warp_app_options_list += ['-dstnodata', str(output_nodata)]
    if set_source_color_interp:
        warp_app_options_list += ['-setci']
    if resample_algorithm:
        warp_app_options_list += RESAMPLE_ALGORITHMS.get(resample_algorithm, ['-r', str(resample_algorithm)])
    if configuration_options:
        for configuration_option in configuration_options:
            warp_app_options_list += ['-co', configuration_option]
    str_joined_options = " ".join(warp_app_options_list).encode('utf-8')
    cdef char** c_vrt_options_list = CSLParseCommandLine(str_joined_options)

    cdef GDALWarpAppOptions* warp_app_options = NULL
    warp_app_options = GDALWarpAppOptionsNew(c_vrt_options_list, NULL)
    return warp_app_options


cpdef warp(source_filename,
                        dest_filename,
                        output_crs=None,
                        warp_memory_limit=None,
                        multi_mode=None,
                        multi_threads=os.cpu_count(),
                        cutline_filename=None,
                        cutline_layer=None,
                        crop_to_cutline=None,
                        input_format=None,
                        output_format=None,
                        overwrite=None,
                        source_nodata=None,
                        dest_nodata=None,
                        set_source_color_interp=None,
                        resample_algorithm='bilinear',
                        flush_to_disk=False,
                        configuration_options=None,
                        target_extent_bbox=None,
                        target_extent_crs=None,
                        overview_level='NONE'):

    GDALAllRegister()

    cdef GDALDatasetH source_dataset = exc_wrap_pointer(GDALOpen(source_filename.encode('utf-8'), GA_ReadOnly))

    cdef int progressbar_usage_error = <int> 0

    cdef GDALWarpAppOptions *warp_app_options = create_warp_app_options(output_crs=output_crs,
                                               warp_memory_limit=warp_memory_limit,
                                               multi_mode=multi_mode,
                                               multi_threads=multi_threads,
                                               cutline_filename=cutline_filename,
                                               cutline_layer=cutline_layer,
                                               crop_to_cutline=crop_to_cutline,
                                               input_format=input_format,
                                               output_format=output_format,
                                               overwrite=overwrite,
                                               flush_to_disk=flush_to_disk,
                                               configuration_options=configuration_options,
                                               target_extent_bbox=target_extent_bbox,
                                               target_extent_crs=target_extent_crs,
                                               overview_level=overview_level,
                                               source_nodata=source_nodata,
                                               output_nodata=dest_nodata,
                                               set_source_color_interp=set_source_color_interp,
                                               resample_algorithm=resample_algorithm)

    dest_dataset = exc_wrap_pointer(GDALWarp(dest_filename.encode('utf-8'), NULL, <int>1, &source_dataset, warp_app_options, &progressbar_usage_error))

    GDALClose(dest_dataset)
    GDALClose(source_dataset)
    GDALWarpAppOptionsFree(warp_app_options)

    GDALDestroyDriverManager()
    return dest_filename
