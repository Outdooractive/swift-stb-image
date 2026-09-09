#include "cstb.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

// Reading

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#include "stb_image.h"

// Writing (only JPG is used from stb_image_write, PNG is written below
// with zlib and adaptive per-row filtering for better compression ratios)

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_WRITE_STATIC
#include "stb_image_write.h"

unsigned char* load_image_from_memory(
    const unsigned char* buffer,
    int len,
    int* width,
    int* height,
    int* channels,
    int desired_channels
) {
    stbi_uc* pixels = stbi_load_from_memory(buffer, len, width, height, channels, desired_channels);
    return pixels;
}

void free_image(void* pixels){
    stbi_image_free(pixels);
}

// Writing

int write_image_jpg_to_func(
    write_func *func,
    void *context,
    int width,
    int height,
    int bpp,
    const void *data,
    int quality
) {
    return stbi_write_jpg_to_func(func, context, width, height, bpp, data, quality);
}

// PNG writing with adaptive per-row filtering and zlib deflate.
//
// Each row is filtered with all 5 PNG filter types (None, Sub, Up, Average,
// Paeth), scored with the standard sum-of-absolute-signed-bytes heuristic,
// and the best candidate is written. The filtered stream is deflated with
// zlib and emitted as a series of IDAT chunks through the callback.

#define PNG_CHUNK_SIZE (128 * 1024)

typedef struct png_writer_state {
    write_func* func;
    void* context;
    unsigned char* chunk_buffer;
    size_t chunk_fill;
    int failed;
} png_writer_state;

static void png_emit(
    png_writer_state* state,
    const void* data,
    size_t size
) {
    if (state->failed || size <= 0) return;
    state->func(state->context, (void*)data, (int)size);
}

static void png_write_chunk(
    png_writer_state* state,
    const char* type,
    const unsigned char* data,
    size_t size
) {
    if (state->failed) return;

    unsigned long crc = crc32(0L, (const Bytef*)type, 4);
    if (size > 0) {
        crc = crc32(crc, data, (unsigned int)size);
    }

    unsigned char header[8];
    header[0] = (unsigned char)((size >> 24) & 0xFF);
    header[1] = (unsigned char)((size >> 16) & 0xFF);
    header[2] = (unsigned char)((size >> 8) & 0xFF);
    header[3] = (unsigned char)(size & 0xFF);
    memcpy(header + 4, type, 4);

    unsigned char crc_bytes[4];
    crc_bytes[0] = (unsigned char)((crc >> 24) & 0xFF);
    crc_bytes[1] = (unsigned char)((crc >> 16) & 0xFF);
    crc_bytes[2] = (unsigned char)((crc >> 8) & 0xFF);
    crc_bytes[3] = (unsigned char)(crc & 0xFF);

    png_emit(state, header, sizeof(header));
    if (size > 0) {
        png_emit(state, data, size);
    }
    png_emit(state, crc_bytes, sizeof(crc_bytes));
}

static void png_flush_idat(png_writer_state* state) {
    if (state->failed || state->chunk_fill == 0) return;
    png_write_chunk(state, "IDAT", state->chunk_buffer, state->chunk_fill);
    state->chunk_fill = 0;
}

// Appends deflate output to the IDAT chunk buffer, flushing full chunks.
static int png_push_deflate_output(
    png_writer_state* state,
    z_stream* stream
) {
    while (stream->avail_out == 0) {
        state->chunk_fill = PNG_CHUNK_SIZE;
        png_flush_idat(state);
        stream->next_out = state->chunk_buffer;
        stream->avail_out = PNG_CHUNK_SIZE;
        if (state->failed) return 0;
    }
    return 1;
}

static int png_write_chunk_header(
    png_writer_state* state,
    unsigned char* ihdr
) {
    // PNG signature
    unsigned char signature[8] = { 137, 80, 78, 71, 13, 10, 26, 10 };
    png_emit(state, signature, sizeof(signature));

    // IHDR: width, height, bit depth 8, color type, compression 0,
    // filter method 0, no interlace
    png_write_chunk(state, "IHDR", ihdr, 13);

    return state->failed ? 0 : 1;
}

static unsigned char png_paeth_predictor(
    int a,
    int b,
    int c
) {
    int p = a + b - c;
    int pa = abs(p - a);
    int pb = abs(p - b);
    int pc = abs(p - c);

    if (pa <= pb && pa <= pc) return (unsigned char)a;
    if (pb <= pc) return (unsigned char)b;
    return (unsigned char)c;
}

// Filters one row with the given filter type and returns the score
// (sum of absolute values of the filtered bytes, interpreted as signed).
static int png_filter_row(
    unsigned char* out,
    const unsigned char* current,
    const unsigned char* previous,
    int row_bytes,
    int bpp,
    int filter_type
) {
    int score = 0;

    for (int i = 0; i < row_bytes; i++) {
        int left = (i >= bpp) ? current[i - bpp] : 0;
        int up = previous[i];
        int upper_left = (i >= bpp) ? previous[i - bpp] : 0;
        int value = current[i];
        int filtered;

        switch (filter_type) {
        case 1: // Sub
            filtered = value - left;
            break;
        case 2: // Up
            filtered = value - up;
            break;
        case 3: // Average
            filtered = value - ((left + up) >> 1);
            break;
        case 4: // Paeth
            filtered = value - png_paeth_predictor(left, up, upper_left);
            break;
        default: // None
            filtered = value;
            break;
        }

        out[i] = (unsigned char)(filtered & 0xFF);
        score += abs((signed char)out[i]);
    }

    return score;
}

