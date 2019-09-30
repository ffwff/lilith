#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <syscalls.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/mouse.h>
#include <sys/kbd.h>
#include <sys/pipes.h>

#include <wm/wm.h>

#include <x86intrin.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include <stb/stb_image.h>

const int channels = 4;
#define CURSOR_FILE "/hd0/share/cursors/cursor.png"

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
  int fb_fd;
  unsigned int *framebuffer;
  unsigned int *backbuffer;
  struct winsize ws;
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
  int window_closed;
};

#define MAX_PACKET_RETRIES 5

struct wm_window_prog {
  pid_t pid;
  unsigned int *bitmap;
  int mfd, sfd, bitmapfd;
  unsigned int event_mask;
  unsigned int x, y, width, height;
  int alpha;
  int packet_retries;
};

enum wm_sprite_type {
  WM_SPRITE_COLOR,
  WM_SPRITE_SURFACE_ALPHA,
};
struct wm_window_sprite {
  union {
    unsigned int color;
    unsigned int *buffer;
  } source;
  unsigned int x, y, width, height;
  enum wm_sprite_type type;
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
  write(prog->mfd, write_atom, sizeof(struct wm_atom));
  if (waitfd(&prog->sfd, 1, PACKET_TIMEOUT) < 0) {
    prog->packet_retries++;
    ftruncate(prog->sfd, 0);
    return 0;
  }
  prog->packet_retries = 0;
  return read(prog->sfd, respond_atom, sizeof(struct wm_atom));
}

void wm_mark_win_removed(struct wm_window *win);
void wm_handle_atom(struct wm_state *state, 
        struct wm_window *win, struct wm_atom *atom) {
  struct wm_window_prog *prog = &win->as.prog;
  switch(atom->type) {
    case ATOM_WIN_CREATE_TYPE: {
      if (prog->bitmap) return;
      struct wm_atom respond_atom;

      char path[128];
      snprintf(path, sizeof(path), "/tmp/wm:%d:bm", prog->pid);
      prog->bitmapfd = create(path);
      
      if (prog->bitmapfd < 0) {
        prog->bitmapfd = -1;
        struct wm_atom write_atom = {
          .type = ATOM_RESPOND_TYPE,
          .respond.retval = 0,
        };
        win_write_and_wait(win, &write_atom, &respond_atom);
        return;
      }

      size_t size = atom->win_create.width * atom->win_create.height * 4;
      ftruncate(prog->bitmapfd, size);
      prog->bitmap = mmap(prog->bitmapfd, (size_t)-1);
      
      struct wm_atom write_atom = {
        .type = ATOM_RESPOND_TYPE,
        .respond.retval = 1,
      };
      win_write_and_wait(win, &write_atom, &respond_atom);

      prog->x = 0;
      prog->y = 0;
      prog->width = atom->win_create.width;
      prog->height = atom->win_create.height;
      prog->alpha = atom->win_create.alpha;
      break;
    }
    case ATOM_MOVE_TYPE: {
      prog->x = atom->move.x;
      prog->y = atom->move.y;
      state->needs_redraw = 1;
      break;
    }
    case ATOM_WIN_CLOSE_TYPE: {
      wm_mark_win_removed(win);
      state->window_closed = 1;
      break;
    }
    default:
      break;
  }
}

/* WINDOW */

struct wm_window *wm_add_window(struct wm_state *state) {
  state->windows = realloc(state->windows,
    sizeof(struct wm_window) * (state->nwindows + 1));
  struct wm_window *win = &state->windows[state->nwindows];
  memset(win, 0, sizeof(struct wm_window));
  win->wid = state->nwindows++;
  return win;
}

