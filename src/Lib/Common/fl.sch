; Copyright 2007 William D Clinger
;
; $Id$
;
; Larceny -- R6RS procedures from (rnrs arithmetic flonums).
; See also Lib/Arch/*/primops.sch and Compiler/common.imp.sch.

($$trace "fl")

; Argument checking.

(define (fl:check! name x)
  (if (not (flonum? x))
      (assertion-violation name "argument not a flonum" x)))

(define (fl:check-args! name args)
  (cond ((null? args) #t)
        ((flonum? (car args))
         (fl:check-args! name (cdr args)))
        (else
         (fl:check! name (car args)))))

(define (flonum-restricted proc name)
  (lambda args
    (fl:check-args! name args)
    (apply proc args)))

(define (flonum-restricted1 proc name)
  (lambda (x)
    (if (flonum? x)
        (proc x)
        (fl:check! name x))))

(define (flonum-doubly-restricted proc name)
  (lambda args
    (fl:check-args! name args)
    (let ((result (apply proc args)))
      (cond ((flonum? result)
             result)
            ((exact? result)
             (inexact result))
            (else
             +nan.0)))))

; flonum? is a primop; see Lib/Arch/*/primops.sch

(define (real->flonum x)
  (assert (real? x))
  (+ x 0.0))

; These can all be slow because important cases will (eventually)
; be handled by Compiler/common.imp.sch

