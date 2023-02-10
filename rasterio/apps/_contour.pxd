include "rasterio/gdal.pxi"

cdef extern from "gdal_alg.h" nogil:

    CPLErr GDALContourGenerateEx(GDALRasterBandH hBand, void *hLayer, CSLConstList options, GDALProgressFunc pfnProgress, void *pProgressArg)

    CPLErr GDALContourGenerate(GDALRasterBandH hBand, double dfContourInterval, double dfContourBase,
                               int nFixedLevelCount, double *padfFixedLevels, int bUseNoData, double dfNoDataValue,
                               void *hLayer, int iIDField, int iElevField, GDALProgressFunc pfnProgress,
                               void *pProgressArg)