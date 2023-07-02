include "rasterio/gdal.pxi"

from libc.stdlib cimport  malloc

from rasterio._err cimport exc_wrap_pointer

cpdef bounds(source_filename, x_flip=False):
    GDALAllRegister()

    cdef GDALDatasetH source_dataset = exc_wrap_pointer(GDALOpen(source_filename.encode('utf-8'), GA_ReadOnly))
    cdef int source_x_size = GDALGetRasterXSize(source_dataset)
    cdef int source_y_size = GDALGetRasterYSize(source_dataset)

    cdef double[2] upper_left = point_to_coord(source_dataset, 0.0, 0.0, x_flip)
    cdef double[2] lower_left = point_to_coord(source_dataset, 0.0, source_y_size, x_flip)
    cdef double[2] upper_right = point_to_coord(source_dataset, source_x_size, 0.0, x_flip)
    cdef double[2] lower_right = point_to_coord(source_dataset, source_x_size, source_y_size, x_flip)

    try:
        return upper_left, lower_left, upper_right, lower_right
    finally:
        GDALClose(source_dataset)
        GDALDestroyDriverManager()

def extent(source_filename, x_flip):
    source_dataset_bounds = bounds(source_filename, x_flip)
    extent = [*source_dataset_bounds[1], *source_dataset_bounds[2]]
    return extent

cdef double* point_to_coord(GDALDatasetH source_dataset, double x, double y, bint x_flip):

    cdef double* geo_xy
    geo_xy = <double*> malloc(2 * sizeof(double))
    cdef double geo_transform[6]
    geo_transform = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    if (GDALGetGeoTransform(source_dataset, geo_transform) == CE_None):
        shift_operand = (geo_transform[1] * x) + (geo_transform[2] * y)
        if x_flip == 1:
            if shift_operand == 360:
                geo_xy[0] = geo_transform[0] * (-1)
            else:
                geo_xy[0] = geo_transform[0] + shift_operand
        elif x_flip == 0:
            geo_xy[0] = geo_transform[0] + shift_operand
        geo_xy[1] = geo_transform[3] + (geo_transform[4] * x) + (geo_transform[5] * y)
    else:
        geo_xy[0] = x
        geo_xy[1] = y

    return geo_xy