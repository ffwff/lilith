#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>
#include <syscalls.h>
#include <dirent.h>

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
  char path[128];
  struct dirent *files;
  int nfiles;

  int needs_redraw;
  int selected_idx;
};

static struct dirent up_dir = {
  .d_name = ".."
};

static void fm_init(struct fm_state *state) {
  getcwd(state->path, sizeof(state->path));
  state->needs_redraw = 1;
  state->selected_idx = 0;

  DIR *d = opendir(state->path);
  if(state->files)
    free(state->files);
  state->files = malloc(sizeof(struct dirent));
  state->files[0] = up_dir;
  state->nfiles = 1;
  struct dirent *dir;
  while ((dir = readdir(d)) != NULL) {
    int idx = state->nfiles++;
    state->files = realloc(state->files, sizeof(struct dirent) * state->nfiles);
    state->files[idx] = *dir;
  }
  closedir(d);
}

static int fm_redraw(struct g_widget *widget, struct g_application *app) {
  struct fm_state *state = g_application_userdata(app);
  if(state->needs_redraw) {
    struct g_canvas *canvas = (struct g_canvas *)widget;
    struct canvas_ctx *ctx = g_canvas_ctx(canvas);
    
    canvas_ctx_fill_rect(ctx, 0, 0,
      g_widget_width(widget), g_widget_height(widget),
      canvas_color_rgb(0x0, 0x0, 0x0));
      
    canvas_ctx_fill_rect(ctx,
      0, state->selected_idx * FONT_HEIGHT,
      g_widget_width(widget), FONT_HEIGHT,
      canvas_color_rgb(0x0, 0x0, 0xff));
    
    for(int i = 0; i < state->nfiles; i++) {
      canvas_ctx_draw_text(ctx, 0, i * FONT_HEIGHT, state->files[i].d_name);
    }

    return 1;
  }
  
  return 0;
}

static void fm_mouse(struct g_widget *widget, int type,
                     unsigned int x, unsigned int y,
                     int delta_x, int delta_y) {
  struct g_canvas *canvas = (struct g_canvas *)widget;
  struct fm_state *state = g_canvas_userdata(canvas);
  int idx = y / FONT_HEIGHT;
  if (idx < state->nfiles) {
    state->selected_idx = idx;
    if(type == WM_MOUSE_PRESS) {
      chdir(state->files[idx].d_name);
      fm_init(state);
    }
  }
}

static int address_redraw(struct g_widget *widget, struct g_application *app) {
  struct fm_state *state = g_application_userdata(app);
  if(state->needs_redraw) {
    struct g_canvas *canvas = (struct g_canvas *)widget;
    struct canvas_ctx *ctx = g_canvas_ctx(canvas);

    canvas_ctx_fill_rect(ctx, 0, 0,
      g_widget_width(widget), g_widget_height(widget),
      canvas_color_rgb(0x0, 0x0, 0x0));
    
    canvas_ctx_draw_text(ctx, 0, 0, state->path);

    g_widget_set_needs_redraw(widget, 0);
    return 1;
  }

  return 0;
}

int main(int argc, char **argv) {
  struct fm_state state = { 0 };
  fm_init(&state);

  struct g_application *app = g_application_create(INIT_WIDTH, INIT_HEIGHT, 1);
  g_application_set_userdata(app, &state);
  
  struct g_canvas *address_widget = g_canvas_create();
  g_widget_resize((struct g_widget *)address_widget, INIT_WIDTH - 10, 15);
  g_canvas_set_redraw_fn(address_widget, address_redraw);
  
  struct g_canvas *main_widget = g_canvas_create();
  g_canvas_set_userdata(main_widget, &state);
  g_canvas_set_redraw_fn(main_widget, fm_redraw);
  g_canvas_set_on_mouse_fn(main_widget, fm_mouse);

  struct g_window_layout *wlayout = g_window_layout_create((struct g_widget *)main_widget);
  g_widget_move_resize((struct g_widget *)wlayout, 0, 0, INIT_WIDTH, INIT_HEIGHT);
  g_decoration_set_widget(g_window_layout_decoration(wlayout), (struct g_widget *)address_widget);
  g_decoration_set_text(g_window_layout_decoration(wlayout), "File Manager");
  g_widget_move_resize((struct g_widget *)wlayout, 0, 0, INIT_WIDTH, INIT_HEIGHT);
  g_application_set_main_widget(app, (struct g_widget *)wlayout);

  return g_application_run(app);
}
