include "rasterio/gdal.pxi"

from rasterio.apps._vrt cimport GDALBuildVRT, GDALBuildVRTOptions, GDALBuildVRTOptionsNew

RESAMPLE_ALGS = {
'near': ['-r', 'near'],
'bilinear': ['-r', 'bilinear'],
'cubic': ['-r', 'cubic'],
'cubic_spline': ['-r', 'cubic_spline'],
'lanczos': ['-r', 'lanczos'],
'average': ['-r', 'average']
}

cdef GDALBuildVRTOptions* create_buildvrt_options(separate=None,
                                                  resample_algo='bilinear',
                                                  band_list=None,
                                                  add_alpha=None,
                                                  src_nodata=None,
                                                  vrt_nodata=None,
                                                  resolution='highest',
                                                  allow_projection_difference=True) except NULL:
    options = []
    if allow_projection_difference:
        options += ['-allow_projection_difference']
    if resolution:
        options += ['-r', str(resolution)]
    if separate:
        options += ['-separate']
    if band_list:
        if isinstance(band_list, list):
            for band in band_list:
                options += ['-b', str(band)]
        if isinstance(band_list, str) or isinstance(band_list, int):
            options += ['-b', str(band_list)]
    if add_alpha:
        options += ['-addalpha']
    if resample_algo:
        options += RESAMPLE_ALGS.get(resample_algo, ['-r', str(resample_algo)])
    if src_nodata:
        if isinstance(src_nodata, int):
            options += ['-srcnodata', str(src_nodata)]
        if isinstance(src_nodata, list) or isinstance(src_nodata, tuple):
            options += ['-srcnodata', f'{" ".join([str(nodata) for nodata in src_nodata])}']
    if vrt_nodata is not None:
        if isinstance(vrt_nodata, int):
            options += ['-vrtnodata', str(vrt_nodata)]
        if isinstance(vrt_nodata, list) or isinstance(vrt_nodata, tuple):
            options += ['-vrtnodata', f'{" ".join([str(nodata) for nodata in vrt_nodata])}']

    enc_str_options = " ".join(options).encode('utf-8')
    cdef char** enc_str_options_ptr = CSLParseCommandLine(enc_str_options)

    cdef GDALBuildVRTOptions* buildvrt_options = NULL
    with nogil:
        buildvrt_options = GDALBuildVRTOptionsNew(enc_str_options_ptr, NULL)
    return buildvrt_options


cdef GDALDatasetH _build_vrt(src_ds,
                             dst_ds,
                             bands=None,
                             resample_algo='bilinear',
                             separate=True,
                             allow_projection_difference=True,
                             add_alpha=None,
                             src_nodata=None,
                             vrt_nodata=None,
                             resolution='highest') except NULL:
    GDALAllRegister()

    cdef GDALBuildVRTOptions* buildvrt_options = NULL
    buildvrt_options = create_buildvrt_options(separate=separate,
                                               band_list=bands,
                                               resample_algo=resample_algo,
                                               allow_projection_difference=allow_projection_difference,
                                               add_alpha=add_alpha,
                                               src_nodata=src_nodata,
                                               vrt_nodata=vrt_nodata,
                                               resolution=resolution)
    cdef int src_ds_len = <int> len(src_ds)

    cdef int i = 0
    cdef char *src_ds_ptr = NULL
    cdef GDALDatasetH* hds_list = NULL

    hds_list = <GDALDatasetH *> CPLMalloc(
        src_ds_len * sizeof(GDALDatasetH)
    )
    while i < src_ds_len:
        src_ds_bytes = src_ds[i].encode('utf-8')
        src_ds_ptr = src_ds_bytes
        with nogil:
            hds_list[i] = GDALOpen(src_ds_ptr, GA_ReadOnly)
        i += 1

    dst_ds_bytes = dst_ds.encode('utf-8')
    cdef char* dst_ds_ptr = dst_ds_bytes

    cdef int pbUsageError = <int> 0

    with nogil:
        dst_hds = GDALBuildVRT(dst_ds_ptr, src_ds_len, hds_list, NULL, buildvrt_options, &pbUsageError)
    try:
        return dst_hds
    finally:
        GDALClose(dst_hds)

def build_vrt(src_ds,
              dst_ds,
              bands=None,
              resample_algo='bilinear',
              separate=True,
              allow_projection_difference=True):
    _build_vrt(src_ds, dst_ds, bands, resample_algo, separate)