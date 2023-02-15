import rasterio

include "rasterio/gdal.pxi"

from rasterio.apps._vrt cimport GDALBuildVRT, GDALBuildVRTOptions, GDALBuildVRTOptionsNew, GDALBuildVRTOptionsFree

RESAMPLE_ALGS = {
GDALRIOResampleAlg.GRIORA_NearestNeighbour: ['-r', 'near'],
GDALRIOResampleAlg.GRIORA_Bilinear: ['-rb'],
GDALRIOResampleAlg.GRIORA_Cubic: ['-rc'],
GDALRIOResampleAlg.GRIORA_CubicSpline: ['-rcs'],
GDALRIOResampleAlg.GRIORA_Lanczos: ['-r', 'lanczos'],
GDALRIOResampleAlg.GRIORA_Average: ['-r', 'average'],
GDALRIOResampleAlg.GRIORA_Mode: ['-r', 'mode'],
GDALRIOResampleAlg.GRIORA_Gauss: ['-r', 'gauss']
}

cdef GDALBuildVRTOptions* create_buildvrt_options(separate=None,
                                                  resampleAlg='near',
                                                  bandList=None,
                                                  addAlpha=None,
                                                  srcNodata=None,
                                                  vrtNodata=None,
                                                  resolution='highest') except NULL:
    options = []
    if resolution:
        options += ['-r', str(resolution)]
    if separate:
        options += ['-separate']
    if bandList:
        for b in bandList:
            options += ['-b', str(b)]
    if addAlpha:
        options += ['-addalpha']
    if resampleAlg:
        options += RESAMPLE_ALGS.get(resampleAlg, ['-r', str(resampleAlg)])
    if srcNodata:
        if isinstance(srcNodata, int):
            options += ['-srcnodata', str(srcNodata)]
        if isinstance(srcNodata, list) or isinstance(srcNodata, tuple):
            options += ['-srcnodata', f'{" ".join([str(nodata) for nodata in srcNodata])}']
    if vrtNodata is not None:
        if isinstance(vrtNodata, int):
            options += ['-vrtnodata', str(vrtNodata)]
        if isinstance(vrtNodata, list) or isinstance(vrtNodata, tuple):
            options += ['-vrtnodata', f'{" ".join([str(nodata) for nodata in vrtNodata])}']

    enc_str_options = " ".join(options).encode('utf-8')
    cdef char** enc_str_options_ptr = CSLParseCommandLine(enc_str_options)

    cdef GDALBuildVRTOptions* buildvrt_options = NULL
    with nogil:
        buildvrt_options = GDALBuildVRTOptionsNew(enc_str_options_ptr, NULL)
    return buildvrt_options


cpdef build_vrt(src_ds_s,
                dst_ds,
                separate=True):
    GDALAllRegister()

    cdef GDALBuildVRTOptions* buildvrt_options = NULL
    buildvrt_options = create_buildvrt_options(separate=separate)
    cdef int src_ds_len = <int>len(src_ds_s)

    cdef GDALDatasetH* hds_list = NULL
    hds_list = <GDALDatasetH *> CPLMalloc(
        src_ds_len * sizeof(GDALDatasetH)
    )

    cdef int i = 0
    while i < src_ds_len:
        hds_list[i] = GDALOpen(src_ds_s[i].encode('utf-8'), GA_ReadOnly)
        i += 1

    dst_ds_enc = dst_ds.encode('utf-8')
    cdef char* dst_ds_ptr = dst_ds_enc

    cdef int pbUsageError = <int> 0

    with nogil:
        dst_hds = GDALBuildVRT(dst_ds_ptr, src_ds_len, hds_list, NULL, buildvrt_options, &pbUsageError)
        GDALClose(dst_hds)
    return dst_ds
