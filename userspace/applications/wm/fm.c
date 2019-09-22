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
#define INIT_HEIGHT 280
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

/* WINDOW DRAWING */

#define LINE_BUFFER_LEN 128

struct fm_state {
    char *path;
};

static void fm_init(struct fm_state *state) {
}

static void fm_redraw(struct g_widget *widget, struct g_application *app) {
    struct g_canvas *canvas = (struct g_canvas *)widget;
    struct canvas_ctx *ctx = g_canvas_ctx(canvas);
    
    canvas_ctx_fill_rect(ctx, 0, 0,
        g_widget_width(widget), g_widget_height(widget),
        canvas_color_rgb(0x0, 0x0, 0x0));
        
    canvas_ctx_draw_text(ctx, 0, 0, "file");
}

int main(int argc, char **argv) {
    struct fm_state state = { 0 };
    fm_init(&state);

    struct g_application *app = g_application_create(INIT_WIDTH, INIT_HEIGHT, 1);
    g_application_set_userdata(app, &state);
    
    struct g_canvas *main_widget = g_canvas_create();
    g_canvas_set_redraw_fn(main_widget, fm_redraw);

    struct g_window_layout *wlayout = g_window_layout_create((struct g_widget *)main_widget);
    g_widget_move_resize((struct g_widget *)wlayout, 0, 0, INIT_WIDTH, INIT_HEIGHT);
    g_decoration_set_text(g_window_layout_decoration(wlayout), "File Manager");
    g_application_set_main_widget(app, (struct g_widget *)wlayout);

    return g_application_run(app);
}
