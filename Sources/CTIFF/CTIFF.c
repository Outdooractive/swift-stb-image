#include "ctiff.h"

#ifdef ENABLE_TIFF

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tiffio.h>

// GeoTIFF tag IDs (not part of libtiff's tiff.h)
#define CTIFF_TAG_MODEL_PIXEL_SCALE 33550
#define CTIFF_TAG_MODEL_TIEPOINT 33922
#define CTIFF_TAG_MODEL_TRANSFORMATION 34264
#define CTIFF_TAG_GEO_KEY_DIRECTORY 34735
#define CTIFF_TAG_GEO_DOUBLE_PARAMS 34736
#define CTIFF_TAG_GEO_ASCII_PARAMS 34737

// GeoTIFF GeoKeys (IDs only; values are handled in Swift)
#define CTIFF_KEY_GT_MODEL_TYPE 1024
#define CTIFF_KEY_GT_RASTER_TYPE 1025
#define CTIFF_KEY_GEOGRAPHIC_CRS 2048
#define CTIFF_KEY_PROJECTED_CRS 3072

// Per-handle error state. Captured through TIFFOpenOptions ext handlers so
// concurrent TIFF operations are independent.

#define CTIFF_ERROR_BUFFER_SIZE 1024

typedef struct ctiff_error_state {
    char message[CTIFF_ERROR_BUFFER_SIZE];
    int active;
} ctiff_error_state;

static int ctiff_error_handler(
    TIFF* tif,
    void* user_data,
    const char* module,
    const char* format,
    va_list args)
{
    (void)tif;
    (void)module;
    ctiff_error_state* state = (ctiff_error_state*)user_data;
    if (!state) {
        return 0;
    }
    int used = snprintf(state->message, CTIFF_ERROR_BUFFER_SIZE, "libtiff: ");
    if (used < 0 || (size_t)used >= CTIFF_ERROR_BUFFER_SIZE) {
        return 0;
    }
    vsnprintf(
        state->message + used,
        CTIFF_ERROR_BUFFER_SIZE - (size_t)used,
        format,
        args);
    state->active = 1;
    return 1;
}

static int ctiff_warning_handler(
    TIFF* tif,
    void* user_data,
    const char* module,
    const char* format,
    va_list args)
{
    (void)tif;
    (void)user_data;
    (void)module;
    (void)format;
    (void)args;
    return 0;
}

static TIFFOpenOptions* ctiff_open_options(ctiff_error_state* state) {
    TIFFOpenOptions* options = TIFFOpenOptionsAlloc();
    if (!options) {
        return NULL;
    }
    TIFFOpenOptionsSetErrorHandlerExtR(options, ctiff_error_handler, state);
    TIFFOpenOptionsSetWarningHandlerExtR(options, ctiff_warning_handler, state);
    return options;
}

// Register the GeoTIFF custom tags on every TIFF open (the libgeotiff
// xtiff.c approach). Variable-length fields (-1) get proper get/set field
// types in libtiff; fixed counts would end up as TIFF_SETGET_UNDEFINED.
static void ctiff_tag_extender(TIFF* tif) {
    static const TIFFFieldInfo fields[] = {
        {CTIFF_TAG_MODEL_PIXEL_SCALE, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_DOUBLE, FIELD_CUSTOM, 1, 1, "ModelPixelScaleTag"},
        {CTIFF_TAG_MODEL_TIEPOINT, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_DOUBLE, FIELD_CUSTOM, 1, 1, "ModelTiepointTag"},
        {CTIFF_TAG_MODEL_TRANSFORMATION, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_DOUBLE, FIELD_CUSTOM, 1, 1, "ModelTransformationTag"},
        {CTIFF_TAG_GEO_KEY_DIRECTORY, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_SHORT, FIELD_CUSTOM, 1, 1, "GeoKeyDirectoryTag"},
        {CTIFF_TAG_GEO_DOUBLE_PARAMS, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_DOUBLE, FIELD_CUSTOM, 1, 1, "GeoDoubleParamsTag"},
        {CTIFF_TAG_GEO_ASCII_PARAMS, TIFF_VARIABLE2, TIFF_VARIABLE2, TIFF_ASCII, FIELD_CUSTOM, 1, 1, "GeoAsciiParamsTag"},
    };
    TIFFMergeFieldInfo(tif, fields, 6);
}

// Memory source: a read-only buffer that the TIFF is opened against.

typedef struct ctiff_source {
    ctiff_error_state error_state;
    const unsigned char* data;
    size_t size;
    size_t offset;
} ctiff_source;

