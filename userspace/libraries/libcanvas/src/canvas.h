#pragma once

// header
struct canvas_ctx;
#define LIBCANVAS_MALLOC(x) malloc(x)
#define LIBCANVAS_CALLOC(nmemb, sz) calloc(nmemb, sz)
#define LIBCANVAS_REALLOC(old, newsz) realloc(old, newsz)
#define LIBCANVAS_FREE(x) free(x)
#define LIBCANVAS_DEBUG(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)
#define LIBCANVAS_PREFIX(x) canvas_##x

struct canvas_color {
  unsigned char r, g, b, a;
} __attribute__((packed));

static inline struct canvas_color canvas_color_rgba(unsigned char r,
                                                    unsigned char g,
                                                    unsigned char b,
                                                    unsigned char a) {
  return (struct canvas_color){
    .r = r,
    .g = g,
    .b = b,
    .a = a,
  };
}

static inline struct canvas_color canvas_color_rgb(unsigned char r,
                                                  unsigned char g,
                                                  unsigned char b) {
  return (struct canvas_color){
    .r = r,
    .g = g,
    .b = b,
    .a = 0xff,
  };
}

typedef enum {
  // Each pixel is a 32-bit quantity with the
  // alpha, red, green, blue channels stored in the lower bits
  LIBCANVAS_FORMAT_ARGB32,
  // Each pixel is a 32-bit quantity with the
  // red, green, blue channels stored in the lower bits
  LIBCANVAS_FORMAT_RGB24,
} canvas_format;

struct canvas_ctx *LIBCANVAS_PREFIX(ctx_create)(int width, int height, canvas_format format);
void LIBCANVAS_PREFIX(ctx_destroy)(struct canvas_ctx *);
unsigned char *LIBCANVAS_PREFIX(ctx_get_surface)(struct canvas_ctx *ctx);
canvas_format LIBCANVAS_PREFIX(ctx_get_format)(struct canvas_ctx *ctx);
int LIBCANVAS_PREFIX(ctx_get_width)(struct canvas_ctx *ctx);
int LIBCANVAS_PREFIX(ctx_get_height)(struct canvas_ctx *ctx);

int LIBCANVAS_PREFIX(ctx_resize_buffer)(struct canvas_ctx *ctx, int width, int height);

// Rectangles
void LIBCANVAS_PREFIX(ctx_fill_rect)(struct canvas_ctx *ctx,
                                     int x, int y, int width, int height,
                                     struct canvas_color color);
void LIBCANVAS_PREFIX(ctx_stroke_rect)(struct canvas_ctx *ctx,
                                     int x, int y, int width, int height,
                                     struct canvas_color color);

// Lines
void LIBCANVAS_PREFIX(ctx_stroke_line)(struct canvas_ctx *ctx,
                                       int x0, int y0, int x1, int y1,
                                       struct canvas_color color);

// Circles
void LIBCANVAS_PREFIX(ctx_fill_circle)(struct canvas_ctx *ctx,
                                       int x, int y, int rad,
                                       struct canvas_color color);
void LIBCANVAS_PREFIX(ctx_stroke_circle)(struct canvas_ctx *ctx,
                                         int x, int y, int rad,
                                         struct canvas_color color);

// implementation
#ifdef LIBCANVAS_IMPLEMENTATION

#define LIBCANVAS_PRIV(x) canv_impl_##x

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* Optimized functions */

static inline void LIBCANVAS_PRIV(memset_long)(uint32_t *dst, uint32_t c, int words) {
    unsigned long d0, d1, d2;
    __asm__ __volatile__(
        "cld\nrep stosl"
        : "=&a"(d0), "=&D"(d1), "=&c"(d2)
        : "0"(c),
          "1"(dst),
          "2"(words)
        : "memory");
}


/* Core */

struct canvas_ctx {
  uint8_t *src;
  int width;
  int height;
  canvas_format format;
};

