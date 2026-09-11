#ifndef CSTB_h
#define CSTB_h

#ifdef __cplusplus
extern "C" {
#endif

    // Reading

    unsigned char* load_image_from_memory(const unsigned char* buffer, int len, int* width, int* height, int* channels, int desired_channels);
    unsigned short* load_image_16_from_memory(const unsigned char* buffer, int len, int* width, int* height, int* channels, int desired_channels);
    int is_image_16_bit(const unsigned char* buffer, int len);
    void free_image(void* pixels);

    // Writing

    typedef void write_func(void *context, void *data, int size);

    int write_image_png_to_func(write_func* func, void* context, int width, int height, int channels, int bit_depth, const void* data, int compression_level);

    int write_image_jpg_to_func(write_func *func, void *context, int width, int height, int channels, const void *data, int quality);

#ifdef __cplusplus
}
#endif

#endif /* CSTB_h */
