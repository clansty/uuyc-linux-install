#include <X11/Xlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        puts("usage: xembed-owner\nExit 0: tray owner exists; 1: absent; 2: display/error.");
        return 0;
    }
    if (argc != 1) {
        fputs("usage: xembed-owner\n", stderr);
        return 2;
    }
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        fputs("Cannot open DISPLAY\n", stderr);
        return 2;
    }
    char name[64];
    snprintf(name, sizeof(name), "_NET_SYSTEM_TRAY_S%d", DefaultScreen(display));
    Atom selection = XInternAtom(display, name, False);
    Window owner = XGetSelectionOwner(display, selection);
    printf("%s owner=0x%lx\n", name, owner);
    XCloseDisplay(display);
    return owner == None ? 1 : 0;
}
