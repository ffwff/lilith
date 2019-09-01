#pragma once

typedef unsigned int tcflag_t;
typedef unsigned int cc_t;

#define VTIME 0
#define VMIN  1
#define NCCS  2

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

#define BRKINT (1 << 0)
#define ICRNL  (1 << 1)
#define INPCK  (1 << 2)
#define ISTRIP (1 << 3)
#define IXON   (1 << 4)
#define OPOST  (1 << 5)

#define CS8     (1 << 0)

#define ECHO    (1 << 0)
#define ICANON  (1 << 1)
#define IEXTEN  (1 << 2)
#define ISIG    (1 << 3)

#define TCSAFLUSH   0
#define TCSAGETS    1