(define fl=? (flonum-restricted = 'fl=?))
(define fl<? (flonum-restricted < 'fl<?))
(define fl>? (flonum-restricted > 'fl>?))
(define fl<=? (flonum-restricted <= 'fl<=?))
(define fl>=? (flonum-restricted >= 'fl>=?))

;;; For the next three procedures, there is a question concerning
;;; their behavior in -r7strict mode, where 0.0 and -0.0 are not
;;; exactly zero and are positive.
;;; These procedures are not (yet) part of R7RS, and the R6RS is
;;; not relevant to -r7strict mode, so SRFI 144 is the only
;;; relevant standard at this time.
;;;
;;; SRFI 144 says fl=?, fl<?, fl>?, fl<=?, and fl>=? should behave
;;; like C99 =, <, >, <=, and >=, which doesn't decide the question
;;; but may provide a hint concerning flzero? and flpositive?.
;;; SRFI 144 says flzero? tests whether its argument is zero, but
;;; doesn't say the test is against exact 0 or (flonum 0); we can
;;; interpret it to mean the latter.  Similarly for flpositive?.
;;; SRFI 144 says flinteger? tests whether its argument is an
;;; "integral flonum", which doesn't decide the question but we can
;;; interpret it to mean it tests to see whether its argument is
;;; equal to the round of its argument, as in IEEE-754 arithmetic.
;;;
;;; We rely on the Principle of Least Astonishment:
;;; Those interpretations are likely to be more consistent with
;;; programmers' expectations for flonum arithmetic than the
;;; interpretation that makes the three procedures behave like
;;; their generic counterparts.
;;; Those interpretations are also consistent with the compiler
;;; tables that generate inline code for calls to these procedures.
;;;
;;; See also the definition of flceiling.

;(define flinteger? (flonum-restricted1 integer? 'flinteger?))
;(define flzero? (flonum-restricted1 zero? 'flzero?))
;(define flpositive? (flonum-restricted1 positive? 'flpositive?))

(define flinteger?
  (flonum-restricted1 (lambda (x) (= x (flround x)))
                      'flinteger?))
(define flzero?
  (flonum-restricted1 (lambda (x) (fl=? x 0.0))
                      'flzero?))
(define flpositive?
  (flonum-restricted1 (lambda (x) (fl>? x 0.0))
                      'flpositive?))

(define flnegative? (flonum-restricted1 negative? 'flnegative?))
(define flodd? (flonum-restricted1 odd? 'flodd?))
(define fleven? (flonum-restricted1 even? 'fleven?))
(define flfinite? (flonum-restricted1 finite? 'flfinite?))
(define flinfinite? (flonum-restricted1 infinite? 'flinfinite?))
(define flnan? (flonum-restricted1 nan? 'flnan?))

(define flmax (flonum-restricted max 'flmax))
(define flmin (flonum-restricted min 'flmin))

(define fl+ (flonum-doubly-restricted + 'fl+))
(define fl* (flonum-doubly-restricted * 'fl*))
(define fl- (flonum-doubly-restricted - 'fl-))
(define fl/ (flonum-doubly-restricted / 'fl/))

(define flabs (flonum-restricted1 abs 'flabs))

(define fldiv-and-mod (flonum-restricted div-and-mod 'fldiv-and-mod))
(define fldiv (flonum-restricted div 'fldiv))
(define flmod (flonum-restricted mod 'flmod))
(define fldiv0-and-mod0 (flonum-restricted div0-and-mod0 'fldiv0-and-mod0))
(define fldiv0 (flonum-restricted div0 'fldiv0))
(define flmod0 (flonum-restricted mod0 'flmod0))

; FIXME: The numerator and denominator procedures are
; defined in Lib/Common/ratnums.sch, which isn't loaded
; until later.
;
; The special casing of 0.0 is for SRFI 144 in -r7strict mode.

(define flnumerator
  (flonum-restricted1 (lambda (x)
                        (cond ((flnan? x)
                               x)
                              ((= x 0.0)
                               x)
                              (else
                               (numerator x))))
                      'flnumerator))

(define fldenominator
  (flonum-restricted1 (lambda (x)
                        (cond ((flnan? x)
                               x)
                              ((= x 0.0)
                               1.0)
                              (else
                               (denominator x))))
                      'fldenominator))

(define flfloor (flonum-restricted1 floor 'flfloor))

;;; See earlier discussion of -r7strict mode.

;(define flceiling (flonum-restricted1 ceiling 'flceiling))

(define flceiling
  (flonum-restricted1 (lambda (x)
                        (if (< x 0.0)
                            (truncate x)
                            (let ((g (truncate x)))
                              (if (not (= g x))
                                  (+ g 1.0)
                                  g))))
                      'flceiling))

(define fltruncate (flonum-restricted1 truncate 'fltruncate))
(define flround (flonum-restricted1 round 'flround))

(define flexp (flonum-restricted1 (lambda (x) (flonum:exp x)) 'flexp))

(define (fllog x . rest)
  (cond ((not (flonum? x))
         (fl:check! 'fllog x))
        ((null? rest)
         (flonum:log x))
        ((not (null? (cdr rest)))
         (assertion-violation 'fllog (errmsg 'msg:wna) (cons x rest)))
        ((not (flonum? (car rest)))
         (fl:check! 'fllog (car rest)))
        (else
         (let ((result (log x (car rest))))
           (if (flonum? result)
               result
               +nan.0)))))

(define flsin (flonum-restricted1 (lambda (x) (flonum:sin x)) 'flsin))
(define flcos (flonum-restricted1 (lambda (x) (flonum:cos x)) 'flcos))
(define fltan (flonum-restricted1 (lambda (x) (flonum:tan x)) 'fltan))
(define flasin (flonum-restricted1 (lambda (x) (flonum:asin x)) 'flasin))
(define flacos (flonum-restricted1 (lambda (x) (flonum:acos x)) 'flacos))
(define flatan (flonum-restricted atan 'flatan))

(define (flsqrt x)
  (if (flonum? x)
      (flonum:sqrt x)
      (fl:check! 'flsqrt x)))

(define (flexpt x y)
  (fl:check! 'flexpt x)
  (fl:check! 'flexpt y)
  (cond ((>= x 0.0)
         (expt x y))
        ((not (integer? y))
         +nan.0)
        (else
         (expt x (exact y)))))

; Heaven help us.
; Implementations of the R6RS must implement these conditions,
; even though these conditions can never occur in systems that
; use IEEE arithmetic.
;
; FIXME: not implemented yet

; &no-infinities
; make-no-infinities-violation
; no-infinities-violation
; &no-nans
; make-no-nans-violation
; no-nans-violation

(define (fixnum->flonum n)
  (fx:check! 'fixnum->flonum n)
  (+ n 0.0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; New for R7RS Orange Edition
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (fl+* x y z)
  (cond ((and (flonum? x) (flonum? y) (flonum? z))
         (flonum:fma x y z))
        (else
         (fl:check-args! 'fl+* (list x y z)))))

(define (flfirst-bessel n x)
  (cond ((and (fixnum? n) (flonum? x))
         (flonum:jn n x))
        (else
	 (fx:check! 'flfirst-bessel n)
	 (fl:check! 'flfirst-bessel x))))

(define (flsecond-bessel n x)
  (cond ((and (fixnum? n) (flonum? x))
         (flonum:yn n x))
        (else
	 (fx:check! 'flsecond-bessel n)
	 (fl:check! 'flsecond-bessel x))))