struct canvas_ctx *LIBCANVAS_PREFIX(ctx_create)(int width, int height, canvas_format format) {
  struct canvas_ctx *ctx = LIBCANVAS_MALLOC(sizeof(struct canvas_ctx));
  ctx->width = width;
  ctx->height = height;
  ctx->format = format;
  switch (format) {
    case LIBCANVAS_FORMAT_ARGB32: {
      size_t words = width * height;
      ctx->src = LIBCANVAS_MALLOC(words * sizeof(uint32_t));
      uint32_t *data = (uint32_t *)ctx->src;
      LIBCANVAS_PRIV(memset_long)(data, 0xff000000, words);
      break;
    }
    case LIBCANVAS_FORMAT_RGB24: {
      size_t bytes = width * height * sizeof(uint32_t);
      ctx->src = LIBCANVAS_MALLOC(bytes);
      memset(ctx->src, 0, bytes);
      break;
    }
    default: {
      LIBCANVAS_DEBUG("TODO: unsupported format %d\n", format);
      LIBCANVAS_FREE(ctx);
      return NULL;
    }
  }
  return ctx;
}

void LIBCANVAS_PREFIX(ctx_destroy)(struct canvas_ctx *ctx) {
  LIBCANVAS_FREE(ctx->src);
  LIBCANVAS_FREE(ctx);
}

uint8_t *LIBCANVAS_PREFIX(ctx_get_surface)(struct canvas_ctx *ctx) {
  return ctx->src;
}

canvas_format LIBCANVAS_PREFIX(ctx_get_format)(struct canvas_ctx *ctx) {
  return ctx->format;
}

int LIBCANVAS_PREFIX(ctx_get_width)(struct canvas_ctx *ctx) {
  return ctx->width;
}

int LIBCANVAS_PREFIX(ctx_get_height)(struct canvas_ctx *ctx) {
  return ctx->height;
}

int LIBCANVAS_PREFIX(ctx_resize_buffer)(struct canvas_ctx *ctx, int width, int height) {
  if(width < 0 || height < 0)
    return 1;
  ctx->width = width;
  ctx->height = height;
  switch (ctx->format) {
    case LIBCANVAS_FORMAT_ARGB32:
      // fallthrough
    case LIBCANVAS_FORMAT_RGB24: {
      size_t bytes = width * height * sizeof(uint32_t);
      ctx->src = LIBCANVAS_REALLOC(ctx->src, bytes);
      return ctx->src != NULL;
    }
    default: {
      LIBCANVAS_DEBUG("TODO: unsupported format %d\n", ctx->format);
      return 1;
    }
  }
}

/* Colors */
static inline uint32_t
LIBCANVAS_PRIV(rgba_to_word)(struct canvas_ctx *ctx,
                                     struct canvas_color color) {
  if (ctx->format == LIBCANVAS_FORMAT_ARGB32)
    return color.a << 24 | color.r << 16 | color.g << 8 | color.b;
  else
    return color.r << 16 | color.g << 8 | color.b;
}

/* Rectangles */

void LIBCANVAS_PREFIX(ctx_fill_rect)(struct canvas_ctx *ctx,
                                     int xs, int ys, int width, int height,
                                     struct canvas_color ccolor) {
  // checks
  if(xs < 0) {
    xs = 0;
    width -= xs;
  } else if(xs > ctx->width) {
    return;
  }

  if(ys < 0) {
    ys = 0;
    height -= ys;
  } else if(ys > ctx->height) {
    return;
  }

  if(xs + width > ctx->width)
    width = ctx->width - xs;
  if(ys + height > ctx->height)
    height = ctx->height - ys;

  // blit
  switch (ctx->format) {
    case LIBCANVAS_FORMAT_ARGB32:
      // fallthrough
    case LIBCANVAS_FORMAT_RGB24: {
      uint32_t color = LIBCANVAS_PRIV(rgba_to_word)(ctx, ccolor);
      uint32_t *dst = (uint32_t *)ctx->src;
      for (int y = ys; y < (ys + height); y++) {
        LIBCANVAS_PRIV(memset_long)(dst + y * ctx->width + xs, color, width);
      }
      break;
    }
    default: {
      LIBCANVAS_DEBUG("TODO: unsupported format %d\n", ctx->format);
      return;
    }
  }
}

void LIBCANVAS_PREFIX(ctx_stroke_rect)(struct canvas_ctx *ctx,
                                     int xs, int ys, int width, int height,
                                     struct canvas_color color) {
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xs, ys, width, 1, color);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xs, ys, 1, height, color);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xs, ys + height, width, 1, color);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xs + width, ys, 1, height, color);
}
/* Lines */

