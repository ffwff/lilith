#pragma once

struct g_termbox;

struct g_termbox *g_termbox_create();

int g_termbox_in_fd(struct g_termbox *);
int g_termbox_out_fd(struct g_termbox *);

void g_termbox_bind_in_fd(struct g_termbox *, int);
void g_termbox_bind_out_fd(struct g_termbox *, int);
