;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright 2007 William D Clinger.
;
; Permission to copy this software, in whole or in part, to use this
; software for any lawful purpose, and to redistribute this software
; is granted subject to the restriction that all copies made of this
; software must include this copyright notice in full.
;
; I also request that you send me a copy of any improvements that you
; make to this software so that they may be incorporated within it to
; the benefit of the Scheme community.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Tests of string <-> bytevector conversions.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(import (rnrs base)
        (rnrs unicode)
        (rnrs bytevectors)
        (rnrs control)
        (rnrs io simple)
        (rnrs mutable-strings))

; Crude test rig, just for benchmarking.

(define failed-tests '())

(define (test name actual expected)
  (if (not (equal? actual expected))
      (begin (display "******** FAILED TEST ******** ")
             (display name)
             (newline)
             (set! failed-tests (cons name failed-tests)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Basic sanity tests, followed by stress tests on random inputs.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (string-bytevector-tests
         *random-stress-tests* *random-stress-test-max-size*)

  (define (test-roundtrip bvec tostring tobvec)
    (let* ((s1 (tostring bvec))
           (b2 (tobvec s1))
           (s2 (tostring b2)))
      (test "round trip of string conversion" (string=? s1 s2) #t)))

  ; This random number generator doesn't have to be good.
  ; It just has to be fast.

  (define random
    (letrec ((random14
              (lambda (n)
                (set! x (mod (+ (* a x) c) (+ m 1)))
                (mod (div x 8) n)))
             (a 701)
             (x 1)
             (c 743483)
             (m 524287)
             (loop
              (lambda (q r n)
                (if (zero? q)
                    (mod r n)
                    (loop (div q 16384)
                          (+ (* 16384 r) (random14 16384))
                          n)))))
      (lambda (n)
        (if (< n 16384)
            (random14 n)
            (loop (div n 16384) (random14 16384) n)))))
 
  ; Returns a random bytevector of length up to n.

  (define (random-bytevector n)
    (let* ((n (random n))
           (bv (make-bytevector n)))
      (do ((i 0 (+ i 1)))
          ((= i n) bv)
        (bytevector-u8-set! bv i (random 256)))))

  ; Returns a random bytevector of even length up to n.

  (define (random-bytevector2 n)
    (let* ((n (random n))
           (n (if (odd? n) (+ n 1) n))
           (bv (make-bytevector n)))
      (do ((i 0 (+ i 1)))
          ((= i n) bv)
        (bytevector-u8-set! bv i (random 256)))))

  ; Returns a random bytevector of multiple-of-4 length up to n.

  (define (random-bytevector4 n)
    (let* ((n (random n))
           (n (* 4 (round (/ n 4))))
           (bv (make-bytevector n)))
      (do ((i 0 (+ i 1)))
          ((= i n) bv)
        (bytevector-u8-set! bv i (random 256)))))

  (test "utf-8, BMP"
        (bytevector=? (string->utf8 "k\x007f;\x0080;\x07ff;\x0800;\xffff;")
                      '#vu8(#x6b
                            #x7f
                            #b11000010 #b10000000
                            #b11011111 #b10111111
                            #b11100000 #b10100000 #b10000000
                            #b11101111 #b10111111 #b10111111))
        #t)

  (test "utf-8, supplemental"
        (bytevector=? (string->utf8 "\x010000;\x10ffff;")
                      '#vu8(#b11110000 #b10010000 #b10000000 #b10000000
                            #b11110100 #b10001111 #b10111111 #b10111111))
        #t)

  (test "utf-8, errors 1"
        (string=? (utf8->string '#vu8(#x61                             ; a
                                      #xc0 #x62                        ; ?b
                                      #xc1 #x63                        ; ?c
                                      #xc2 #x64                        ; ?d
                                      #x80 #x65                        ; ?e
                                      #xc0 #xc0 #x66                   ; ??f
                                      #xe0 #x67                        ; ?g
                                     ))
                  "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e\xfffd;\xfffd;f\xfffd;g")
        #t)

  (test "utf-8, errors 2"
        (string=? (utf8->string '#vu8(#xe0 #x80 #x80 #x68              ; ???h
                                      #xe0 #xc0 #x80 #x69              ; ???i
                                      #xf0 #x6a                        ; ?j
                                     ))
                  "\xfffd;\xfffd;\xfffd;h\xfffd;\xfffd;\xfffd;i\xfffd;j")
        #t)

  (test "utf-8, errors 3"
        (string=? (utf8->string '#vu8(#x61                             ; a
                                      #xf0 #x80 #x80 #x80 #x62         ; ????b
                                      #xf0 #x90 #x80 #x80 #x63         ; .c
                                     ))
                  "a\xfffd;\xfffd;\xfffd;\xfffd;b\x10000;c")
        #t)

  (test "utf-8, errors 4"
        (string=? (utf8->string '#vu8(#x61                             ; a
                                      #xf0 #xbf #xbf #xbf #x64         ; .d
                                      #xf0 #xbf #xbf #x65              ; ?e
                                      #xf0 #xbf #x66                   ; ?f
                                     ))
                  "a\x3ffff;d\xfffd;e\xfffd;f")
        #t)

  (test "utf-8, errors 5"
        (string=? (utf8->string '#vu8(#x61                             ; a
                                      #xf4 #x8f #xbf #xbf #x62         ; .b
                                      #xf4 #x90 #x80 #x80 #x63         ; ????c
                                     ))

                  "a\x10ffff;b\xfffd;\xfffd;\xfffd;\xfffd;c")
        #t)

  (test "utf-8, errors 6"
        (string=? (utf8->string '#vu8(#x61                             ; a
                                      #xf5 #x80 #x80 #x80 #x64         ; ????d
                                     ))

                  "a\xfffd;\xfffd;\xfffd;\xfffd;d")
        #t)

  ; ignores BOM signature

  (test "utf-8, BOM"
        (string=? (utf8->string '#vu8(#xef #xbb #xbf #x61 #x62 #x63 #x64))
                  "abcd")
        #t)

  (test-roundtrip (random-bytevector 10) utf8->string string->utf8)

  (do ((i 0 (+ i 1)))
      ((= i *random-stress-tests*))
    (test-roundtrip (random-bytevector *random-stress-test-max-size*)
                    utf8->string string->utf8))

  (test "utf-16, BMP"
        (bytevector=? (string->utf16 "k\x007f;\x0080;\x07ff;\x0800;\xffff;")
                      '#vu8(#x00 #x6b
                            #x00 #x7f
                            #x00 #x80
                            #x07 #xff
                            #x08 #x00
                            #xff #xff))
        #t)

  (test "utf-16le, BMP"
        (bytevector=? (string->utf16 "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                                     'little)
                      '#vu8(#x6b #x00
                            #x7f #x00
                            #x80 #x00
                            #xff #x07
                            #x00 #x08
                            #xff #xff))
        #t)

  (test "utf-16, supplemental"
        (bytevector=? (string->utf16 "\x010000;\xfdcba;\x10ffff;")
                      '#vu8(#xd8 #x00 #xdc #x00
                            #xdb #xb7 #xdc #xba
                            #xdb #xff #xdf #xff))
        #t)

  (test "utf-16le, supplemental"
        (bytevector=? (string->utf16 "\x010000;\xfdcba;\x10ffff;" 'little)
                      '#vu8(#x00 #xd8 #x00 #xdc
                            #xb7 #xdb #xba #xdc
                            #xff #xdb #xff #xdf))
        #t)

  (test "utf-16be"
        (bytevector=? (string->utf16 "ab\x010000;\xfdcba;\x10ffff;cd")
                      (string->utf16 "ab\x010000;\xfdcba;\x10ffff;cd" 'big))
        #t)

  (test "utf-16, errors 1"
        (string=? "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                  (utf16->string
                   '#vu8(#x00 #x6b
                         #x00 #x7f
                         #x00 #x80
                         #x07 #xff
                         #x08 #x00
                         #xff #xff)
                   'big))
        #t)

  (test "utf-16, errors 2"
        (string=? "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                  (utf16->string
                   '#vu8(#x00 #x6b
                         #x00 #x7f
                         #x00 #x80
                         #x07 #xff
                         #x08 #x00
                         #xff #xff)
                   'big #t))
        #t)

  (test "utf-16, errors 3"
        (string=? "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                  (utf16->string
                   '#vu8(#xfe #xff     ; big-endian BOM
                         #x00 #x6b
                         #x00 #x7f
                         #x00 #x80
                         #x07 #xff
                         #x08 #x00
                         #xff #xff)
                   'big))
        #t)

  (test "utf-16, errors 4"
        (string=? "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                  (utf16->string
                   '#vu8(#x6b #x00
                         #x7f #x00
                         #x80 #x00
                         #xff #x07
                         #x00 #x08
                         #xff #xff)
                   'little #t))
        #t)

  (test "utf-16, errors 5"
        (string=? "k\x007f;\x0080;\x07ff;\x0800;\xffff;"
                  (utf16->string
                   '#vu8(#xff #xfe     ; little-endian BOM
                         #x6b #x00
                         #x7f #x00
                         #x80 #x00
                         #xff #x07
                         #x00 #x08
                         #xff #xff)
                   'big))
        #t)

  (let ((tostring        (lambda (bv) (utf16->string bv 'big)))
        (tostring-big    (lambda (bv) (utf16->string bv 'big #t)))
        (tostring-little (lambda (bv) (utf16->string bv 'little #t)))
        (tobvec          string->utf16)
        (tobvec-big      (lambda (s) (string->utf16 s 'big)))
        (tobvec-little   (lambda (s) (string->utf16 s 'little))))

    (do ((i 0 (+ i 1)))
        ((= i *random-stress-tests*))
      (test-roundtrip (random-bytevector2 *random-stress-test-max-size*)
                      tostring tobvec)
      (test-roundtrip (random-bytevector2 *random-stress-test-max-size*)
                      tostring-big tobvec-big)
      (test-roundtrip (random-bytevector2 *random-stress-test-max-size*)
                      tostring-little tobvec-little)))

  (test "utf-32"
        (bytevector=? (string->utf32 "abc")
                      '#vu8(#x00 #x00 #x00 #x61
                            #x00 #x00 #x00 #x62
                            #x00 #x00 #x00 #x63))
        #t)

  (test "utf-32be"
        (bytevector=? (string->utf32 "abc" 'big)
                      '#vu8(#x00 #x00 #x00 #x61
                            #x00 #x00 #x00 #x62
                            #x00 #x00 #x00 #x63))
        #t)

  (test "utf-32le"
        (bytevector=? (string->utf32 "abc" 'little)
                      '#vu8(#x61 #x00 #x00 #x00
                            #x62 #x00 #x00 #x00
                            #x63 #x00 #x00 #x00))
        #t)

  (test "utf-32, errors 1"
        (string=? "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#x00 #x00 #x00 #x61
                         #x00 #x00 #xd9 #x00
                         #x00 #x00 #x00 #x62
                         #x00 #x00 #xdd #xab
                         #x00 #x00 #x00 #x63
                         #x00 #x11 #x00 #x00
                         #x00 #x00 #x00 #x64
                         #x01 #x00 #x00 #x65
                         #x00 #x00 #x00 #x65)
                   'big))
        #t)

  (test "utf-32, errors 2"
        (string=? "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#x00 #x00 #x00 #x61
                         #x00 #x00 #xd9 #x00
                         #x00 #x00 #x00 #x62
                         #x00 #x00 #xdd #xab
                         #x00 #x00 #x00 #x63
                         #x00 #x11 #x00 #x00
                         #x00 #x00 #x00 #x64
                         #x01 #x00 #x00 #x65
                         #x00 #x00 #x00 #x65)
                   'big #t))
        #t)

  (test "utf-32, errors 3"
        (string=? "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#x00 #x00 #xfe #xff   ; big-endian BOM
                         #x00 #x00 #x00 #x61
                         #x00 #x00 #xd9 #x00
                         #x00 #x00 #x00 #x62
                         #x00 #x00 #xdd #xab
                         #x00 #x00 #x00 #x63
                         #x00 #x11 #x00 #x00
                         #x00 #x00 #x00 #x64
                         #x01 #x00 #x00 #x65
                         #x00 #x00 #x00 #x65)
                   'big))
        #t)

  (test "utf-32, errors 4"
        (string=? "\xfeff;a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#x00 #x00 #xfe #xff   ; big-endian BOM
                         #x00 #x00 #x00 #x61
                         #x00 #x00 #xd9 #x00
                         #x00 #x00 #x00 #x62
                         #x00 #x00 #xdd #xab
                         #x00 #x00 #x00 #x63
                         #x00 #x11 #x00 #x00
                         #x00 #x00 #x00 #x64
                         #x01 #x00 #x00 #x65
                         #x00 #x00 #x00 #x65)
                   'big #t))
        #t)

  (test "utf-32, errors 5"
        (string=? "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#x61 #x00 #x00 #x00
                         #x00 #xd9 #x00 #x00
                         #x62 #x00 #x00 #x00
                         #xab #xdd #x00 #x00
                         #x63 #x00 #x00 #x00
                         #x00 #x00 #x11 #x00
                         #x64 #x00 #x00 #x00
                         #x65 #x00 #x00 #x01
                         #x65 #x00 #x00 #x00)
                   'little #t))
        #t)

  (test "utf-32, errors 6"
        (string=? "a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#xff #xfe #x00 #x00   ; little-endian BOM
                         #x61 #x00 #x00 #x00
                         #x00 #xd9 #x00 #x00
                         #x62 #x00 #x00 #x00
                         #xab #xdd #x00 #x00
                         #x63 #x00 #x00 #x00
                         #x00 #x00 #x11 #x00
                         #x64 #x00 #x00 #x00
                         #x65 #x00 #x00 #x01
                         #x65 #x00 #x00 #x00)
                   'big))
        #t)

  (test "utf-32, errors 7"
        (string=? "\xfeff;a\xfffd;b\xfffd;c\xfffd;d\xfffd;e"
                  (utf32->string
                   '#vu8(#xff #xfe #x00 #x00   ; little-endian BOM
                         #x61 #x00 #x00 #x00
                         #x00 #xd9 #x00 #x00
                         #x62 #x00 #x00 #x00
                         #xab #xdd #x00 #x00
                         #x63 #x00 #x00 #x00
                         #x00 #x00 #x11 #x00
                         #x64 #x00 #x00 #x00
                         #x65 #x00 #x00 #x01
                         #x65 #x00 #x00 #x00)
                   'little #t))
        #t)

  (let ((tostring        (lambda (bv) (utf32->string bv 'big)))
        (tostring-big    (lambda (bv) (utf32->string bv 'big #t)))
        (tostring-little (lambda (bv) (utf32->string bv 'little #t)))
        (tobvec          string->utf32)
        (tobvec-big      (lambda (s) (string->utf32 s 'big)))
        (tobvec-little   (lambda (s) (string->utf32 s 'little))))

    (do ((i 0 (+ i 1)))
        ((= i *random-stress-tests*))
      (test-roundtrip (random-bytevector4 *random-stress-test-max-size*)
                      tostring tobvec)
      (test-roundtrip (random-bytevector4 *random-stress-test-max-size*)
                      tostring-big tobvec-big)
      (test-roundtrip (random-bytevector4 *random-stress-test-max-size*)
                      tostring-little tobvec-little)))

)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Exhaustive tests.
;
; Tests string <-> bytevector conversion on strings
; that contain every Unicode scalar value.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (exhaustive-string-bytevector-tests)

  ; Tests throughout an inclusive range.

  (define (test-char-range lo hi tostring tobytevector)
    (let* ((n (+ 1 (- hi lo)))
           (s (make-string n))
           (replacement-character (integer->char #xfffd)))
      (do ((i lo (+ i 1)))
          ((> i hi))
        (let ((c (if (or (<= 0 i #xd7ff)
                         (<= #xe000 i #x10ffff))
                     (integer->char i)
                     replacement-character)))
          (string-set! s (- i lo) c)))
      (test "test of long string conversion"
            (string=? (tostring (tobytevector s)) s) #t)))

  (define (test-exhaustively name tostring tobytevector)
   ;(display "Testing ")
   ;(display name)
   ;(display " conversions...")
   ;(newline)
    (test-char-range 0 #xffff tostring tobytevector)
    (test-char-range #x10000 #x1ffff tostring tobytevector)
    (test-char-range #x20000 #x2ffff tostring tobytevector)
    (test-char-range #x30000 #x3ffff tostring tobytevector)
    (test-char-range #x40000 #x4ffff tostring tobytevector)
    (test-char-range #x50000 #x5ffff tostring tobytevector)
    (test-char-range #x60000 #x6ffff tostring tobytevector)
    (test-char-range #x70000 #x7ffff tostring tobytevector)
    (test-char-range #x80000 #x8ffff tostring tobytevector)
    (test-char-range #x90000 #x9ffff tostring tobytevector)
    (test-char-range #xa0000 #xaffff tostring tobytevector)
    (test-char-range #xb0000 #xbffff tostring tobytevector)
    (test-char-range #xc0000 #xcffff tostring tobytevector)
    (test-char-range #xd0000 #xdffff tostring tobytevector)
    (test-char-range #xe0000 #xeffff tostring tobytevector)
    (test-char-range #xf0000 #xfffff tostring tobytevector)
    (test-char-range #x100000 #x10ffff tostring tobytevector))

  ; Feel free to replace this with your favorite timing macro.

  (define (timeit x) x)

  (timeit (test-exhaustively "UTF-8" utf8->string string->utf8))

  ; NOTE:  An unfortunate misunderstanding led to a late deletion
  ; of single-argument utf16->string from the R6RS.  To get the
  ; correct effect of single-argument utf16->string, you have to
  ; use two arguments, as below.
  ;
  ;(timeit (test-exhaustively "UTF-16" utf16->string string->utf16))

  (timeit (test-exhaustively "UTF-16"
                             (lambda (bv) (utf16->string bv 'big))
                             string->utf16))

  ; NOTE:  To get the correct effect of two-argument utf16->string,
  ; you have to use three arguments, as below.

  (timeit (test-exhaustively "UTF-16BE"
                             (lambda (bv) (utf16->string bv 'big #t))
                             (lambda (s) (string->utf16 s 'big))))

  (timeit (test-exhaustively "UTF-16LE"
                             (lambda (bv) (utf16->string bv 'little #t))
                             (lambda (s) (string->utf16 s 'little))))

  ; NOTE:  An unfortunate misunderstanding led to a late deletion
  ; of single-argument utf32->string from the R6RS.  To get the
  ; correct effect of single-argument utf32->string, you have to
  ; use two arguments, as below.
  ;
  ;(timeit (test-exhaustively "UTF-32" utf32->string string->utf32))

  (timeit (test-exhaustively "UTF-32"
                             (lambda (bv) (utf32->string bv 'big))
                             string->utf32))

  ; NOTE:  To get the correct effect of two-argument utf32->string,
  ; you have to use three arguments, as below.

  (timeit (test-exhaustively "UTF-32BE"
                             (lambda (bv) (utf32->string bv 'big #t))
                             (lambda (s) (string->utf32 s 'big))))

  (timeit (test-exhaustively "UTF-32LE"
                             (lambda (bv) (utf32->string bv 'little #t))
                             (lambda (s) (string->utf32 s 'little)))))

(define (main)
  (let* ((count (read))
         (input1 (read))
         (input2 (read))
         (output (read))
         (s3 (number->string count))
         (s2 (number->string input2))
         (s1 (number->string input1))
         (name "bv2string"))
    (run-r6rs-benchmark
     (string-append name ":" s1 ":" s2 ":" s3)
     count
     (lambda ()
       (string-bytevector-tests (hide count count) (hide count input1))
       (exhaustive-string-bytevector-tests)
       (length failed-tests))
     (lambda (result) (equal? result output)))))