struct wm_window *wm_add_win_prog(struct wm_state *state,
                                  pid_t pid, unsigned int event_mask,
                                  struct wm_window *win) {
  char path[128] = { 0 };

  snprintf(path, sizeof(path), "wm:%d:m", pid);
  int mfd = mkppipe(path, PIPE_S_RD | PIPE_M_WR, pid);
  if(mfd < 0) { return 0; }

  snprintf(path, sizeof(path), "wm:%d:s", pid);
  int sfd = mkppipe(path, PIPE_M_RD | PIPE_S_WR, pid);
  if(sfd < 0) { close(mfd); return 0; }
  
  snprintf(path, sizeof(path), "/tmp/wm:%d:bm", pid);
  int bitmapfd = create(path);
  if(bitmapfd < 0) { close(sfd); close(mfd); return 0; }

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
  win->as.prog.bitmapfd = -1;
  win->as.prog.bitmap = 0;
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
      
      munmap(prog->bitmap);
      close(prog->bitmapfd);

      break;
    }
  }
  win->type = WM_WINDOW_REMOVE;
}

void wm_sort_windows_by_z(struct wm_state *state);
void wm_remove_marked(struct wm_state *state) {
  wm_sort_windows_by_z(state);
  for (int i = 0; i < state->nwindows; i++) {
    struct wm_window *win = &state->windows[i];
    if(win->type == WM_WINDOW_REMOVE) {
      state->nwindows = i;
      return;
    }
  }
}

/* IMPL */

int wm_sort_windows_by_z_compar(const void *av, const void *bv) {
  const struct wm_window *a = av, *b = bv;
  if (a->type == WM_WINDOW_REMOVE || b->type == WM_WINDOW_REMOVE) {
    // place removed windows on the tail of the array
    if(a->type == WM_WINDOW_REMOVE && b->type != WM_WINDOW_REMOVE) return 1;
    else if(a->type == b->type) return 0;
    return -1;
  }
  if (a->z_index < b->z_index) return -1;
  else if(a->z_index == b->z_index) return 0;
  return 1;
}

