/*
 * wlr-task — tiny client for wlr-taskd's unix socket.
 * Sends argv joined with spaces, pipes server's reply to stdout.
 *   wlr-task list
 *   wlr-task focus 12
 *   wlr-task minimize 7
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <command> [arg]\n", argv[0]);
        return 1;
    }

    char sockpath[256];
    snprintf(sockpath, sizeof(sockpath), "/run/user/%d/wlr-taskd.sock", getuid());

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) { perror("socket"); return 1; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sockpath, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        /* daemon not running — exit quietly */
        return 0;
    }

    /* Build command line from argv */
    char cmd[256] = {0};
    size_t pos = 0;
    for (int i = 1; i < argc && pos < sizeof(cmd) - 2; i++) {
        if (i > 1) cmd[pos++] = ' ';
        size_t n = strlen(argv[i]);
        if (pos + n >= sizeof(cmd) - 2) n = sizeof(cmd) - 2 - pos;
        memcpy(cmd + pos, argv[i], n);
        pos += n;
    }
    cmd[pos++] = '\n';

    if (write(fd, cmd, pos) < 0) { perror("write"); return 1; }
    shutdown(fd, SHUT_WR);

    char buf[4096];
    for (;;) {
        ssize_t r = read(fd, buf, sizeof(buf));
        if (r <= 0) break;
        if (write(STDOUT_FILENO, buf, (size_t)r) < 0) break;
    }
    return 0;
}
