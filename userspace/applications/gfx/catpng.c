#include <stdlib.h>
#include <syscalls.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <png.h>

int main(int argc, char **argv) {
  if (argc < 2) {
    printf("usage: %s filename\n", argv[0]);
    return 1;
  }
  
  png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, 0, 0);
  png_infop info_ptr = png_create_info_struct(png_ptr);
  
  FILE *fp = fopen(argv[1], "r");
  if(!fp) return 1;
  
  png_init_io(png_ptr, fp);
  png_read_info(png_ptr, info_ptr);

  int width = png_get_image_width(png_ptr, info_ptr);
  int height = png_get_image_height(png_ptr, info_ptr);
  png_byte color_type = png_get_color_type(png_ptr, info_ptr);
  png_byte bit_depth = png_get_bit_depth(png_ptr, info_ptr);
  
  // Read any color_type into 8bit depth, RGBA format.
  // See http://www.libpng.org/pub/png/libpng-manual.txt

  if(bit_depth == 16)
    png_set_strip_16(png_ptr);

  if(color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_palette_to_rgb(png_ptr);

  // PNG_COLOR_TYPE_GRAY_ALPHA is always 8 or 16bit depth.
  if(color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
    png_set_expand_gray_1_2_4_to_8(png_ptr);

  if(png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
    png_set_tRNS_to_alpha(png_ptr);

  // These color_type don't have an alpha channel then fill it with 0xff.
  if(color_type == PNG_COLOR_TYPE_RGB ||
     color_type == PNG_COLOR_TYPE_GRAY ||
     color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_filler(png_ptr, 0x0, PNG_FILLER_AFTER);

  if(color_type == PNG_COLOR_TYPE_GRAY ||
     color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
    png_set_gray_to_rgb(png_ptr);

  png_read_update_info(png_ptr, info_ptr);

  // png_bytep *row_pointers = (png_bytep*)malloc(sizeof(png_bytep) * height);
  png_byte *image = malloc(width * height * 4);
  for(int y = 0; y < height; y++) {
    png_read_row(png_ptr, &image[y * width * 4], 0);
  }

  int fd = open("/fb0", O_RDWR);
  struct fbdev_bitblit bitblit = {
    .target_buffer = GFX_FRONT_BUFFER,
    .source = (unsigned long*)image,
    .x = 0,
    .y = 0,
    .width = width,
    .height = height,
    .type = GFX_BITBLIT_SURFACE
  };
  ioctl(fd, GFX_BITBLIT, &bitblit);

  fclose(fp);
  png_destroy_read_struct(&png_ptr, &info_ptr, 0);
  return 0;
}
