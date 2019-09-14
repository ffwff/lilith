#pragma once

#include <syscalls.h>
#include <wm/wm.h>

struct wmc_connection {
	int wm_control_fd;
	int win_fd_m, win_fd_s;
};

int wmc_connection_init(struct wmc_connection *conn) {
	conn->wm_control_fd = open("/pipes/wm", O_WRONLY);
	if(conn->wm_control_fd < 0) {
		return 0;
	}
	conn->win_fd_m = -1;
	conn->win_fd_s = -1;
	return 1;
}

void wmc_connection_deinit(struct wmc_connection *conn) {
	close(conn->wm_control_fd);
	close(conn->win_fd_m);
	close(conn->win_fd_s);
}

void wmc_connection_obtain(struct wmc_connection *conn, unsigned int event_mask) {
    struct wm_connection_request conn_req = {
        .pid = getpid(),
        .event_mask = event_mask,
    };
    write(conn->wm_control_fd, (char *)&conn_req, sizeof(struct wm_connection_request));
    while(1) {
        // try to poll for pipes
        char path[128] = { 0 };

        if(conn->win_fd_m == -1) {
            snprintf(path, sizeof(path), "/pipes/wm:%d:m", conn_req.pid);
            if((conn->win_fd_m = open(path, O_RDONLY)) < 0) {
                goto await_conn;
            }
        }

        if(conn->win_fd_s == -1) {
            snprintf(path, sizeof(path), "/pipes/wm:%d:s", conn_req.pid);
            if((conn->win_fd_s = open(path, O_WRONLY)) < 0) {
                goto await_conn;
            }
        }

        if(conn->win_fd_m != -1 && conn->win_fd_s != -1) {
            break;
        }

    await_conn:
        usleep(1);
    }
}

int wmc_send_atom(struct wmc_connection *conn, struct wm_atom *atom) {
	return write(conn->win_fd_s, (char *)atom, sizeof(struct wm_atom));
}

int wmc_recv_atom(struct wmc_connection *conn, struct wm_atom *atom) {
    if(atom == NULL) {
        struct wm_atom unused;
        return read(conn->win_fd_m, (char *)&unused, sizeof(struct wm_atom));
    }
    return read(conn->win_fd_m, (char *)atom, sizeof(struct wm_atom));
}

int wmc_wait_atom(struct wmc_connection *conn) {
    return waitfd(&conn->win_fd_m, 1, (useconds_t)-1);
}
