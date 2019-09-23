#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/mouse.h>
#include <sys/kbd.h>
#include <syscalls.h>

#include <wm/wm.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include <stb/stb_image.h>

const int channels = 4;
#define CURSOR_FILE "/hd0/share/cursors/cursor.png"

static void filter_data(struct fbdev_bitblit *sprite) {
  unsigned char *data = (unsigned char *)sprite->source;
  for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
    unsigned char r = data[i + 0];
    unsigned char g = data[i + 1];
    unsigned char b = data[i + 2];
    data[i + 0] = b;
    data[i + 1] = g;
    data[i + 2] = r;
    data[i + 3] = 0;
  }
}

static void filter_data_with_alpha(struct fbdev_bitblit *sprite) {
  unsigned char *data = (unsigned char *)sprite->source;
  for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
    unsigned char r = data[i + 0];
    unsigned char g = data[i + 1];
    unsigned char b = data[i + 2];
    unsigned char a = data[i + 3];
    // premultiply by alpha / 0xff
    data[i + 0] = ((int)b * (int)a) / 0xff;
    data[i + 1] = ((int)g * (int)a) / 0xff;
    data[i + 2] = ((int)r * (int)a) / 0xff;
  }
}

static void panic(const char *s) {
  puts(s);
  exit(1);
}

#define min(x, y) ((x)<(y)?(x):(y))

#define FRAME_WAIT 10000
#define PACKET_TIMEOUT FRAME_WAIT*5

/* WM State */

struct wm_state;
struct wm_window;
struct wm_window_prog;
struct wm_window_sprite;

#define WM_EVENT_QUEUE_LEN 128
#define WAITFD_LEN 512

struct wm_state {
  int needs_redraw;
  int control_fd;
  int mouse_fd;
  struct wm_window *mouse_win; // weakref
  int kbd_fd;
  struct wm_atom last_mouse_atom;
  struct wm_window *windows;
  int nwindows;
  struct wm_atom queue[WM_EVENT_QUEUE_LEN];
  size_t queue_len;
  int focused_wid;
  int waitfds[WAITFD_LEN];
  size_t waitfds_len;
};

struct wm_window_prog {
  pid_t pid;
  int mfd, sfd;
  unsigned int event_mask;
  unsigned int x, y, width, height;
  int pad; // FIXME: doesn't work without this
};

struct wm_window_sprite {
  struct fbdev_bitblit sprite;
};

enum wm_window_type {
  WM_WINDOW_PROG = 0,
  WM_WINDOW_SPRITE = 1,
  WM_WINDOW_REMOVE = 2,
};

struct wm_window {
  enum wm_window_type type;
  int wid;
  union {
    struct wm_window_prog prog;
    struct wm_window_sprite sprite;
  } as;
  unsigned int z_index;
  int drawn;
};

/* IPC */

int win_write_and_wait(struct wm_window *win,
             struct wm_atom *write_atom,
             struct wm_atom *respond_atom) {
  struct wm_window_prog *prog = &win->as.prog;
  ftruncate(prog->mfd, 0);
  write(prog->mfd, (char *)write_atom, sizeof(struct wm_atom));
  if (waitfd(&prog->sfd, 1, PACKET_TIMEOUT) < 0) {
    // win->refresh_retries++;
    ftruncate(prog->sfd, 0);
    return 0;
  }
  // respond received
  return read(prog->sfd, (char *)respond_atom, sizeof(struct wm_atom));
}

void win_copy_refresh_atom(struct wm_window_prog *prog, struct wm_atom *atom) {
  prog->x = atom->win_refresh.x;
  prog->y = atom->win_refresh.y;
  prog->width = atom->win_refresh.width;
  prog->height = atom->win_refresh.height;

}

/* WINDOW */

struct wm_window *wm_add_window(struct wm_state *state) {
  state->windows = realloc(state->windows, state->nwindows + 1);
  struct wm_window *win = &state->windows[state->nwindows++];
  memset(win, 0, sizeof(struct wm_window));
  win->wid = state->nwindows;
  return win;
}

