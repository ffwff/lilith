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
    
    struct g_termbox *tb = g_termbox_create();
    g_termbox_bind_in_fd(tb, state.in_fd);
    g_termbox_bind_out_fd(tb, state.out_fd);
    
    struct g_window_layout *wlayout = g_window_layout_create((struct g_widget *)tb);
    g_widget_move_resize((struct g_widget *)wlayout, 0, 0, INIT_WIDTH, INIT_HEIGHT);
    g_decoration_set_text(g_window_layout_decoration(wlayout), "Terminal");
    g_application_add_widget(app, (struct g_widget *)wlayout);

    return g_application_run(app);
}
