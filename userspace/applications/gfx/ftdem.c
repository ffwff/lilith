#include <ft2build.h>
#include FT_FREETYPE_H

int main(int argc, char **argv) {
  FT_Library library;
  FT_Error err;
  err = FT_Init_FreeType(&library);
  printf("%d\n", err);
  
  FT_Face face;
  err = FT_New_Face(library,
                    "/hd0/share/fonts/arial.ttf",
                    0, &face );
  printf("%d\n", err);
}
