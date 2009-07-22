/* Copyright 2009 Felix S Klock II.              -*- indent-tabs-mode: nil -*-
 *
 * $Id$
 *
 * Unified Remembered-set interface.
 *
 * A remembered set is a set of objects.  This interface does not
 * assume a direct mapping from generations (aka regions) to remsets;
 * instead the abstraction is that there is a single remembered set
 * for the whole heap.  (The internal implementation is of course free
 * to maintain a mapping from generations to an internal set
 * structure.)
 * 
 * The standard invariant is: If object A has a region-crossing
 * reference to object B, then A is in the rembered set.
 */

#ifndef INCLUDED_UREMSET_T_H
#define INCLUDED_UREMSET_T_H

#include "larceny-types.h"

struct uremset {
  char *id;
    /* A human-readable string identifying the remset representation. 
     */

  gc_t *collector;

  void *data;

    /* METHODS BELOW */

  void  (*expand_remset_gnos)( uremset_t *urs, int fresh_gno );

  void               (*clear)( uremset_t *urs, int gno );

  bool        (*add_elem_new)( uremset_t *urs, word w );
  bool            (*add_elem)( uremset_t *urs, word w );
  bool           (*add_elems)( uremset_t *urs, word *bot, word *top );

  void       (*enumerate_gno)( uremset_t *urs, int gno, 
                               bool (*scanner)(word loc, void *data), 
                               void *data );
    /* Enumerates all objects in generation (region) gno 
     * that (may) have region-crossing references.
     */

  void (*enumerate_allbutgno)( uremset_t *urs, int gno, 
                               bool (*scanner)(word loc, void *data), 
                               void *data );
    /* Enumerates all objects in generations (regions) *other than* gno
     * that (may) have region-crossing references.
     */

  void     (*enumerate_older)( uremset_t *urs, int gno, 
                               bool (*scanner)(word loc, void *data), 
                               void *data );
    /* Enumerates all objects in generations >= gno 
     * that (may) have region-crossing references.
     * 
     * (Note that gno *is* included in the enumeration.)
     */

  void     (*enumerate_minor)( uremset_t *urs, 
                               bool (*scanner)(word loc, void *data), 
                               void *data );
    /* Enumerates all objects that (may) have references into the
     * nursery.
     * 
     * (Note that objects with region-crossing references that do not
     *  point into the nursery are not necessarily included in the 
     *  enumeration.)
     */

  void           (*enumerate)( uremset_t *urs, 
                               bool (*scanner)(word loc, void *data), 
                               void *data );
    /* Enumerates all objects that (may) have region-crossing references.
     */

  bool       (*is_remembered)( uremset_t *urs, word w );
    /* True if w is in the remembered set. */

  void        (*init_summary)( uremset_t *urs, int gno, 
                               int max_words_per_step, 
                               /* out parameter */ summary_t *s );
    /* Inializes summary_t that enumerates objects in generation (region) gno.
     */
};

#define urs_expand_remset_gnos( r,g )  ((r)->expand_remset_gnos( (r),(g) ))
#define urs_clear( r,g )               ((r)->clear( (r),(g) ))
#define urs_add_elem_new( r,w )        ((r)->add_elem_new( (r),(w) ))
#define urs_add_elem( r,w )            ((r)->add_elem( (r),(w) ))
#define urs_add_elems( r,b,t )         ((r)->add_elems( (r),(b),(t) ))
#define urs_enumerate_gno( r,g,s,d )   ((r)->enumerate_gno( (r),(g),(s),(d) ))
#define urs_enumerate_allbutgno( r,g,s,d ) \
  ((r)->enumerate_allbutgno( (r),(g),(s),(d) ))
#define urs_enumerate_minor( r,s,d )   ((r)->enumerate_minor( (r),(s),(d) ))
#define urs_enumerate( r,s,d )         ((r)->enumerate( (r),(s),(d) ))
#define urs_isremembered( r,w )        ((r)->is_remembered( (r),(w) ))
#define urs_init_summary( r,g,m,s )    ((r)->init_summary( (r),(g),(m),(s) ))

uremset_t
*create_uremset_t(char *id,
                  void *data, 
                  void  (*expand_remset_gnos)( uremset_t *urs, 
                                               int fresh_gno ), 
                  void               (*clear)( uremset_t *urs, int gno ), 
                  bool        (*add_elem_new)( uremset_t *urs, word w ), 
                  bool            (*add_elem)( uremset_t *urs, word w ), 
                  bool           (*add_elems)( uremset_t *urs, 
                                               word *bot, 
                                               word *top ),
                  void       (*enumerate_gno)( uremset_t *urs, 
                                               int gno, 
                                               bool (*scanner)(word loc, 
                                                               void *data), 
                                               void *data ),
                  void (*enumerate_allbutgno)( uremset_t *urs, 
                                               int gno, 
                                               bool (*scanner)(word loc, 
                                                               void *data), 
                                               void *data ),
                  void     (*enumerate_older)( uremset_t *urs, 
                                               int gno, 
                                               bool (*scanner)(word loc, 
                                                               void *data), 
                                               void *data ),
                  void     (*enumerate_minor)( uremset_t *urs, 
                                               bool (*scanner)(word loc, 
                                                               void *data), 
                                               void *data ),
                  void           (*enumerate)( uremset_t *urs, 
                                               bool (*scanner)(word loc, 
                                                               void *data), 
                                               void *data ),
                  bool       (*is_remembered)( uremset_t *urs, word w ),
                  void        (*init_summary)( uremset_t *urs, 
                                               int gno, 
                                               int max_words_per_step, 
                                               summary_t *s_outparam )
                  );

#endif /* INCLUDED_UREMSET_T_H */

/* eof */
