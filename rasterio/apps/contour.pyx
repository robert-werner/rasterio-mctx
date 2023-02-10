from rasterio.apps._contour cimport GDALContourGenerateEx

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

cpdef build_contour(src_raster_ds, output_vector_ds,
                    src_band=1,
                    elev_interval=10.0,
                    elev_base=0,
                    elev_exp_base=0,
                    fixed_levels=None,
                    nodata=None,
                    id_field=None,
                    elev_field='ELEV',
                    polygonize=False,
                    vector_driver_name='GPKG'):
    OGRRegisterAll()

    cdef GDALDatasetH h_src_ds = NULL
    src_raster_ds_enc = src_raster_ds.encode('utf-8')

    h_src_ds = GDALOpen(src_raster_ds_enc, GA_ReadOnly)

    cdef OGRSpatialReferenceH src_srs = NULL
    src_srs = GDALGetSpatialRef(h_src_ds)

    cdef GDALRasterBandH dem_band = NULL
    cdef int src_band_int = <int> 1
    src_band_int = <int> src_band
    dem_band = GDALGetRasterBand(h_src_ds, src_band_int)

    cdef OGRSFDriverH vector_driver = NULL
    vector_driver_name_enc = vector_driver_name.encode('utf-8')
    cdef char* vector_driver_name_ptr = NULL
    vector_driver_name_ptr = vector_driver_name_enc
    vector_driver = OGRGetDriverByName(vector_driver_name_ptr)

    cdef OGRDataSourceH vector_ds = NULL
    cdef OGRLayerH vector_layer = NULL
    cdef OGRFieldDefnH vector_layer_field = NULL

    cdef int idx_id_field = <int> -1
    cdef int idx_elev_field = <int> -1

    cdef char* isolines_layername_ptr = NULL
    isolines_layername = 'ISOLINES'.encode('utf-8')
    isolines_layername_ptr = isolines_layername

    cdef char* elev_attrib_name = NULL
    elev_field_enc = elev_field.encode('utf-8')
    elev_attrib_name = elev_field_enc

    cdef char* output_vector_ds_name = NULL
    output_vector_ds_enc = output_vector_ds.encode('utf-8')
    output_vector_ds_name = output_vector_ds_enc

    vector_ds = OGR_Dr_CreateDataSource(vector_driver, output_vector_ds_name, NULL)
    if polygonize is True:
        vector_layer = OGR_DS_CreateLayer(vector_ds, isolines_layername_ptr, src_srs, wkbMultiPolygon, NULL)
    elif polygonize is False:
        vector_layer = OGR_DS_CreateLayer(vector_ds, isolines_layername_ptr, src_srs, wkbLineString, NULL)
    cdef OGRFieldDefnH hFld = OGR_Fld_Create("ID", OFTInteger)
    OGR_Fld_SetWidth(hFld, 8)
    OGR_L_CreateField(vector_layer, hFld, <int>0)
    OGR_Fld_Destroy(hFld)
    if elev_field is not None:
        create_elev_attrib(elev_attrib_name, vector_layer)
        idx_id_field = OGR_FD_GetFieldIndex(OGR_L_GetLayerDefn(vector_layer), "ID")
        idx_elev_field = OGR_FD_GetFieldIndex(OGR_L_GetLayerDefn(vector_layer), elev_attrib_name)
        print(idx_id_field, idx_elev_field)


    cdef CSLConstList contour_generate_options = NULL
    contour_generate_options = create_contour_generate_options(elev_interval, elev_base,
                                                               elev_exp_base, fixed_levels,
                                                               nodata, idx_id_field, idx_elev_field, polygonize)

    with nogil:
        GDALContourGenerateEx(dem_band, vector_layer, contour_generate_options, NULL, NULL)