static tmsize_t ctiff_read(thandle_t handle, void* buffer, tmsize_t size) {
    ctiff_source* source = (ctiff_source*)handle;
    if (source->offset >= source->size || size <= 0) {
        return 0;
    }
    size_t remaining = source->size - source->offset;
    size_t count = (size_t)size;
    if (count > remaining) {
        count = remaining;
    }
    memcpy(buffer, source->data + source->offset, count);
    source->offset += count;
    return (tmsize_t)count;
}

static tmsize_t ctiff_write(thandle_t handle, void* buffer, tmsize_t size) {
    (void)handle;
    (void)buffer;
    (void)size;
    return 0;
}

static uint64_t ctiff_seek(thandle_t handle, uint64_t offset, int whence) {
    ctiff_source* source = (ctiff_source*)handle;
    size_t new_offset;
    switch (whence) {
        case SEEK_SET:
            new_offset = (size_t)offset;
            break;
        case SEEK_CUR:
            new_offset = source->offset + (size_t)offset;
            break;
        case SEEK_END:
            new_offset = source->size + (size_t)offset;
            break;
        default:
            return (uint64_t)-1;
    }
    if (new_offset > source->size) {
        new_offset = source->size;
    }
    source->offset = new_offset;
    return (uint64_t)source->offset;
}

static int ctiff_close(thandle_t handle) {
    (void)handle;
    return 0;
}

static uint64_t ctiff_size(thandle_t handle) {
    ctiff_source* source = (ctiff_source*)handle;
    return (uint64_t)source->size;
}

static int ctiff_map(thandle_t handle, void** base, toff_t* size) {
    (void)handle;
    (void)base;
    (void)size;
    return 0;
}

static void ctiff_unmap(thandle_t handle, void* base, toff_t size) {
    (void)handle;
    (void)base;
    (void)size;
}

// Memory sink for encoding. libtiff seeks and rewrites offsets when closing
// the file, so the sink supports seeking within the written region.

typedef struct ctiff_sink {
    ctiff_error_state error_state;
    unsigned char* data;
    size_t size;
    size_t capacity;
    size_t offset;
    int failed;
} ctiff_sink;

static int ctiff_sink_reserve(ctiff_sink* sink, size_t additional) {
    if (sink->failed) {
        return 0;
    }
    size_t required = sink->size + additional;
    if (required > sink->capacity) {
        size_t new_capacity = sink->capacity ? sink->capacity : 65536;
        while (new_capacity < required) {
            if (new_capacity > SIZE_MAX / 2) {
                new_capacity = required;
                break;
            }
            new_capacity *= 2;
        }
        unsigned char* data = (unsigned char*)realloc(sink->data, new_capacity);
        if (!data) {
            sink->failed = 1;
            return 0;
        }
        sink->data = data;
        sink->capacity = new_capacity;
    }
    return 1;
}

static tmsize_t ctiff_sink_read(thandle_t handle, void* buffer, tmsize_t size) {
    ctiff_sink* sink = (ctiff_sink*)handle;
    if (sink->offset >= sink->size || size <= 0) {
        return 0;
    }
    size_t remaining = sink->size - sink->offset;
    size_t count = (size_t)size;
    if (count > remaining) {
        count = remaining;
    }
    memcpy(buffer, sink->data + sink->offset, count);
    sink->offset += count;
    return (tmsize_t)count;
}

static tmsize_t ctiff_sink_write(thandle_t handle, void* buffer, tmsize_t size) {
    ctiff_sink* sink = (ctiff_sink*)handle;
    if (size < 0) {
        return 0;
    }
    size_t count = (size_t)size;
    if (!ctiff_sink_reserve(sink, count)) {
        return 0;
    }
    memcpy(sink->data + sink->offset, buffer, count);
    sink->offset += count;
    if (sink->offset > sink->size) {
        sink->size = sink->offset;
    }
    return size;
}

static uint64_t ctiff_sink_seek(thandle_t handle, uint64_t offset, int whence) {
    ctiff_sink* sink = (ctiff_sink*)handle;
    int64_t new_offset;
    switch (whence) {
        case SEEK_SET:
            new_offset = (int64_t)offset;
            break;
        case SEEK_CUR:
            new_offset = (int64_t)sink->offset + (int64_t)offset;
            break;
        case SEEK_END:
            new_offset = (int64_t)sink->size + (int64_t)offset;
            break;
        default:
            return (uint64_t)-1;
    }
    if (new_offset < 0) {
        return (uint64_t)-1;
    }
    // Seeking beyond the written size only extends the buffer.
    if ((size_t)new_offset > sink->size) {
        if (!ctiff_sink_reserve(sink, (size_t)new_offset - sink->size)) {
            return (uint64_t)-1;
        }
        memset(sink->data + sink->size, 0, (size_t)new_offset - sink->size);
        sink->size = (size_t)new_offset;
    }
    sink->offset = (size_t)new_offset;
    return (uint64_t)sink->offset;
}

