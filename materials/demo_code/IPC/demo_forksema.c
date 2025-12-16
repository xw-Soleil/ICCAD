#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/types.h>
#include <unistd.h>

/* <sys/something.h> is for OS specific header files */
/* The System V version semaphore here is mostly used in legacy systems,
 * and not commonly used now.
 * There is another demo example for POSIX semaphore.
 */

#define KEY 0x1111

union semun {
  int val;
  struct semid_ds *buf;
  unsigned short *array;
};

/* p for -1 to lock, v for +1 to unlock */
struct sembuf p = {0, -1, SEM_UNDO};
struct sembuf v = {0, +1, SEM_UNDO};

/* We can turn off all the semop(id, &p/&v, 1) operations,
 * by using an option -DSEMOFF when in compiling.
 * If turned off, the output letter cases would become random.
 * If turned on, output letters go from lower case to upper case.
 */
void my_sema_proc(int sid, int p_or_v, int exit_value) {
#ifndef SEMOFF
  if (p_or_v) {
    if (semop(sid, &p, 1) < 0) {
      perror("semop p");
      exit(exit_value);
    }
  } else {
    if (semop(sid, &v, 1) < 0) {
      perror("semop v");
      exit(exit_value);
    }
  }
#endif
}

int main() {
  int id = semget(KEY, 1, 0666 | IPC_CREAT);
  if (id < 0) {
    perror("semget");
    exit(11);
  }
  union semun u;
  u.val = 1;
  if (semctl(id, 0, SETVAL, u) < 0) {
    perror("semctl");
    exit(12);
  }
  int pid;
  pid = fork();
  srand(pid);
  if (pid < 0) {
    perror("fork");
    exit(1);
  } else if (pid) {
    char *s = "abcdefgh";
    int l = strlen(s);
    for (int i = 0; i < l; ++i) {
      my_sema_proc(id, 1, 13);
      putchar(s[i]);
      fflush(stdout);
      sleep(rand() % 2);
      putchar(s[i]);
      fflush(stdout);
      my_sema_proc(id, 0, 14);
      sleep(rand() % 2);
    }
  } else {
    char *s = "ABCDEFGH";
    int l = strlen(s);
    for (int i = 0; i < l; ++i) {
      my_sema_proc(id, 1, 15);
      putchar(s[i]);
      fflush(stdout);
      sleep(rand() % 2);
      putchar(s[i]);
      fflush(stdout);
      my_sema_proc(id, 0, 16);
      sleep(rand() % 2);
    }
  }
  putchar('\n');
  fflush(stdout);
}
