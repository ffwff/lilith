#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>
#include <string.h>

#include "gui.h"
#include "priv/gwidget-impl.h"

#define LINE_BUFFER_LEN 128

struct g_termbox_data {
  int cx, cy; // character placement position
  int cwidth, cheight; // size in number of characters

  char *buffer;
  size_t buffer_len;

  int in_fd, out_fd;

  char line_buffer[LINE_BUFFER_LEN];
  size_t line_buffer_len;
};

static void g_termbox_deinit(struct g_widget *widget) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  if(data->buffer) {
    free(data);
  }
  if(data->in_fd > 0) {
    close(data->in_fd);
  }
  if(data->out_fd > 0) {
    close(data->in_fd);
  }
  free(widget->widget_data);
}

static void g_termbox_resize(struct g_widget *widget, int w, int h) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  data->cwidth = w / FONT_WIDTH;
  data->cheight = h / FONT_HEIGHT;
  size_t new_len = data->cwidth * data->cheight;
  if(new_len != data->buffer_len) {
    data->buffer = realloc(data->buffer, new_len);
    if(new_len > data->buffer_len) {
      memset(data->buffer + data->buffer_len, 0, new_len - data->buffer_len);
    }
    data->buffer_len = new_len;
  }
  widget->needs_redraw = 1;
}

static void g_termbox_newline(struct g_widget *widget) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  data->cx = 0;
  if(data->cy == data->cheight - 1) {
    // scroll
    for(int y = 0; y < data->cheight - 1; y++) {
      for(int x = 0; x < data->cwidth; x++) {
        data->buffer[y * data->cwidth + x]
                = data->buffer[(y + 1) * data->cwidth + x];
      }
    }
    for(int x = 0; x < data->cwidth; x++) {
      data->buffer[(data->cheight - 1) * data->cwidth + x] = 0;
    }
  } else {
    data->cy++;
  }
}

static void g_termbox_advance(struct g_widget *widget) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  data->cx++;
  if(data->cx == data->cwidth) {
    g_termbox_newline(widget);
  }
}

static void g_termbox_add_character(struct g_widget *widget, char ch) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  if(ch == '\b') {
    if(data->cx > 0) {
      data->buffer[data->cy * data->cwidth + data->cx] = 0;
      canvas_ctx_fill_rect(widget->ctx,
        data->cx * FONT_WIDTH,
        data->cy * FONT_HEIGHT,
        FONT_WIDTH, FONT_HEIGHT,
        canvas_color_rgb(0, 0, 0));
      data->cx--;
    }
  } else if(ch == '\n') {
    g_termbox_newline(widget);
  } else {
    data->buffer[data->cy * data->cwidth + data->cx] = ch;
    canvas_ctx_draw_character(widget->ctx,
            data->cx * FONT_WIDTH,
            data->cy * FONT_HEIGHT,
            ch);
    g_termbox_advance(widget);
  }
}

static void g_termbox_type(struct g_widget *widget, int ch) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  if(ch == '\b') {
    if(data->line_buffer_len > 0) {
      g_termbox_add_character(widget, ch);
      data->line_buffer[data->line_buffer_len--] = 0;
    }
  } else if(ch == '\n' || data->line_buffer_len == LINE_BUFFER_LEN - 2) {
    g_termbox_add_character(widget, ch);
    data->line_buffer[data->line_buffer_len++] = '\n';
    write(data->in_fd, data->line_buffer, data->line_buffer_len);
    data->line_buffer_len = 0;
  } else {
    g_termbox_add_character(widget, ch);
    data->line_buffer[data->line_buffer_len++] = ch;
  }
}

static int g_termbox_read_buf(struct g_widget *widget) {
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  char buf[4096];
  int retval = read(data->out_fd, buf, sizeof(buf));
  if(retval <= 0) return retval;
  widget->needs_redraw = 1;
  for(int i = 0; i < retval; i++) {
    g_termbox_add_character(widget, buf[i]);
  }
  return retval;
}

static int g_termbox_redraw(struct g_widget *widget) {
  g_widget_init_ctx(widget);

  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  if(data->out_fd != -1) {
    g_termbox_read_buf(widget);
  }

  if(!widget->needs_redraw)
    return 0;

  canvas_ctx_fill_rect(widget->ctx, 0, 0,
        widget->width, widget->height,
        canvas_color_rgb(0, 0, 0));

  for(int y = 0; y < data->cheight; y++) {
    for(int x = 0; x < data->cwidth; x++) {
      canvas_ctx_draw_character(widget->ctx,
        x * FONT_WIDTH, y * FONT_HEIGHT,
        data->buffer[y * data->cwidth + x]);
    }
  }
  
  widget->needs_redraw = 0;
  return 1;
}

static void g_termbox_on_key(struct g_widget *widget, int ch) {
  widget->needs_redraw = 1;
  g_termbox_type(widget, ch);
}

struct g_termbox *g_termbox_create() {
  struct g_widget *termbox = calloc(1, sizeof(struct g_widget));
  if(!termbox) return 0;

  struct g_termbox_data *data = calloc(1, sizeof(struct g_termbox_data));
  if(!data) return 0;
  data->in_fd = -1;
  data->out_fd = -1;
  
  termbox->widget_data = data;
  termbox->needs_redraw = 1;
  termbox->deinit_fn = g_termbox_deinit;
  termbox->resize_fn = g_termbox_resize;
  termbox->redraw_fn = g_termbox_redraw;
  termbox->on_key_fn = g_termbox_on_key;
  return (struct g_termbox *)termbox;
}

// getters

int g_termbox_in_fd(struct g_termbox *tb) {
  struct g_widget *widget = (struct g_widget *)tb;
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  return data->in_fd;
}

int g_termbox_out_fd(struct g_termbox *tb) {
  struct g_widget *widget = (struct g_widget *)tb;
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  return data->out_fd;
}

// setters

void g_termbox_bind_in_fd(struct g_termbox *tb, int in_fd) {
  struct g_widget *widget = (struct g_widget *)tb;
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  data->in_fd = in_fd;
}

void g_termbox_bind_out_fd(struct g_termbox *tb, int out_fd) {
  struct g_widget *widget = (struct g_widget *)tb;
  struct g_termbox_data *data = (struct g_termbox_data *)widget->widget_data;
  data->out_fd = out_fd;
}
