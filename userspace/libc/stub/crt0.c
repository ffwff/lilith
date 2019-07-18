extern int open(const char*, int);
extern void _exit();

extern int main(int, const char*);

void _start() {
    open("/kbd", 0); // 0
    open("/vga", 0); // 1
    main(0, 0);
    _exit();
}