struct wm_window *wm_add_win_prog(struct wm_state *state,
                                  pid_t pid, unsigned int event_mask,
                                  struct wm_window *win) {
  char path[128] = { 0 };

  snprintf(path, sizeof(path), "/pipes/wm:%d:m", pid);
  int mfd = create(path);
  if(mfd < 0) { return 0; }

  snprintf(path, sizeof(path), "/pipes/wm:%d:s", pid);
  int sfd = create(path);
  if(sfd < 0) { close(mfd); return 0; }

  if(win == 0) {
    win = wm_add_window(state);
    win->z_index = 1;
    state->focused_wid = win->wid;
  } else {
    assert(win->type == WM_WINDOW_SPRITE);
    memset(&win->as.prog, 0, sizeof(struct wm_window_prog));
    win->drawn = 0;
  }
  win->type = WM_WINDOW_PROG;
  win->as.prog.pid = pid;
  win->as.prog.event_mask = event_mask;
  win->as.prog.mfd = mfd;
  win->as.prog.sfd = sfd;
  return win;
}

struct wm_window *wm_add_sprite(struct wm_state *state, struct wm_window_sprite *sprite) {
  struct wm_window *win = wm_add_window(state);
  win->z_index = 1;
  win->type = WM_WINDOW_SPRITE;
  win->as.sprite = *sprite;
  return win;
}

/* WINDOW REMOVE */
void wm_mark_win_removed(struct wm_window *win) {
  switch (win->type) {
    case WM_WINDOW_PROG: {
      struct wm_window_prog *prog = &win->as.prog;
      
      close(prog->mfd);
      close(prog->sfd);

      char path[128] = { 0 };

      snprintf(path, sizeof(path), "/pipes/wm:%d:m", prog->pid);
      remove(path);

      snprintf(path, sizeof(path), "/pipes/wm:%d:s", prog->pid);
      remove(path);

      break;
    }
  }
  win->type = WM_WINDOW_REMOVE;
}

/* IMPL */

int wm_sort_windows_by_z_compar(const void *av, const void *bv) {
  const struct wm_window *a = av, *b = bv;
  if (a->z_index < b->z_index) return -1;
  else if(a->z_index == b->z_index) return 0;
  return 1;
}

void wm_sort_windows_by_z(struct wm_state *state) {
  int mouse_wid = state->mouse_win->wid;

  qsort(state->windows, state->nwindows, sizeof(struct wm_window), wm_sort_windows_by_z_compar);

  for (int i = 0; i < state->nwindows; i++) {
    struct wm_window *win = &state->windows[i];
    if (win->wid == mouse_wid) {
      state->mouse_win = win;
      break;
    }
  }
}

/* QUEUE */

void wm_add_queue(struct wm_state *state, struct wm_atom *atom) {
  if(state->queue_len == WM_EVENT_QUEUE_LEN) {
    return;
  }
  state->queue[state->queue_len++] = *atom;
}

/* CONNECTIONS */

int wm_handle_connection_request(struct wm_state *state, struct wm_connection_request *conn_req) {
  struct wm_window *win = 0;
  if((conn_req->properties & WM_PROPERTY_ROOT) != 0) {
    if(state->windows[0].type == WM_WINDOW_SPRITE) {
      win = wm_add_win_prog(state, conn_req->pid, conn_req->event_mask, &state->windows[0]);
    } else {
      abort(); // TODO
      return 1;
    }
  } else {
    win = wm_add_win_prog(state, conn_req->pid, conn_req->event_mask, 0);
  }

  if(!win) {
    return 0;
  }
  wm_sort_windows_by_z(state);
  return 1;
}

void wm_build_waitfds(struct wm_state *state) {
  state->waitfds_len = 0;
  state->waitfds[state->waitfds_len++] = state->mouse_fd;
  state->waitfds[state->waitfds_len++] = state->kbd_fd;
}

/* MISC */

int point_in_win_prog(struct wm_window_prog *prog, unsigned int x, unsigned int y) {
  return prog->x <= x && x <= (prog->x + prog->width) &&
       prog->y <= y && y <= (prog->y + prog->height);
}

