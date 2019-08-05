#pragma once

typedef unsigned int tcflag_t;
typedef unsigned int cc_t;

#define NCCS 2
#define VTIME 0
#define VMIN 1

struct termios {
    tcflag_t c_iflag; /* input modes */
    tcflag_t c_oflag; /* output modes */
    tcflag_t c_cflag; /* control modes */
    tcflag_t c_lflag; /* local modes */
    cc_t c_cc[NCCS];  /* special characters */
};

int tcgetattr(int fd, struct termios *termios_p);
int tcsetattr(int fd, int optional_actions,
              const struct termios *termios_p);

#define TCSAFLUSH 0

#define BRKINT  0
#define ICRNL   0
#define INPCK   0
#define ISTRIP  0
#define IXON    0

#define OPOST   0

#define CS8     0

#define ECHO    0
#define ICANON  0
#define IEXTEN  0
#define ISIG    0