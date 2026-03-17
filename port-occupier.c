#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

static volatile sig_atomic_t running = 1;
static int server_fd = -1;
static const char *OCCUPIED_MSG_FMT =
    "Port %d is intentionally occupied by port-occupier. Find your own port.\n";

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

int run_port_occupier(int argc, char *argv[]) {
    unsigned short port = 9292;

    if (argc > 1) {
        long p = strtol(argv[1], NULL, 10);
        if (p < 1 || p > 65535) {
            fprintf(stderr, "port must be 1-65535\n");
            return 1;
        }
        port = (unsigned short)p;
    }

    struct sigaction sa = {0};
    sa.sa_handler = handle_signal;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return 1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(server_fd);
        return 1;
    }

    if (listen(server_fd, 4) < 0) {
        perror("listen");
        close(server_fd);
        return 1;
    }

    fprintf(stderr, "port-occupier: holding port %d\n", port);

    while (running) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0)
            continue;

        char msg[128];
        int len = snprintf(msg, sizeof(msg), OCCUPIED_MSG_FMT, port);
        write(client_fd, msg, len);
        close(client_fd);
    }

    close(server_fd);
    fprintf(stderr, "port-occupier: released port %d\n", port);
    return 0;
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    return run_port_occupier(argc, argv);
}
#endif
