#ifndef CTIFF_h
#define CTIFF_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

// Opaque handle
typedef struct tiff TIFF;

// Memory source open ("r"). The data buffer must stay valid until close.
TIFF* ctiff_open_read(const unsigned char* data, size_t size);

// Memory sink open ("w"). The sink is released with ctiff_sink_finish.
TIFF* ctiff_open_write(void** sink_out);

// Finish writing: returns the malloc'ed buffer (caller frees with
// ctiff_free) and its size; NULL on sink failure.
unsigned char* ctiff_sink_finish(void** sink_out, size_t* size_out);

// Close. Returns 1 when an error was captured during the session (which
// may indicate a failed write), 0 otherwise.
int ctiff_close_check_error(TIFF* tif);

void ctiff_free(void* buffer);

// Error state (captured per handle by the shim's handlers)
int ctiff_has_error(TIFF* tif);
void ctiff_clear_error(TIFF* tif);
const char* ctiff_last_error(TIFF* tif);

const char* ctiff_version_string(void);

// Field access. Scalar tags return 1 when present. GeoTIFF array tags
// return 1 and point into libtiff-owned memory valid until close.
uint32_t ctiff_image_width(TIFF* tif);
uint32_t ctiff_image_height(TIFF* tif);

int ctiff_get_scalar(TIFF* tif, uint32_t tag, uint32_t* value);
int ctiff_get_scalar_defaulted(TIFF* tif, uint32_t tag, uint32_t* value);
int ctiff_get_short_scalar(TIFF* tif, uint32_t tag, uint16_t* value);
int ctiff_get_short_scalar_defaulted(TIFF* tif, uint32_t tag, uint16_t* value);
int ctiff_get_double_array(TIFF* tif, uint32_t tag, double** value, uint32_t* count);
int ctiff_get_short_array(TIFF* tif, uint32_t tag, uint16_t** value, uint32_t* count);
int ctiff_get_ascii(TIFF* tif, uint32_t tag, char** value);
int ctiff_get_extrasamples(TIFF* tif, uint16_t** value, uint16_t* count);
int ctiff_get_color_map(TIFF* tif, uint16_t** red, uint16_t** green, uint16_t** blue);

int ctiff_set_scalar(TIFF* tif, uint32_t tag, uint32_t value);
int ctiff_set_short_scalar(TIFF* tif, uint32_t tag, uint16_t value);
int ctiff_set_ascii(TIFF* tif, uint32_t tag, const char* value);
int ctiff_set_double_array(TIFF* tif, uint32_t tag, const double* values, uint32_t count);
int ctiff_set_short_array(TIFF* tif, uint32_t tag, const uint16_t* values, uint32_t count);
int ctiff_set_extrasamples(TIFF* tif, uint16_t value);
// Layout queries
int ctiff_is_tiled(TIFF* tif);
uint32_t ctiff_number_of_strips(TIFF* tif);
uint32_t ctiff_number_of_tiles(TIFF* tif);
int64_t ctiff_strip_size(TIFF* tif);
int64_t ctiff_tile_size(TIFF* tif);
int64_t ctiff_scanline_size(TIFF* tif);
uint32_t ctiff_rows_per_strip(TIFF* tif);
uint32_t ctiff_tile_width(TIFF* tif);
uint32_t ctiff_tile_height(TIFF* tif);
uint16_t ctiff_current_directory(TIFF* tif);
int ctiff_next_directory(TIFF* tif);

// Strip/tile decoding
int64_t ctiff_read_encoded_strip(TIFF* tif, uint32_t strip, void* buffer, int64_t size);
int64_t ctiff_read_encoded_tile(TIFF* tif, uint32_t tile, void* buffer, int64_t size);

// Strip-based encoding
int ctiff_write_encoded_strip(TIFF* tif, uint32_t strip, void* buffer, int64_t size);

#ifdef __cplusplus
}
#endif

#endif /* CTIFF_h */
