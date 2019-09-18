#pragma once

extern char font8x8_basic[128][8];

#define FONT_WIDTH 8
#define FONT_HEIGHT 8

void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, const char ch);
void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, const char *s);
