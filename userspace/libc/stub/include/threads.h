/* Threads <threads.h>

   This file is part of the Public Domain C Library (PDCLib).
   Permission is granted to use, modify, and / or redistribute at will.
*/

/* This header does not include any platform-specific information, but as
   a whole is optional (depending on whether threads are supported or not,
   ref. __STDC_NO_THREADS__), which is why it is located in the example
   platform instead of the general include directory.
*/

#ifndef _PDCLIB_THREADS_H
#define _PDCLIB_THREADS_H _PDCLIB_THREADS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <time.h>

#if __STDC_NO_THREADS__ == 1
#error __STDC_NO_THREADS__ defined but <threads.h> included. Something is wrong about your setup.
#endif

#if __STDC_VERSION__ >= 201112L
/* The rest of <threads.h> can work with a pre-C11 compiler just fine. */
#define thread_local _Thread_local
#endif

/* Initializing value for an object of type once_flag */
#define ONCE_FLAG_INIT _PDCLIB_ONCE_FLAG_INIT

/* Maximum number of times destructors are called on thread termination */
#define TSS_DTOR_ITERATIONS _PDCLIB_TSS_DTOR_ITERATIONS

/* Condition variable */
typedef _PDCLIB_cnd_t cnd_t;

/* Thread */
typedef _PDCLIB_thrd_t thrd_t;

/* Thread-specific storage */
typedef _PDCLIB_tss_t tss_t;

/* Mutex */
typedef _PDCLIB_mtx_t mtx_t;

/* TSS destructor */
typedef void (*tss_dtor_t)( void * );

/* Thread start function */
typedef int (*thrd_start_t)( void * );

/* Flag for use with call_once() */
typedef _PDCLIB_once_flag once_flag;

/* TODO: Documentation. */
enum
{
    mtx_plain,
    mtx_recursive,
    mtx_timed
};

/* TODO: Documentation. */
enum
{
    thrd_timedout,
    thrd_success,
    thrd_busy,
    thrd_error,
    thrd_nomem
};

/* Initialization functions */

/* Ensure that func is called only the first time call_once() is called
   for a given flag.
*/
void call_once( once_flag * flag, void (*func)( void ) );

/* Condition variable functions */

/* Unblock threads waiting on given condition.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
*/
int cnd_broadcast( cnd_t * cond );

/* Destroy condition variable.
   No threads may be waiting on a condition when it is destroyed.
*/
void cnd_destroy( cnd_t * cond );

/* Initialize condition variable.
   Returns thrd_success if successful, thrd_nomem if out of memory, and
   thrd_error if the request could not be honored.
   Initializes the variable in a way that a thread calling cnd_wait() on it
   would block.
*/
int cnd_init( cnd_t * cond );

/* Unblock one thread waiting on the condition variable.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
*/
int cnd_signal( cnd_t * cond );

/* TODO: Documentation.
   Returns thrd_success if successful, thrd_timedout if the specified time
   is reached without acquiring the resource, or thrd_error if the request
   could not be honored.
*/
int cnd_timedwait( cnd_t * _PDCLIB_restrict cond, mtx_t * _PDCLIB_restrict mtx, const struct timespec * _PDCLIB_restrict ts );

/* TODO: Documentation.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
*/ 
int cnd_wait( cnd_t * cond, mtx_t * mtx );

/* Mutex functions */

/* Destroy mutex variable.
   No threads may be waiting on a mutex when it is destroyed.
*/
void mtx_destroy( mtx_t * mtx );

/* Initialize mutex variable.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
   Type must have one of the following values:
   mtx_plain                 -- non-recursive mutex
   mtx_timed                 -- non-recursive mutex supporting timeout
   mtx_plain | mtx_recursive -- recursive mutex
   mtx_timed | mtx_recursive -- recursive mutex supporting timeout
*/
int mtx_init( mtx_t * mtx, int type );

/* Try to lock the given mutex (blocking).
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
   If the given mutex is non-recursive, it must not be already locked by
   the calling thread.
*/
int mtx_lock( mtx_t * mtx );

/* TODO: Documentation.
   Returns thrd_success if successful, thrd_timedout if the specified time
   is reached without acquiring the resource, or thrd_error if the request
   could not be honored.
*/
int mtx_timedlock( mtx_t * _PDCLIB_restrict mtx, const struct timespec * _PDCLIB_restrict ts );

/* Try to lock the given mutex (non-blocking).
   Returns thrd_success if successful, thrd_busy if the resource is already
   locked, or thrd_error if the request could not be honored.
*/
int mtx_trylock( mtx_t * mtx );

/* Unlock the given mutex.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
   The given mutex must be locked by the calling thread.
*/
int mtx_unlock( mtx_t * mtx );

/* Thread functions */

/* Create a new thread.
   Returns thrd_success if successful, thrd_nomem if out of memory, and
   thrd_error if the request could not be honored.
   Create a new thread executing func( arg ), and sets thr to identify
   the created thread. (Identifiers may be reused afer a thread exited
   and was either detached or joined.)
*/
int thrd_create( thrd_t * thr, thrd_start_t func, void * arg );

/* Identify the calling thread.
   Returns the identifier of the calling thread.
*/
thrd_t thrd_current( void );

/* Notify the OS to destroy all resources of a given thread once it
   terminates.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
   The given thread must not been previously detached or joined.
*/
int thrd_detach( thrd_t thr );

/* Compare two thread identifiers for equality.
   Returns nonzero if both parameters identify the same thread, zero
   otherwise.
*/
int thrd_equal( thrd_t thr0, thrd_t thr1 );

/* Terminate calling thread, set result code to res.
   When the last thread of a program terminates the program shall terminate
   normally as if by exit( EXIT_SUCCESS ).
*/
_PDCLIB_Noreturn void thrd_exit( int res );

/* Join the given thread with the calling thread.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
   Function blocks until the given thread terminates. If res is not NULL,
   the given thread's result code will be stored at that address.
*/
int thrd_join( thrd_t thr, int * res );

/* Suspend the calling thread for the given duration or until a signal not
   being ignored is received.
   Returns zero if the requested time has elapsed, -1 if interrupted by a
   signal, negative if the request failed.
   If remaining is not NULL, and the sleeping thread received a signal that
   is not being ignored, the remaining time (duration minus actually elapsed
   time) shall be stored at that address.
*/
int thrd_sleep( const struct timespec * duration, struct timespec * remaining );

/* Permit other threads to run. */
void thrd_yield( void );

/* Thread-specific storage functions */

/* Initialize thread-specific storage, with optional destructor
   Returns thrs_success if successful, thrd_error otherwise (in this case
   key is set to an undefined value).
*/
int tss_create( tss_t * key, tss_dtor_t dtor );

/* Release all resources of a given thread-specific storage. */
void tss_delete( tss_t key );

/* Returns the value for the current thread associated with the given key.
*/
void * tss_get( tss_t key );

/* Sets the value associated with the given key for the current thread.
   Returns thrd_success if successful, thrd_error if the request could not
   be honored.
*/
int tss_set( tss_t key, void * val );

#ifdef __cplusplus
}
#endif

#endif