int main(int argc, char **argv) {
  int fb_fd = open("/fb0", O_RDWR);

  // setup
  struct winsize ws;
  ioctl(fb_fd, TIOCGWINSZ, &ws);

  struct wm_state wm = {0};
  wm.focused_wid = -1;

  // wallpaper
  {
    struct wm_window_sprite pape_spr = {
      .sprite = (struct fbdev_bitblit){
        .target_buffer = GFX_BACK_BUFFER,
        .source = (unsigned long*)0x000066cc,
        .x = 0,
        .y = 0,
        .width = ws.ws_col,
        .height = ws.ws_row,
        .type = GFX_BITBLIT_COLOR
      }
    };
    struct wm_window *win = wm_add_sprite(&wm, &pape_spr);
    win->z_index = 0;
  }

  // mouse
  {
    wm.mouse_fd = open("/mouse/raw", O_RDONLY);

    struct wm_window_sprite mouse_spr = {
      .sprite = (struct fbdev_bitblit){
        .target_buffer = GFX_BACK_BUFFER,
        .source = NULL,
        .x = 100,
        .y = 100,
        .width = 0,
        .height = 0,
        .type = GFX_BITBLIT_SURFACE_ALPHA
      }
    };
    printf("loading cursor...\n");
    int w, h, n;
    mouse_spr.sprite.source = (unsigned long *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
    if (!mouse_spr.sprite.source) panic("can't load mouse_spr");
    mouse_spr.sprite.width = w;
    mouse_spr.sprite.height = h;
    filter_data_with_alpha(&mouse_spr.sprite);

    wm.mouse_win = wm_add_sprite(&wm, &mouse_spr);
    wm.mouse_win->z_index = (unsigned int)-1;
  }

  // keyboard
  {
    wm.kbd_fd = open("/kbd/raw", O_RDONLY);
  }

  wm_sort_windows_by_z(&wm);

  // disable console
  ioctl(STDOUT_FILENO, TIOCGSTATE, 0);

  // control pipe
  wm.control_fd = create("/pipes/wm");

  wm_build_waitfds(&wm);

  wm.needs_redraw = 1;

  // sample win
  //char *spawn_argv[] = {"desktop", NULL};
  //spawnv("desktop", (char **)spawn_argv);
  char *spawn_argv[] = {"cterm", NULL};
  spawnv("cterm", (char **)spawn_argv);

  while(1) {
    {
      // control pipe
      struct wm_connection_request conn_req = { 0 };
      while(
        read(wm.control_fd, (char *)&conn_req, sizeof(struct wm_connection_request))
          == sizeof(struct wm_connection_request)
      ) {
        if (wm_handle_connection_request(&wm, &conn_req)) {
          wm.needs_redraw = 1;
        }
      }
    }
    int select_fd = waitfd(wm.waitfds, wm.waitfds_len, PACKET_TIMEOUT);
    if (select_fd == wm.mouse_fd) {
      // mouse
      struct mouse_packet mouse_packet;
      read(wm.mouse_fd, (char *)&mouse_packet, sizeof(mouse_packet));

      unsigned int speed = __builtin_ffs(mouse_packet.x + mouse_packet.y);
      struct fbdev_bitblit *sprite = &wm.mouse_win->as.sprite.sprite;

      struct wm_atom mouse_atom = { 0 };
      mouse_atom.type = ATOM_MOUSE_EVENT_TYPE;

      if (mouse_packet.x != 0) {
        // left = negative
        int delta_x = mouse_packet.x * speed;
        mouse_atom.mouse_event.delta_x = delta_x;

        if(!(delta_x < 0 && sprite->x < -delta_x)) {
          sprite->x += delta_x;
          sprite->x = min(sprite->x, ws.ws_col);
        }
        wm.needs_redraw = 1;
      }
      mouse_atom.mouse_event.x = sprite->x;

      if (mouse_packet.y != 0) {
        // bottom = negative
        int delta_y = -mouse_packet.y * speed;
        mouse_atom.mouse_event.delta_y = delta_y;

        if(!(delta_y < 0 && sprite->y < -delta_y)) {
          sprite->y += delta_y;
          sprite->y = min(sprite->y, ws.ws_row);
        }
        wm.needs_redraw = 1;
      }
      mouse_atom.mouse_event.y = sprite->y;

      if ((mouse_packet.attr_byte & MOUSE_ATTR_LEFT_BTN) != 0) {
        mouse_atom.mouse_event.type = WM_MOUSE_PRESS;
      } else {
        mouse_atom.mouse_event.type = WM_MOUSE_RELEASE;
      }

      if(!wm_atom_eq(&mouse_atom, &wm.last_mouse_atom)) {
        // focus on window
        if(mouse_atom.mouse_event.type == WM_MOUSE_PRESS) {
          int old_wid = wm.focused_wid;
          struct wm_window *focused_win = NULL;
          for(int i = wm.nwindows - 1; i >= 0; i--) {
            if (wm.windows[i].z_index > 0 && wm.windows[i].type == WM_WINDOW_PROG) {
              if(point_in_win_prog(&wm.windows[i].as.prog, sprite->x, sprite->y) && !focused_win) {
                wm.focused_wid = wm.windows[i].wid;
                focused_win = &wm.windows[i];
              }
              wm.windows[i].z_index = 1;
            }
          }
          if(old_wid != wm.focused_wid && focused_win) {
            // TODO: not hard code z_index value
            focused_win->z_index = 2;
            wm_sort_windows_by_z(&wm);
          }
        }
        wm_add_queue(&wm, &mouse_atom);
      }

      wm.last_mouse_atom = mouse_atom;
    } else if (select_fd == wm.kbd_fd) {
      // keyboard
      struct keyboard_packet keyboard_packet = { 0 };
      read(wm.kbd_fd, (char *)&keyboard_packet, sizeof(keyboard_packet));
      if(keyboard_packet.ch) {
        struct wm_atom keyboard_atom = { 0 };
        keyboard_atom.type = ATOM_KEYBOARD_EVENT_TYPE;
        keyboard_atom.keyboard_event.ch = keyboard_packet.ch;
        keyboard_atom.keyboard_event.modifiers = keyboard_packet.modifiers;
        wm_add_queue(&wm, &keyboard_atom);
      }
    }
    {
      // reset window states
      for (int i = 0; i < wm.nwindows; i++) {
        struct wm_window *win = &wm.windows[i];
        win->drawn = 0;
      }
    }
    int undrawn_windows = 0;
    for (int i = 0; i < wm.nwindows; i++) {
      struct wm_window *win = &wm.windows[i];
      switch (win->type) {
        case WM_WINDOW_PROG: {
          int retval;
          struct wm_atom respond_atom;

          // transmit events in queue
          if(wm.focused_wid == win->wid) {
            for(size_t i = 0; i < wm.queue_len; i++) {
              if((win->as.prog.event_mask & (1 << wm.queue[i].type)) != 0) {
                win_write_and_wait(win, &wm.queue[i], &respond_atom);
              }
            }
          }

          // request a redraw
          struct wm_atom redraw_atom = {
            .type = ATOM_REDRAW_TYPE,
            .redraw.force_redraw = wm.needs_redraw,
          };
          retval = win_write_and_wait(win, &redraw_atom, &respond_atom);

          if (retval == sizeof(struct wm_atom)) {
            win_copy_refresh_atom(&win->as.prog, &respond_atom);
            if (respond_atom.type == ATOM_WIN_REFRESH_TYPE) {
              if(respond_atom.win_refresh.did_redraw) {
                wm.needs_redraw = 1;
                win->drawn = 1;
                if(undrawn_windows > 0) {
                  // redraw all undrawn windows
                  struct wm_atom redraw_atom = {
                    .type = ATOM_REDRAW_TYPE,
                    .redraw.force_redraw = wm.needs_redraw,
                  };
                  for(int j = 0; j < wm.nwindows; j++) {
                    struct wm_window *win = &wm.windows[j];
                    if(!undrawn_windows || win->drawn)
                      break;
                    switch (win->type) {
                      case WM_WINDOW_PROG: {
                        retval = win_write_and_wait(win, &redraw_atom, &respond_atom);
                        if (retval == sizeof(struct wm_atom)) {
                          win_copy_refresh_atom(&win->as.prog, &respond_atom);
                        }
                        win->drawn = 1;
                        undrawn_windows--;
                        break;
                      }
                    }
                  }
                  undrawn_windows = 0;
                }
              } else {
                win->drawn = 0;
                undrawn_windows++;
              }
            } else {
              // TODO: wrong response atom
            }
          }
          break;
        }
        case WM_WINDOW_SPRITE: {
          ioctl(fb_fd, GFX_BITBLIT, &win->as.sprite.sprite);
          break;
        }
      }
    }
    if (wm.needs_redraw) {
      ioctl(fb_fd, GFX_SWAPBUF, 0);
      wm.needs_redraw = 0;
    }
    wm.queue_len = 0;
    usleep(FRAME_WAIT);
  }

  return 0;
}