void wm_sort_windows_by_z(struct wm_state *state) {
  int mouse_wid = state->mouse_win->wid;

  qsort(state->windows, state->nwindows,
        sizeof(struct wm_window),
        wm_sort_windows_by_z_compar);

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

/* SPRITES */

static inline void memset_long(uint32_t *dst, uint32_t c, size_t words) {
  unsigned long d0, d1, d2;
  __asm__ __volatile__(
    "cld\nrep stosl"
    : "=&a"(d0), "=&D"(d1), "=&c"(d2)
    : "0"(c),
      "1"(dst),
      "2"(words)
    : "memory");
}

static inline __m128i clip_u8(__m128i dst) {
  // calculate values > 0xFF
  const __m128i zeroes = _mm_setr_epi32(0, 0, 0, 0);
  const __m128i mask = _mm_setr_epi16(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF);
  __m128i overflow = _mm_srli_epi16(dst, 8);     // dst = dst >> 8
  overflow = _mm_cmpgt_epi16(overflow, zeroes);  // 0xFFFF if overflow[i] > 0, else 0
  dst = _mm_or_si128(dst, overflow);             // dst | overflow
  dst = _mm_and_si128(dst, mask);                // chop higher bits
  return dst;
}

static __m128i alpha_blend_array(__m128i dst, __m128i src) {
  const __m128i rbmask = _mm_setr_epi32(0x00FF00FF, 0x00FF00FF, 0x00FF00FF, 0x00FF00FF);
  const __m128i gmask = _mm_setr_epi32(0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00);
  const __m128i amask = _mm_setr_epi32(0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000);

  const __m128i asub = _mm_setr_epi16(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF);
  const __m128i rbadd = _mm_setr_epi16(0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1);
  const __m128i gadd = _mm_setr_epi16(0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0);

  // alpha(u16) = { A, A, B, B, C, C, D, D }
  __m128i a = _mm_and_si128(src, amask);
  a = _mm_srli_si128(a, 3);
  // swizzle alpha by RB pairs
#if defined(__SSSE3__)
  a = _mm_shuffle_epi8(a, _mm_set_epi8(1, 8, 1, 8, 1, 12, 1, 12, 1, 4, 1, 4, 1, 0, 1, 0));
#else
  a = _mm_shufflehi_epi16(a, _MM_SHUFFLE(0, 0, 2, 2));
  a = _mm_shufflelo_epi16(a, _MM_SHUFFLE(2, 2, 0, 0));
#endif
  a = _mm_subs_epu8(asub, a);  // a = 0xff - a

  // RB * (0xff - alpha) / 0xff
  __m128i rb = _mm_and_si128(dst, rbmask);
  rb = _mm_mullo_epi16(rb, a);
  rb = _mm_srli_epi16(rb, 8);    // RB = RB >> 8
  rb = _mm_adds_epi16(rb, rbadd);  // RB = RB + 1
  // add:
  rb = _mm_adds_epi16(rb, _mm_and_si128(src, rbmask));  // RB += RB(src)
  rb = clip_u8(rb);

  // G * (1 - alpha)
  __m128i g = _mm_and_si128(dst, gmask);
  g = _mm_srli_epi16(g, 8);  // (trim blue portion)
  g = _mm_mullo_epi16(g, a);
  g = _mm_srli_epi16(g, 8);   // G = G >> 8
  g = _mm_adds_epi16(g, gadd);  // G = G + 1
  // add:
  __m128i src_g = _mm_srli_epi16(_mm_and_si128(src, gmask), 8);
  g = _mm_adds_epi16(g, src_g);
  g = clip_u8(g);
  // shift
  g = _mm_slli_epi16(g, 8);

  return _mm_or_si128(rb, g);
}

void alpha_blend(unsigned char *dst, const unsigned char *src, size_t size) {
  __m128i *dst128 = (__m128i *)dst;
  __m128i *src128 = (__m128i *)src;
  for (size_t i = 0; i < size; i++) {
    _mm_storeu_si128(dst128 + i, alpha_blend_array(_mm_loadu_si128(dst128 + i), _mm_loadu_si128(src128 + i)));
  }
}

void wm_bitblt_prog(struct wm_state *state, struct wm_window_prog *prog) {
  if(!prog->bitmap)
    return;
  unsigned char *src = (unsigned char *)prog->bitmap;
  unsigned char *dst = (unsigned char *)state->backbuffer;
  if(prog->alpha) {
    for(unsigned int y = 0; y < prog->height; y++) {
      size_t fb_offset = ((prog->y + y) * state->ws.ws_col + prog->x) * 4;
      size_t src_offset = y * prog->width * 4;
      size_t copy_size = prog->width / 4;
      alpha_blend(&dst[fb_offset],
                  &src[src_offset], copy_size);
    }
  } else {
    for(unsigned int y = 0; y < prog->height; y++) {
      size_t fb_offset = ((prog->y + y) * state->ws.ws_col + prog->x) * 4;
      size_t src_offset = y * prog->width * 4;
      size_t copy_size = prog->width * 4;
      memcpy(&dst[fb_offset],
             &src[src_offset], copy_size);
    }
  }
}

void wm_bitblt_sprite(struct wm_state *state, struct wm_window_sprite *sprite) {
  switch(sprite->type) {
    case WM_SPRITE_COLOR: {
      // TODO: handle sprites that are not as large as the screen
      unsigned int color = sprite->source.color;
      size_t words = state->ws.ws_col * state->ws.ws_row;
      memset_long(state->backbuffer, color, words);
      break;
    }
    case WM_SPRITE_SURFACE_ALPHA: {
      unsigned char *src = (unsigned char *)sprite->source.buffer;
      unsigned char *dst = (unsigned char *)state->backbuffer;
      for (unsigned int y = 0; y < sprite->height; y++) {
        size_t fb_offset = ((sprite->y + y) * state->ws.ws_col + sprite->x) * 4;
        size_t src_offset = y * sprite->width * 4;
        size_t copy_size = sprite->width / 4;
        alpha_blend(&dst[fb_offset],
                    &src[src_offset], copy_size);
      }
      break;
    }
  }
}

int main(int argc, char **argv) {
  // setup
  struct wm_state wm = {0};
  wm.fb_fd = open("/fb0", O_RDWR);
  wm.framebuffer = (unsigned int *)mmap(wm.fb_fd, (size_t)-1);
  struct winsize ws;
  ioctl(wm.fb_fd, TIOCGWINSZ, &ws);
  wm.backbuffer = (unsigned int *)malloc(ws.ws_row * ws.ws_col * 4);
  wm.ws = ws;
  
  wm.focused_wid = -1;

  // wallpaper
  {
    struct wm_window_sprite pape_spr = {
      .source.color = 0x000066cc,
      .x = 0,
      .y = 0,
      .width = ws.ws_col,
      .height = ws.ws_row,
      .type = WM_SPRITE_COLOR
    };
    struct wm_window *win = wm_add_sprite(&wm, &pape_spr);
    win->z_index = 0;
  }

  // mouse
  {
    wm.mouse_fd = open("/mouse/raw", O_RDONLY);

    struct wm_window_sprite mouse_spr = {
      .source.buffer = NULL,
      .x = 100,
      .y = 100,
      .width = 0,
      .height = 0,
      .type = WM_SPRITE_SURFACE_ALPHA
    };
    printf("loading cursor...\n");
    int w, h, n;
    mouse_spr.source.buffer = (unsigned int *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
    if (!mouse_spr.source.buffer) panic("can't load mouse_spr");
    mouse_spr.width = w;
    mouse_spr.height = h;

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
  wm.control_fd = mkfpipe("wm", PIPE_M_RD | PIPE_G_WR);

  wm_build_waitfds(&wm);

  wm.needs_redraw = 1;

  // spawn desktop
  {
    char *spawn_argv[] = {"desktop", NULL};
    spawnv("desktop", (char **)spawn_argv);
  }

  while(1) {
    wm.window_closed = 0;
    {
      // control pipe
      struct wm_connection_request conn_req = { 0 };
      while(
        read(wm.control_fd, &conn_req, sizeof(struct wm_connection_request))
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
      read(wm.mouse_fd, &mouse_packet, sizeof(mouse_packet));

      unsigned int speed = __builtin_ffs(mouse_packet.x + mouse_packet.y);
      struct wm_window_sprite *sprite = &wm.mouse_win->as.sprite;

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
      read(wm.kbd_fd, &keyboard_packet, sizeof(keyboard_packet));
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
          
          // handle events
          struct wm_atom req_atom;
          while(
            read(win->as.prog.sfd, &req_atom, sizeof(struct wm_atom))
              == sizeof(struct wm_atom)
          ) {
            wm_handle_atom(&wm, win, &req_atom);
            if(win->type == WM_WINDOW_REMOVE)
              goto next_win;
          }

          // request a redraw
          struct wm_atom redraw_atom = {
            .type = ATOM_REDRAW_TYPE,
            .redraw.force_redraw = wm.needs_redraw,
          };
          retval = win_write_and_wait(win, &redraw_atom, &respond_atom);

          if (retval == sizeof(struct wm_atom)) {
            if(respond_atom.type == ATOM_WIN_REFRESH_TYPE) {
              if(respond_atom.win_refresh.did_redraw)
                wm.needs_redraw = 1;
            } else {
              wm_handle_atom(&wm, win, &respond_atom);
            }
          }
          
          // remove if we are unable to send any packets
          if(win->as.prog.packet_retries >= MAX_PACKET_RETRIES) {
            wm_mark_win_removed(win);
            wm.window_closed = 1;
          }

          break;
        }
        case WM_WINDOW_SPRITE: {
          break;
        }
      }
    next_win: continue;
    }
    if (wm.window_closed == 1) {
      wm_remove_marked(&wm);
    }
    if (wm.needs_redraw) {
      for (int i = 0; i < wm.nwindows; i++) {
        struct wm_window *win = &wm.windows[i];
        switch (win->type) {
          case WM_WINDOW_PROG: {
            wm_bitblt_prog(&wm, &win->as.prog);
            break;
          }
          case WM_WINDOW_SPRITE: {
            wm_bitblt_sprite(&wm, &win->as.sprite);
            break;
          }
        }
      }
      memcpy(wm.framebuffer, wm.backbuffer, ws.ws_row * ws.ws_col * 4);
      wm.needs_redraw = 0;
    }
    wm.queue_len = 0;
    usleep(FRAME_WAIT);
  }

  return 0;
}
