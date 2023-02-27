from rasterio.apps._contour cimport GDALContourGenerateEx

from rasterio._err cimport exc_wrap_int, exc_wrap_pointer

include "rasterio/gdal.pxi"

cdef CSLConstList create_contour_generate_options(elev_interval=10.0,
                                                  elev_base=0,
                                                  elev_exp_base=0,
                                                  fixed_levels=None,
                                                  nodata=None,
                                                  idx_id_field=-1,
                                                  idx_elev_field=-1,
                                                  polygonize=False):
    cdef CSLConstList contour_generate_options = NULL

    if elev_interval:
        k = 'LEVEL_INTERVAL'.encode('utf-8')
        v = str(elev_interval).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if elev_base:
        k = 'LEVEL_BASE'.encode('utf-8')
        v = str(elev_base).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if elev_exp_base:
        k = 'LEVEL_EXP_BASE'.encode('utf-8')
        v = str(elev_exp_base).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if fixed_levels:
        k = 'FIXED_LEVELS'.encode('utf-8')
        v = ",".join([str(fixed_level) for fixed_level in fixed_levels]).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if nodata:
        k = 'NODATA'.encode('utf-8')
        v = str(nodata).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if idx_elev_field:
        print(idx_elev_field)
        k = 'ELEV_FIELD'.encode('utf-8')
        v = str(idx_elev_field).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if idx_id_field:
        k = 'ID_FIELD'.encode('utf-8')
        v = str(idx_id_field).encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    if polygonize is not None:
        k = 'POLYGONIZE'.encode('utf-8')
        v = ('ON' if polygonize else 'OFF').encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    else:
        k = 'POLYGONIZE'.encode('utf-8')
        v = 'OFF'.encode('utf-8')
        contour_generate_options = CSLAddNameValue(contour_generate_options, <const char *> k, <const char *> v)
    return contour_generate_options

cdef void create_elev_attrib(const char *pszElevAttrib, OGRLayerH vector_layer):
    cdef OGRFieldDefnH vector_layer_field = NULL
    vector_layer_field = OGR_Fld_Create(pszElevAttrib, OFTReal)
    cdef OGRErr eErr = OGR_L_CreateField(vector_layer, vector_layer_field, 0)
    OGR_Fld_Destroy(vector_layer_field)

cpdef build_contour(source_raster_filename, output_vector_filename,
                    source_band=1,
                    elevation_interval=10.0,
                    elevation_base=0,
                    elevation_exp_base=0,
                    fixed_levels=None,
                    nodata=None,
                    id_field=None,
                    elevation_field='ELEV',
                    polygonize=False,
                    vector_driver_name='GPKG'):
    GDALAllRegister()
    OGRRegisterAll()

    cdef GDALDatasetH source_raster_dataset = exc_wrap_pointer(GDALOpen(source_raster_filename, GA_ReadOnly))
    cdef OGRSpatialReferenceH source_srs = GDALGetSpatialRef(source_raster_dataset)

    cdef GDALRasterBandH dem_band = GDALGetRasterBand(source_raster_dataset, <int>source_band)

    cdef OGRSFDriverH vector_driver = OGRGetDriverByName(vector_driver_name)

    cdef OGRLayerH vector_layer = NULL

    cdef char* isolines_layername_ptr = 'ISOLINES'

    cdef char* elev_attrib_name = elevation_field

    cdef char* output_vector_ds_name = output_vector_filename

    cdef OGRDataSourceH vector_ds = OGR_Dr_CreateDataSource(vector_driver, output_vector_ds_name, NULL)

    if polygonize is True:
        vector_layer = OGR_DS_CreateLayer(vector_ds, isolines_layername_ptr, source_srs, wkbMultiPolygon, NULL)
    elif polygonize is False:
        vector_layer = OGR_DS_CreateLayer(vector_ds, isolines_layername_ptr, source_srs, wkbLineString, NULL)

    cdef OGRFieldDefnH hFld = OGR_Fld_Create("ID", OFTInteger)
    OGR_Fld_SetWidth(hFld, 8)
    OGR_L_CreateField(vector_layer, hFld, <int> 0)
    OGR_Fld_Destroy(hFld)

    cdef int idx_id_field = <int> -1
    cdef int idx_elev_field = <int> -1

    if elevation_field is not None:
        create_elev_attrib(elev_attrib_name, vector_layer)
        idx_id_field = OGR_FD_GetFieldIndex(OGR_L_GetLayerDefn(vector_layer), "ID")
        idx_elev_field = OGR_FD_GetFieldIndex(OGR_L_GetLayerDefn(vector_layer), elev_attrib_name)
        print(idx_id_field, idx_elev_field)


    cdef CSLConstList contour_generate_options = create_contour_generate_options(elevation_interval, elevation_base,
                                                               elevation_exp_base, fixed_levels,
                                                               nodata, idx_id_field, idx_elev_field, polygonize)


    try:
        exc_wrap_int(GDALContourGenerateEx(dem_band, vector_layer, contour_generate_options, NULL, NULL))
    finally:
        GDALClose(source_raster_dataset)
        GDALClose(vector_layer)
        CSLDestroy(contour_generate_options)
        GDALDestroyDriverManager()
        OGRCleanupAll()

        return output_vector_filename

