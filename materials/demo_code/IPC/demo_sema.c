#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <unistd.h>

// POSIX semaphores use sem_init(), sem_wait(), sem_post() & sem_destroy().

// Declare a semaphore
sem_t sem;

// Function for the first thread
void* thread1_func(void* arg) {
  for (int i = 0; i < 10; i++) {
    // Wait for the semaphore to be available
    sem_wait(&sem);

    // Print "Hello"
    printf("Hello+++\n");
    fflush(stdout);

    // Signal the semaphore to allow two threads to print again
    sem_post(&sem);

    sleep(1);
  }

  return NULL;
}

// Function for the second thread
void* thread2_func(void* arg) {
  for (int i = 0; i < 10; i++) {
    // Wait for the semaphore to be available
    sem_wait(&sem);

    // Print "World"
    printf("World\n");
    fflush(stdout);

    // Signal the semaphore to allow two threads to print again
    sem_post(&sem);

    // Both threads sleeping one second leads to random result
    // in each run, due to the race between them
    sleep(1);
    // Sleeping two seconds will slow the racing rhythm for thread2
    // sleep(2);
  }
  return NULL;
}

int main() {
  pthread_t thread1, thread2;

  // Initialize the semaphore with an initial value of 0
  sem_init(&sem, 0, 0);

  // Create the first thread
  pthread_create(&thread1, NULL, thread1_func, NULL);

  // Create the second thread
  pthread_create(&thread2, NULL, thread2_func, NULL);

  // Since sem==0, thread1 and thread2 are waiting
  printf("two threads waiting now... return to go.\n");
  getchar();

  // Increments (unlocks) the semaphore sem, to give a start
  sem_post(&sem);

  // Wait for both threads to finish
  pthread_join(thread1, NULL);
  pthread_join(thread2, NULL);

  // Destroy the semaphore
  sem_destroy(&sem);

  return 0;
}
