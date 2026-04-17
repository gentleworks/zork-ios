/* ZorkIOS-Bridging-Header.h — exposes C game API to Swift */

#pragma once

/* Configure pipe fds before calling run_dungeon().
 * out_write_fd: game output will be written here (Swift reads from the other end).
 * in_read_fd:   game input will be read from here (Swift writes to the other end). */
void configure_dungeon_io(int out_write_fd, int in_read_fd);

/* Start the game; returns when the game ends. Must be called on a background thread. */
void run_dungeon(void);

/* Set to 1 by exit_() before longjmp; can be read after run_dungeon() returns. */
extern volatile int dungeon_exited;
