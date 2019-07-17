/* _PDCLIB_fillbuffer( struct _PDCLIB_file_t * )

   This file is part of the Public Domain C Library (PDCLib).
   Permission is granted to use, modify, and / or redistribute at will.
*/

/* This is an example implementation of _PDCLIB_fillbuffer() fit for
   use with POSIX kernels.
*/

#include <stdio.h>
#include "pdclib/_PDCLIB_glue.h"

typedef long ssize_t;
extern ssize_t read( int fd, void * buf, size_t count );

int _PDCLIB_fillbuffer( struct _PDCLIB_file_t * stream )
{
    /* No need to handle buffers > INT_MAX, as PDCLib doesn't allow them */
    ssize_t rc = read( stream->handle, stream->buffer, stream->bufsize );
    if ( rc > 0 )
    {
        /* Reading successful. */
        if ( ! ( stream->status & _PDCLIB_FBIN ) )
        {
            /* TODO: Text stream conversion here */
        }
        stream->pos.offset += rc;
        stream->bufend = rc;
        stream->bufidx = 0;
        return 0;
    }
    if ( rc < 0 )
    {
        /* The 1:1 mapping done in _PDCLIB_config.h ensures
           this works.
        */
        *_PDCLIB_errno_func() = 1;
        /* Flag the stream */
        stream->status |= _PDCLIB_ERRORFLAG;
        return EOF;
    }
    /* End-of-File */
    stream->status |= _PDCLIB_EOFFLAG;
    return EOF;
}