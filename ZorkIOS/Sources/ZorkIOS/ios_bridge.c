/* ios_bridge.c -- iOS entry point and exit handler for Dungeon */

#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* Shared with supp.c */
jmp_buf dungeon_exit_jump;
volatile int dungeon_exited = 0;

/*
 * I/O strategy:
 *
 * We override putchar() and printf() at link time.  Because Darwin uses
 * two-level namespace linking, these overrides ONLY affect calls within
 * the main executable (our game code).  System dylibs resolve printf/
 * putchar against their own libSystem copy and are never affected, so
 * private-framework log messages can't leak into the game output.
 *
 * stdin is redirected via dup2 (STDIN_FILENO) since system frameworks
 * never read from stdin in a foreground iOS app.
 */

static int game_out_fd = -1;
static int game_in_fd  = -1;

void configure_dungeon_io(int out_write_fd, int in_read_fd)
{
    game_out_fd = out_write_fd;
    game_in_fd  = in_read_fd;
}

/* ── stdio overrides ───────────────────────────────────────────────────── */

int putchar(int c)
{
    if (game_out_fd >= 0) {
        unsigned char ch = (unsigned char)c;
        write(game_out_fd, &ch, 1);
    }
    return c;
}

int puts(const char *s)
{
    if (game_out_fd >= 0 && s) {
        write(game_out_fd, s, strlen(s));
        write(game_out_fd, "\n", 1);
    }
    return 0;
}

int printf(const char *fmt, ...)
{
    if (game_out_fd < 0) return 0;
    va_list args;
    va_start(args, fmt);
    char buf[4096];
    int n = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n > 0) write(game_out_fd, buf, (size_t)n);
    return n;
}

/* ── game entry point ──────────────────────────────────────────────────── */

extern void dungeon_main(int argc, char **argv);

void run_dungeon(void)
{
    dungeon_exited = 0;

    /* Redirect STDIN_FILENO so getchar/scanf read from our input pipe.
     * This is safe — no iOS system framework reads from fd 0 in a
     * foreground app. */
    if (game_in_fd >= 0) {
        dup2(game_in_fd, STDIN_FILENO);
    }

    if (setjmp(dungeon_exit_jump) == 0) {
        dungeon_main(0, NULL);
    }
    /* Arrived here after longjmp from exit_() or normal return */
}
