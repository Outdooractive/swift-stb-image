#ifndef CSTB_h
#define CSTB_h

#ifdef __cplusplus
extern "C" {
#endif

    // Reading

    unsigned char* load_image_from_memory(const unsigned char* buffer, int len, int* width, int* height, int* channels, int desired_channels);
    void free_image(void* pixels);

    // Writing

    typedef void write_func(void *context, void *data, int size);

    int write_image_png_to_func(write_func* func, void* context, int width, int height, int bpp, const void* data, int compression_level);

    int write_image_jpg_to_func(write_func *func, void *context, int width, int height, int comp, const void *data, int quality);

#ifdef __cplusplus
}
#endif

#endif /* CSTB_h */