static int ctiff_sink_close(thandle_t handle) {
    (void)handle;
    return 0;
}

static uint64_t ctiff_sink_size(thandle_t handle) {
    ctiff_sink* sink = (ctiff_sink*)handle;
    return (uint64_t)sink->size;
}

// TIFFClientOpen on a memory buffer.

TIFF* ctiff_open_read(const unsigned char* data, size_t size) {
    ctiff_source* source = (ctiff_source*)calloc(1, sizeof(ctiff_source));
    if (!source) {
        return NULL;
    }
    source->data = data;
    source->size = size;
    source->offset = 0;

    TIFFSetTagExtender(ctiff_tag_extender);

    TIFFOpenOptions* options = ctiff_open_options(&source->error_state);
    if (!options) {
        free(source);
        return NULL;
    }

    TIFF* tif = TIFFClientOpenExt(
        "memory",
        "r",
        (thandle_t)source,
        ctiff_read,
        ctiff_write,
        ctiff_seek,
        ctiff_close,
        ctiff_size,
        ctiff_map,
        ctiff_unmap,
        options);
    TIFFOpenOptionsFree(options);
    if (!tif) {
        free(source);
    }
    return tif;
}

// Memory sink open for writing. "w" mode overwrites; the sink grows.

TIFF* ctiff_open_write(void** sink_out) {
    ctiff_sink* sink = (ctiff_sink*)calloc(1, sizeof(ctiff_sink));
    if (!sink) {
        return NULL;
    }

    TIFFSetTagExtender(ctiff_tag_extender);

    TIFFOpenOptions* options = ctiff_open_options(&sink->error_state);
    if (!options) {
        free(sink);
        return NULL;
    }

    TIFF* tif = TIFFClientOpenExt(
        "memory",
        "w",
        (thandle_t)sink,
        ctiff_sink_read,
        ctiff_sink_write,
        ctiff_sink_seek,
        ctiff_sink_close,
        ctiff_sink_size,
        ctiff_map,
        ctiff_unmap,
        options);
    TIFFOpenOptionsFree(options);
    if (!tif) {
        free(sink);
        return NULL;
    }
    *sink_out = sink;
    return tif;
}

// Field access (variadic TIFFGetField/TIFFSetField wrapped here so Swift
// doesn't deal with C varargs).

uint32_t ctiff_image_width(TIFF* tif) {
    uint32_t value = 0;
    return TIFFGetFieldDefaulted(tif, TIFFTAG_IMAGEWIDTH, &value) ? value : 0;
}

uint32_t ctiff_image_height(TIFF* tif) {
    uint32_t value = 0;
    return TIFFGetFieldDefaulted(tif, TIFFTAG_IMAGELENGTH, &value) ? value : 0;
}

int ctiff_get_scalar(TIFF* tif, uint32_t tag, uint32_t* value) {
    return TIFFGetField(tif, tag, value);
}

int ctiff_get_scalar_defaulted(TIFF* tif, uint32_t tag, uint32_t* value) {
    return TIFFGetFieldDefaulted(tif, tag, value);
}

int ctiff_get_short_scalar(TIFF* tif, uint32_t tag, uint16_t* value) {
    return TIFFGetField(tif, tag, value);
}

int ctiff_get_short_scalar_defaulted(TIFF* tif, uint32_t tag, uint16_t* value) {
    return TIFFGetFieldDefaulted(tif, tag, value);
}

int ctiff_get_double_array(TIFF* tif, uint32_t tag, double** value, uint32_t* count) {
    // Variable-length custom fields expect (count, value) argument order.
    return TIFFGetField(tif, tag, count, value);
}

int ctiff_get_short_array(TIFF* tif, uint32_t tag, uint16_t** value, uint32_t* count) {
    return TIFFGetField(tif, tag, count, value);
}

int ctiff_get_ascii(TIFF* tif, uint32_t tag, char** value) {
    return TIFFGetField(tif, tag, value);
}

int ctiff_get_extrasamples(TIFF* tif, uint16_t** value, uint16_t* count) {
    return TIFFGetField(tif, TIFFTAG_EXTRASAMPLES, &count, value);
}

int ctiff_get_color_map(TIFF* tif, uint16_t** red, uint16_t** green, uint16_t** blue) {
    return TIFFGetField(tif, TIFFTAG_COLORMAP, red, green, blue);
}

int ctiff_set_scalar(TIFF* tif, uint32_t tag, uint32_t value) {
    return TIFFSetField(tif, tag, value);
}

int ctiff_set_short_scalar(TIFF* tif, uint32_t tag, uint16_t value) {
    return TIFFSetField(tif, tag, value);
}

int ctiff_set_ascii(TIFF* tif, uint32_t tag, const char* value) {
    return TIFFSetField(tif, tag, value);
}

