import os
include "rasterio/gdal.pxi"

from rasterio.apps._warp cimport GDALWarpAppOptions, GDALWarpAppOptionsFree, GDALWarp, GDALWarpAppOptionsNew


RESAMPLE_ALGS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALWarpAppOptions* create_warp_app_options(output_crs=None,
                                                 warp_memory_limit=None,
                                                 multi=None,
                                                 multi_threads=os.cpu_count(),
                                                 cutline_fn=None,
                                                 cutline_layer=None,
                                                 crop_to_cutline=None,
                                                 input_format=None,
                                                 output_format=None,
                                                 overwrite=None,
                                                 src_nodata=None,
                                                 dst_nodata=None,
                                                 set_source_color_interp=None,
                                                 resample_algo=None,
                                                 write_flush=None,
                                                 configuration_options=None,
                                                 target_extent=None,
                                                 target_extent_crs=None,
                                                 overview_level='NONE'):
    options = []
    if overview_level:
        options += ['-ovr', str(overview_level)]
    if target_extent:
        options += ['-te', ' '.join(list(map(str, target_extent)))]
        if target_extent_crs:
            options += ['-te_srs', f'"{target_extent_crs}"']
    if output_crs:
        options += ['-t_srs', f'"{output_crs}"']
    if input_format:
        options += ['-if', str(input_format)]
    if output_format:
        options += ['-of', str(output_format)]
    if warp_memory_limit:
        options += ['-wm', str(warp_memory_limit)]
    if write_flush:
        options += ['-wo', 'WRITE_FLUSH=YES']
    if multi:
        options += ['-multi']
        if multi_threads:
            options += ['-wo', f'NUM_THREADS={multi_threads}']
    if cutline_fn:
        options += ['-cutline', str(cutline_fn)]
        if crop_to_cutline:
            options += ['-crop_to_cutline']
        if cutline_layer:
            options += ['-cl', str(cutline_layer)]
    if overwrite:
        options += ['-overwrite']
    if src_nodata:
        options += ['-srcnodata', str(src_nodata)]
    if dst_nodata:
        options += ['-dstnodata', str(dst_nodata)]
    if set_source_color_interp:
        options += ['-setci']
    if resample_algo:
        options += RESAMPLE_ALGS.get(resample_algo, ['-r', str(resample_algo)])
    if configuration_options:
        for configuration_option in configuration_options:
            options += ['-co', configuration_option]
    enc_str_options = " ".join(options).encode('utf-8')
    cdef char** enc_str_options_ptr = CSLParseCommandLine(enc_str_options)

    cdef GDALWarpAppOptions* warp_app_options = NULL
    with nogil:
        warp_app_options = GDALWarpAppOptionsNew(enc_str_options_ptr, NULL)
    return warp_app_options


cdef GDALDatasetH _warp(src_ds,
                        dst_ds,
                        output_crs=None,
                        warp_memory_limit=None,
                        multi=None,
                        multi_threads=os.cpu_count(),
                        cutline_fn=None,
                        cutline_layer=None,
                        crop_to_cutline=None,
                        input_format=None,
                        output_format=None,
                        overwrite=None,
                        src_nodata=None,
                        dst_nodata=None,
                        set_source_color_interp=None,
                        resample_algo=None,
                        write_flush=False,
                        configuration_options=None,
                        target_extent=None,
                        target_extent_crs=None,
                        overview_level='NONE') except NULL:

    GDALAllRegister()

    cdef GDALDatasetH src_hds = NULL
    src_ds_bytes = src_ds.encode('utf-8')
    cdef char *src_ds_ptr = src_ds_bytes
    with nogil:
        src_hds = GDALOpen(src_ds_ptr, GA_ReadOnly)

    cdef GDALDatasetH *src_ds_ptr_list = NULL

    with nogil:
        src_ds_ptr_list = <GDALDatasetH *> CPLMalloc(1 * sizeof(GDALDatasetH))
        src_ds_ptr_list[0] = src_hds

    cdef int pbUsageError = <int> 0
    cdef int src_count = <int> 1

    cdef GDALDatasetH dst_hds = NULL
    cdef GDALWarpAppOptions *warp_app_options = NULL
    warp_app_options = create_warp_app_options(output_crs=output_crs,
                                               warp_memory_limit=warp_memory_limit,
                                               multi=multi,
                                               multi_threads=multi_threads,
                                               cutline_fn=cutline_fn,
                                               cutline_layer=cutline_layer,
                                               crop_to_cutline=crop_to_cutline,
                                               input_format=input_format,
                                               output_format=output_format,
                                               overwrite=overwrite,
                                               write_flush=write_flush,
                                               configuration_options=configuration_options,
                                               target_extent=target_extent,
                                               target_extent_crs=target_extent_crs,
                                               overview_level=overview_level,
                                               src_nodata=src_nodata,
                                               dst_nodata=dst_nodata,
                                               set_source_color_interp=set_source_color_interp,
                                               resample_algo=resample_algo)

    dst_ds_bytes = dst_ds.encode('utf-8')
    cdef char *dst_ds_ptr = dst_ds_bytes
    with nogil:
        dst_hds = GDALWarp(dst_ds_ptr, NULL, src_count, src_ds_ptr_list, warp_app_options, &pbUsageError)
    try:
        return dst_hds
    finally:
        GDALClose(dst_hds)
        GDALClose(src_ds_ptr_list[0])
        CPLFree(src_ds_ptr_list)
        GDALWarpAppOptionsFree(warp_app_options)
        GDALDestroyDriverManager()

def warp(src_ds,
         dst_ds,
         output_crs=None,
         warp_memory_limit=None,
         multi=None,
         multi_threads=os.cpu_count(),
         cutline_fn=None,
         cutline_layer=None,
         crop_to_cutline=None,
         input_format=None,
         output_format=None,
         overwrite=None,
         src_nodata=None,
         dst_nodata=None,
         set_source_color_interp=None,
         resample_algo='bilinear',
         write_flush=False,
         configuration_options=None,
         target_extent=None,
         target_extent_crs=None,
         overview_level='NONE'):
    _warp(src_ds,
          dst_ds,
          output_crs,
          warp_memory_limit,
          multi,
          multi_threads,
          cutline_fn,
          cutline_layer,
          crop_to_cutline,
          input_format,
          output_format,
          overwrite,
          src_nodata,
          dst_nodata,
          set_source_color_interp,
          resample_algo,
          write_flush,
          configuration_options,
          target_extent,
          target_extent_crs,
          overview_level)