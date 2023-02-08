include "rasterio/gdal.pxi"

cdef extern from "gdal_utils.h" nogil:

    ctypedef struct GDALBuildVRTOptions
    ctypedef struct GDALBuildVRTOptionsForBinary

    void GDALBuildVRTOptionsFree(GDALBuildVRTOptions *psOptions)
    GDALBuildVRTOptions *GDALBuildVRTOptionsNew(char **papszArgv, GDALBuildVRTOptionsForBinary *psOptionsForBinary)

    GDALDatasetH GDALBuildVRT(const char *pszDest, int nSrcCount,
                              GDALDatasetH *pahSrcDS, const char *const *papszSrcDSNames,
                              const GDALBuildVRTOptions *psOptions, int *pbUsageError)