void LIBCANVAS_PREFIX(ctx_stroke_line)(struct canvas_ctx *ctx,
                                      int x0, int y0, int x1, int y1,
                                      struct canvas_color ccolor) {
  // TODO: checks

  if(y0 == y1) {
    if(x0 < x1) {
      LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, x0, y0, x1 - x0, 1, ccolor);
    } else {
      LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, x1, y0, x0 - x1, 1, ccolor);
    }
    return;
  } else if(x0 == x1) {
    if(y0 < y1) {
      LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, x0, y0, 1, y1 - y0, ccolor);
    } else {
      LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, x0, y1, 1, y0 - y1, ccolor);
    }
    return;
  }

  int dx = x1 - x0;
  int dy = y1 - y0;
  int D = 2 * dy - dx;
  int y = y0;

  switch (ctx->format) {
    case LIBCANVAS_FORMAT_ARGB32:
      // fallthrough
    case LIBCANVAS_FORMAT_RGB24: {
      uint32_t color = LIBCANVAS_PRIV(rgba_to_word)(ctx, ccolor);
      uint32_t *dst = (uint32_t *)ctx->src;
      for (int x = x0; x < x1; x++) {
        dst[y * ctx->width + x] = color;
        if (D > 0) {
          y++;
          D -= 2 * dx;
        }
        D += 2 * dy;
      }
      break;
    }
    default: {
      LIBCANVAS_DEBUG("TODO: unsupported format %d\n", ctx->format);
      return;
    }
  }
}

/* Circles */
static void LIBCANVAS_PRIV(stroke_circle_oct)(struct canvas_ctx *ctx,
                                              int xc, int yc, int x, int y,
                                              struct canvas_color ccolor) {
  switch (ctx->format) {
    case LIBCANVAS_FORMAT_ARGB32:
      // fallthrough
    case LIBCANVAS_FORMAT_RGB24: {
      uint32_t color = LIBCANVAS_PRIV(rgba_to_word)(ctx, ccolor);
      uint32_t *dst = (uint32_t *)ctx->src;
#define _putpixel(x, y) dst[(y) * ctx->width + (x)] = color
      _putpixel(xc + x, yc + y);
      _putpixel(xc - x, yc + y);
      _putpixel(xc + x, yc - y);
      _putpixel(xc - x, yc - y);
      _putpixel(xc + y, yc + x);
      _putpixel(xc - y, yc + x);
      _putpixel(xc + y, yc - x);
      _putpixel(xc - y, yc - x);
#undef _putpixel
      break;
    }
  }
}

static void LIBCANVAS_PRIV(fill_circle_oct)(struct canvas_ctx *ctx,
                                              int xc, int yc, int x, int y,
                                              struct canvas_color ccolor) {
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xc - x, yc + y, x * 2, 1, ccolor);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xc - x, yc - y, x * 2, 1, ccolor);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xc - y, yc + x, y * 2, 1, ccolor);
  LIBCANVAS_PREFIX(ctx_fill_rect)(ctx, xc - y, yc - x, y * 2, 1, ccolor);
}

typedef void (LIBCANVAS_PRIV(circle_oct_fn)(struct canvas_ctx *ctx,
                                            int xc, int yc, int x, int y,
                                              struct canvas_color ccolor));

static inline void LIBCANVAS_PRIV(ctx_circle_wrapper)(struct canvas_ctx *ctx,
                                          int xc, int yc, int rad,
                                          struct canvas_color ccolor,
                                          LIBCANVAS_PRIV(circle_oct_fn) oct_fn) {
  if (xc + rad > ctx->width || xc - rad < 0)
    return;
  if (yc + rad > ctx->height || yc - rad < 0)
    return;

  int x = 0, y = rad;
  int d = 3 - 2 * rad;
  oct_fn(ctx, xc, yc, x, y, ccolor);
  while (y >= x) {
    x++;
    if (d >= 0) {
      y--;
      d += 4 * (x - y) + 10;
    } else
      d += 4 * x + 6;
    oct_fn(ctx, xc, yc, x, y, ccolor);
  }
}

void LIBCANVAS_PREFIX(ctx_stroke_circle)(struct canvas_ctx *ctx,
                                         int xc, int yc, int rad,
                                         struct canvas_color color) {
  LIBCANVAS_PRIV(ctx_circle_wrapper)(ctx, xc, yc, rad, color, LIBCANVAS_PRIV(stroke_circle_oct));
}

void LIBCANVAS_PREFIX(ctx_fill_circle)(struct canvas_ctx *ctx,
                                        int xc, int yc, int rad,
                                        struct canvas_color color) {
  LIBCANVAS_PRIV(ctx_circle_wrapper)(ctx, xc, yc, rad, color, LIBCANVAS_PRIV(fill_circle_oct));
}

#endif