int ctiff_set_double_array(TIFF* tif, uint32_t tag, const double* values, uint32_t count) {
    return TIFFSetField(tif, tag, count, values);
}

int ctiff_set_short_array(TIFF* tif, uint32_t tag, const uint16_t* values, uint32_t count) {
    return TIFFSetField(tif, tag, count, values);
}

int ctiff_set_extrasamples(TIFF* tif, uint16_t value) {
    // EXTRASAMPLES is registered with TIFF_VARIABLE2; the count is read
    // as uint32_t.
    uint32_t count = 1;
    return TIFFSetField(tif, TIFFTAG_EXTRASAMPLES, count, &value);
}

// Layout queries

int ctiff_is_tiled(TIFF* tif) {
    return TIFFIsTiled(tif);
}

uint32_t ctiff_number_of_strips(TIFF* tif) {
    return TIFFNumberOfStrips(tif);
}

uint32_t ctiff_number_of_tiles(TIFF* tif) {
    return TIFFNumberOfTiles(tif);
}

int64_t ctiff_strip_size(TIFF* tif) {
    return (int64_t)TIFFStripSize(tif);
}

int64_t ctiff_tile_size(TIFF* tif) {
    return (int64_t)TIFFTileSize(tif);
}

int64_t ctiff_scanline_size(TIFF* tif) {
    return (int64_t)TIFFScanlineSize(tif);
}

uint32_t ctiff_rows_per_strip(TIFF* tif) {
    uint32_t value = 0;
    return TIFFGetFieldDefaulted(tif, TIFFTAG_ROWSPERSTRIP, &value) ? value : 0;
}

uint32_t ctiff_tile_width(TIFF* tif) {
    uint32_t value = 0;
    return TIFFGetField(tif, TIFFTAG_TILEWIDTH, &value) ? value : 0;
}

uint32_t ctiff_tile_height(TIFF* tif) {
    uint32_t value = 0;
    return TIFFGetField(tif, TIFFTAG_TILELENGTH, &value) ? value : 0;
}

uint16_t ctiff_current_directory(TIFF* tif) {
    return (uint16_t)TIFFCurrentDirectory(tif);
}

int ctiff_next_directory(TIFF* tif) {
    return TIFFReadDirectory(tif);
}

// Strip/tile decoding

int64_t ctiff_read_encoded_strip(TIFF* tif, uint32_t strip, void* buffer, int64_t size) {
    return (int64_t)TIFFReadEncodedStrip(tif, strip, buffer, (tmsize_t)size);
}

int64_t ctiff_read_encoded_tile(TIFF* tif, uint32_t tile, void* buffer, int64_t size) {
    return (int64_t)TIFFReadEncodedTile(tif, tile, buffer, (tmsize_t)size);
}

// Strip-based encoding

int ctiff_write_encoded_strip(TIFF* tif, uint32_t strip, void* buffer, int64_t size) {
    return TIFFWriteEncodedStrip(tif, strip, buffer, (tmsize_t)size);
}

// Finish writing, return the sink buffer (caller owns) and free the sink struct.

unsigned char* ctiff_sink_finish(void** sink_out, size_t* size_out) {
    ctiff_sink* sink = (ctiff_sink*)*sink_out;
    *sink_out = NULL;
    if (!sink) {
        *size_out = 0;
        return NULL;
    }
    if (sink->failed) {
        free(sink->data);
        free(sink);
        *size_out = 0;
        return NULL;
    }
    unsigned char* data = sink->data ? sink->data : (unsigned char*)malloc(1);
    *size_out = sink->data ? sink->size : 0;
    free(sink);
    return data;
}

void ctiff_free(void* buffer) {
    free(buffer);
}

// Close with error propagation

int ctiff_close_check_error(TIFF* tif) {
    if (!tif) {
        return 0;
    }
    ctiff_error_state* state = (ctiff_error_state*)TIFFClientdata(tif);
    int failed = state ? state->active : 0;
    TIFFClose(tif);
    return failed;
}

int ctiff_has_error(TIFF* tif) {
    if (!tif) {
        return 0;
    }
    ctiff_error_state* state = (ctiff_error_state*)TIFFClientdata(tif);
    return state ? state->active : 0;
}

void ctiff_clear_error(TIFF* tif) {
    if (!tif) {
        return;
    }
    ctiff_error_state* state = (ctiff_error_state*)TIFFClientdata(tif);
    if (state) {
        state->message[0] = '\0';
        state->active = 0;
    }
}

const char* ctiff_last_error(TIFF* tif) {
    if (!tif) {
        return "";
    }
    ctiff_error_state* state = (ctiff_error_state*)TIFFClientdata(tif);
    return state ? state->message : "";
}

const char* ctiff_version_string(void) {
    return TIFFGetVersion();
}

#endif // ENABLE_TIFF
