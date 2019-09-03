#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#include "wm.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include "../.build/stb_image.h"

double ldexp(double x, int exp) {
    abort();
    return 0.0;
}

const int channels = 4;

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("usage: %s filename\n", argv[0]);
        return 1;
    }

    // open image
    int w, h, n;
    uint8_t *data = stbi_load(argv[1], &w, &h, &n, channels);
    if (data == 0) {
        printf("%s: unable to open file %s\n", argv[0], argv[1]);
        return 1;
    }

    // preprocess data
    for (int i = 0; i < (w * h * 4); i += 4) {
        uint8_t r = data[i + 0];
        uint8_t g = data[i + 1];
        uint8_t b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }

    // draw it!
    int fb_fd = open("/fb0", 0);
    int sample_win_fd_m = open("/pipes/wm:sample:m", 0);
    int sample_win_fd_s = open("/pipes/wm:sample:s", 0);

    struct fbdev_bitblit sprite = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = (uint32_t *)data,
        .x = 0,
        .y = 0,
        .width = w,
        .height = h,
        .type = GFX_BITBLIT_SURFACE
    };

    struct wm_atom atom;
    int retval = 0;
    while ((retval = read(sample_win_fd_m, (char *)&atom, sizeof(atom))) >= 0) {
        if(retval == 0)
            goto wait;
        struct wm_atom respond_atom = {
            .type = ATOM_RESPOND_TYPE,
            .redraw.needs_redraw = 0,
        };
        switch (atom.type) {
            case ATOM_REDRAW_TYPE: {
                ioctl(fb_fd, GFX_BITBLIT, &sprite);
                write(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
            case ATOM_MOVE_TYPE: {
                sprite.x = atom.move.x;
                sprite.y = atom.move.y;
                respond_atom.redraw.needs_redraw = 1;
                write(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
        }
    wait:
        waitfd(sample_win_fd_m, (useconds_t)-1);
    }

    // cleanup
    stbi_image_free(data);
    return 0;
}