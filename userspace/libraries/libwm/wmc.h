#pragma once

#include <stdio.h>
#include <syscalls.h>
#ifndef LIBWM_IMPLEMENTATION
#include <wm/wm.h>
#endif

struct wmc_connection {
	int wm_control_fd;
	int win_fd_m, win_fd_s;
};

int wmc_connection_init(struct wmc_connection *conn);
void wmc_connection_deinit(struct wmc_connection *conn);
void wmc_connection_obtain(struct wmc_connection *conn,
			unsigned int event_mask, unsigned int properties);
int wmc_send_atom(struct wmc_connection *conn, struct wm_atom *atom);
int wmc_recv_atom(struct wmc_connection *conn, struct wm_atom *atom);
int wmc_wait_atom(struct wmc_connection *conn);
int wmc_open_bitmap(struct wmc_connection *conn);