int write_image_png_to_func(
    write_func* func,
    void* context,
    int width,
    int height,
    int bpp,
    const void* data,
    int compression_level
) {
    if (!func || !data || width <= 0 || height <= 0 || bpp < 1 || bpp > 4) {
        return 0;
    }
    if (compression_level < 0) compression_level = 0;
    if (compression_level > 9) compression_level = 9;

    int row_bytes = width * bpp;
    int stride = row_bytes;

    // Color type: 0 = gray, 4 = gray+alpha, 2 = RGB, 6 = RGBA
    int color_type;
    switch (bpp) {
    case 1: color_type = 0; break;
    case 2: color_type = 4; break;
    case 3: color_type = 2; break;
    default: color_type = 6; break;
    }

    unsigned char ihdr[13];
    ihdr[0] = (unsigned char)((width >> 24) & 0xFF);
    ihdr[1] = (unsigned char)((width >> 16) & 0xFF);
    ihdr[2] = (unsigned char)((width >> 8) & 0xFF);
    ihdr[3] = (unsigned char)(width & 0xFF);
    ihdr[4] = (unsigned char)((height >> 24) & 0xFF);
    ihdr[5] = (unsigned char)((height >> 16) & 0xFF);
    ihdr[6] = (unsigned char)((height >> 8) & 0xFF);
    ihdr[7] = (unsigned char)(height & 0xFF);
    ihdr[8] = 8; // bit depth
    ihdr[9] = (unsigned char)color_type;
    ihdr[10] = 0; // compression method
    ihdr[11] = 0; // filter method
    ihdr[12] = 0; // interlace method

    png_writer_state state = { 0 };
    state.func = func;
    state.context = context;
    state.chunk_buffer = (unsigned char*)malloc(PNG_CHUNK_SIZE);

    unsigned char* previous_row = (unsigned char*)calloc(row_bytes, 1);
    unsigned char* best_row = (unsigned char*)malloc(row_bytes);
    unsigned char* candidate_row = (unsigned char*)malloc(row_bytes);
    unsigned char* emit_row = (unsigned char*)malloc(row_bytes + 1);

    z_stream stream = { 0 };
    int deflate_initialized = 0;
    int result = 0;

    if (!state.chunk_buffer || !previous_row || !best_row || !candidate_row || !emit_row) {
        goto cleanup;
    }

    if (deflateInit2(&stream, compression_level, Z_DEFLATED, 15, 9, Z_DEFAULT_STRATEGY) != Z_OK) {
        goto cleanup;
    }
    deflate_initialized = 1;
    stream.next_out = state.chunk_buffer;
    stream.avail_out = PNG_CHUNK_SIZE;

    if (!png_write_chunk_header(&state, ihdr)) {
        goto cleanup;
    }

    for (int y = 0; y < height && !state.failed; y++) {
        const unsigned char* current = (const unsigned char*)data + y * stride;

        int best_filter = 0;
        int best_score = 0x7FFFFFFF;
        for (int filter_type = 0; filter_type < 5; filter_type++) {
            int score = png_filter_row(
                candidate_row,
                current,
                previous_row,
                row_bytes,
                bpp,
                filter_type);
            if (score < best_score) {
                best_score = score;
                best_filter = filter_type;
                memcpy(best_row, candidate_row, row_bytes);
            }
        }

        emit_row[0] = (unsigned char)best_filter;
        memcpy(emit_row + 1, best_row, row_bytes);

        stream.next_in = emit_row;
        stream.avail_in = row_bytes + 1;
        while (stream.avail_in > 0) {
            if (deflate(&stream, Z_NO_FLUSH) != Z_OK) {
                state.failed = 1;
                break;
            }
            if (!png_push_deflate_output(&state, &stream)) {
                break;
            }
        }

        memcpy(previous_row, current, row_bytes);
    }

    if (!state.failed) {
        // Flush the remaining output
        for (;;) {
            int status = deflate(&stream, Z_FINISH);
            if (!png_push_deflate_output(&state, &stream)) {
                break;
            }
            if (status == Z_STREAM_END) {
                result = 1;
                break;
            }
            if (status != Z_OK && status != Z_BUF_ERROR) {
                break;
            }
        }
    }

    if (result) {
        state.chunk_fill = PNG_CHUNK_SIZE - stream.avail_out;
        png_flush_idat(&state);
        png_write_chunk(&state, "IEND", NULL, 0);
        result = state.failed ? 0 : 1;
    }

cleanup:
    if (deflate_initialized) {
        deflateEnd(&stream);
    }
    free(state.chunk_buffer);
    free(previous_row);
    free(best_row);
    free(candidate_row);
    free(emit_row);

    return result;
}
