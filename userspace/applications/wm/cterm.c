#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>
#include <syscalls.h>

#include <canvas.h>
#include <font8x8_basic.h>
#include <wm/wmc.h>
#include <gui.h>

#define INIT_WIDTH 400
#define INIT_HEIGHT 256
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, const char ch) {
    char *bitmap = font8x8_basic[ch];
    if(canvas_ctx_get_format(ctx) != LIBCANVAS_FORMAT_RGB24)
        return;
    unsigned long *data = (unsigned long *)canvas_ctx_get_surface(ctx);
    for (int x = 0; x < FONT_WIDTH; x++) {
        for (int y = 0; y < FONT_HEIGHT; y++) {
            if (bitmap[y] & 1 << x) {
                data[(ys + y) * canvas_ctx_get_width(ctx) + (xs + x)] = 0xffffffff;
            }
        }
    }
}

void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, const char *s) {
    int x = xs, y = ys;
    while(*s) {
        canvas_ctx_draw_character(ctx, x, y, *s);
        x += FONT_WIDTH;
        s++;
    }
}

/* WINDOW DRAWING */

#define LINE_BUFFER_LEN 128

struct cterm_state {
    int cwidth, cheight; // in number of characters
    int cx, cy;
    int root_width, root_height;
    int root_x, root_y;
    char *buffer;
    size_t buffer_len;
    int in_fd, out_fd;
    char line_buffer[LINE_BUFFER_LEN];
    size_t line_buffer_len;
};

void cterm_init(struct cterm_state *state) {
    state->cwidth = 0;
    state->cheight = 0;
    state->cx = 0;
    state->cy = 0;
    state->buffer = 0;
    state->buffer_len = 0;

    char path[128] = { 0 };

    snprintf(path, sizeof(path), "/pipes/cterm:%d:in", getpid());
    state->in_fd = create(path);
    ioctl(state->in_fd, PIPE_CONFIGURE, PIPE_WAIT_READ);

    snprintf(path, sizeof(path), "/pipes/cterm:%d:out", getpid());
    state->out_fd = create(path);
}

int cterm_app_redraw(struct g_application *app) {
    struct canvas_ctx *ctx = g_application_ctx(app);
    unsigned int width = g_application_width(app);
    unsigned int height = g_application_height(app);

    // window decorations
    canvas_ctx_fill_rect(ctx, 0, 0,
        width, height,
        canvas_color_rgb(0x32, 0x36, 0x39));
    canvas_ctx_stroke_rect(ctx, 0, 0,
        width - 1, height - 1,
        canvas_color_rgb(0x20, 0x21, 0x24));

    {
        const char *title = "Terminal";
        int x_title = (width - strlen(title) * FONT_WIDTH) / 2;
        canvas_ctx_draw_text(ctx, x_title, 10, title);
    }
    
    // calculate root
    
    return 0;
}

#if 0

void cterm_draw_buffer(struct cterm_state *state);
void cterm_draw(struct cterm_state *state) {
    // window decorations
    canvas_ctx_fill_rect(state->ctx, 0, 0,
        state->sprite.width, state->sprite.height,
        canvas_color_rgb(0x32, 0x36, 0x39));
    canvas_ctx_stroke_rect(state->ctx, 0, 0,
        state->sprite.width - 1, state->sprite.height - 1,
        canvas_color_rgb(0x20, 0x21, 0x24));

    {
        const char *title = "Terminal";
        int x_title = (state->sprite.width - strlen(title) * FONT_WIDTH) / 2;
        canvas_ctx_draw_text(state->ctx, x_title, 10, title);
    }

    // calculate root widget
    state->root_x = 1;
    state->root_y = FONT_HEIGHT + 15;
    state->root_width = state->sprite.width - state->root_x - 1;
    state->root_height = state->sprite.height - state->root_y - 1;

    // calculate characters and buffer
    state->cwidth  = state->root_width / FONT_WIDTH;
    state->cheight = state->root_height / FONT_HEIGHT;
    size_t new_len = state->cwidth * state->cheight;
    if(new_len != state->buffer_len) {
        state->buffer = realloc(state->buffer, new_len);
        if(new_len > state->buffer_len) {
            memset(state->buffer + state->buffer_len, 0, new_len - state->buffer_len);
        }
        state->buffer_len = new_len;
    }
    cterm_draw_buffer(state);
}

void cterm_draw_buffer(struct cterm_state *state) {
    canvas_ctx_fill_rect(state->ctx, state->root_x, state->root_y,
        state->root_width, state->root_height,
        canvas_color_rgb(0, 0, 0));
    for(int y = 0; y < state->cheight; y++) {
        for(int x = 0; x < state->cwidth; x++) {
            canvas_ctx_draw_character(state->ctx,
                    state->root_x + x * FONT_WIDTH, state->root_y + y * FONT_HEIGHT,
                    state->buffer[y * state->cwidth + x]);
        }
    }
}

void cterm_newline(struct cterm_state *state) {
    state->cx = 0;
    if(state->cy == state->cheight - 1) {
        // scroll
        for(int y = 0; y < state->cheight - 1; y++) {
            for(int x = 0; x < state->cwidth; x++) {
                state->buffer[y * state->cwidth + x]
                    = state->buffer[(y + 1) * state->cwidth + x];
            }
        }
        for(int x = 0; x < state->cwidth; x++) {
            state->buffer[(state->cheight - 1) * state->cwidth + x] = 0;
        }
        cterm_draw_buffer(state);
    } else {
        state->cy++;
    }
}

void cterm_advance(struct cterm_state *state) {
    state->cx++;
    if(state->cx == state->cwidth) {
        cterm_newline(state);
    }
}

void cterm_add_character(struct cterm_state *state, char ch) {
    if(ch == '\n') {
        cterm_newline(state);
    } else {
        state->buffer[state->cy * state->cwidth + state->cx] = ch;
        canvas_ctx_draw_character(state->ctx,
                state->root_x + state->cx * FONT_WIDTH,
                state->root_y + state->cy * FONT_HEIGHT,
                ch);
        cterm_advance(state);
    }
}

void cterm_type(struct cterm_state *state, char ch) {
    cterm_add_character(state, ch);
    if(ch == '\n' || state->line_buffer_len == LINE_BUFFER_LEN - 2) {
        state->line_buffer[state->line_buffer_len++] = '\n';
        write(state->in_fd, state->line_buffer, state->line_buffer_len);
        state->line_buffer_len = 0;
    } else {
        state->line_buffer[state->line_buffer_len++] = ch;
    }
}

int cterm_read_buf(struct cterm_state *state) {
    char buf[4096];
    int retval = read(state->out_fd, buf, sizeof(buf));
    if(retval <= 0) return retval;
    for(int i = 0; i < retval; i++) {
        cterm_add_character(state, buf[i]);
    }
    return retval;
}

#endif

int main(int argc, char **argv) {
    #if 0
    cterm_draw(&state);

    // spawn main
    struct startup_info s_info = {
        .stdin = state.in_fd,
        .stdout = state.out_fd,
        .stderr = state.out_fd,
    };
    char *spawn_argv[] = {"/hd0/main", NULL};
    spawnxv(&s_info, "/hd0/main", (char **)spawn_argv);
    #endif

    struct cterm_state state = { 0 };
    cterm_init(&state);

    struct g_application *app = g_application_create(INIT_WIDTH, INIT_HEIGHT);
    g_application_set_userdata(app, &state);
    g_application_set_redraw_cb(app, cterm_app_redraw);

    return g_application_run(app);
}
