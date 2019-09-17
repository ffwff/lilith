#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>
#include <syscalls.h>

#include <canvas.h>
#include <wm/wmc.h>
#include <gui.h>

#define INIT_WIDTH 400
#define INIT_HEIGHT 256
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

static void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, const char ch) {
    char *bitmap = font8x8_basic[(int)ch];
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

static void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, const char *s) {
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
    int in_fd, out_fd;
};

void cterm_init(struct cterm_state *state) {
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
    {
        const char *title = "Terminal";
        int x_title = (width - strlen(title) * FONT_WIDTH) / 2;
        canvas_ctx_draw_text(ctx, x_title, 10, title);
    }
    
    return 0;
}

int main(int argc, char **argv) {
    struct cterm_state state = { 0 };
    cterm_init(&state);

    // spawn main
    struct startup_info s_info = {
        .stdin = state.in_fd,
        .stdout = state.out_fd,
        .stderr = state.out_fd,
    };
    char *spawn_argv[] = {"/hd0/main", NULL};
    spawnxv(&s_info, "/hd0/main", (char **)spawn_argv);

    struct g_application *app = g_application_create(INIT_WIDTH, INIT_HEIGHT);
    g_application_set_userdata(app, &state);
    g_application_set_redraw_cb(app, cterm_app_redraw);
    
    struct g_decoration *dec = g_decoration_create();
    g_widget_move_resize((struct g_widget *)dec, 0, 0, INIT_WIDTH, INIT_HEIGHT);
    g_application_add_widget(app, (struct g_widget *)dec);
    
    struct g_termbox *tb = g_termbox_create();
    const int title_height = 20;
    g_widget_move_resize((struct g_widget *)tb, 0, title_height, INIT_WIDTH, INIT_HEIGHT - title_height);
    g_termbox_bind_in_fd(tb, state.in_fd);
    g_termbox_bind_out_fd(tb, state.out_fd);
    g_application_add_widget(app, (struct g_widget *)tb);

    return g_application_run(app);
}
