#lang racket

(provide eliza)

(define fail 'fail)
(define no-bindings '((#t . #t)))

(define (rule-pattern rule) (car rule))
(define (rule-response rule) (cdr rule))

(define (atom? x)
       (not (pair? x)))

(define (pat-match pattern input (bindings no-bindings))
  (cond ((eq? bindings fail) fail)
        ((variable-p pattern)
         (match-variable pattern input bindings))
        ((equal? pattern input) bindings)
        ((segment-pattern? pattern)
         (segment-match pattern input bindings))
        ((and (cons? pattern) (cons? input))
         (pat-match (cdr pattern) (cdr input)
                    (pat-match (car pattern) (car input)
                                bindings)))
        (#t fail)))

(define (eliza)
    (displayln "")
    (print "Eliza:")
    (write (flatten (use-eliza-rules (read))))
    (eliza))

(define *eliza-rules*
    '((((?* ?x) hello (?* ?y))
       (How do you do.  Please state your problem.))
      (((?* ?x) I want (?* ?y))
       (What would it mean if you got ?y)
       (Why do you want ?y) (Suppose you got ?y soon))
      (((?* ?x) if (?* ?y))
       (Do you really think its likely that ?y) (Do you wish that ?y)
       (What do you think about ?y) (Really-- if ?y))
      (((?* ?x) no (?* ?y))
       (Why not?) (You are being a bit negative)
       (Are you saying "NO" just to be negative?))
      (((?* ?x) I was (?* ?y))
       (Were you really?) (Perhaps I already knew you were ?y)
       (Why do you tell me you were ?y now?))
      (((?* ?x) I feel (?* ?y))
       (Do you often feel ?y ?))
      (((?* ?x) I felt (?* ?y))
       (What other feelings do you have?))))

(define (use-eliza-rules input)
    (for/or ((i *eliza-rules*))
        (foo i input)))

(define (foo rule input)
    (let ((result (pat-match (rule-pattern rule) input)))
        (if (not (eq? result fail))
            (sublis (switch-viewpoint result)
                    (random-elt (rule-response rule)))
            #f)))

(define (switch-viewpoint words)
    (sublis '((I . you) (you . I) (me . you) (am . are)) words))

(define (random-elt choices)
    (sequence-ref choices (random (length choices))))

(define (sublis pairs input)
    (if (null? (cdr pairs))
        (replace (cdr (car pairs)) (caar pairs) input)
        (sublis (cdr pairs) (replace (cdr (car pairs)) (caar pairs) input))))

(define (replace a b ls)
     (cond ((null? ls) '())
       ((equal? (car ls) b) (replace a b (cons a (cdr ls))))
       (else (cons (car ls) (replace a b (cdr ls))))))

(define (segment-match pattern input bindings (start 0))
  (let ((var (second (car pattern)))
        (pat (cdr pattern)))
      (if (null? pat)
          (match-variable var input bindings)
          (let ((pos (position (car pat) input start)))
            (if (false? pos)
                fail
                (let ((b2 (pat-match
                            pat (subseq input pos)
                            (match-variable var (subseq input 0 pos)
                                            bindings))))
                    (if (eq? b2 fail)
                        (segment-match pattern input bindings (+ pos 1))
                        b2)))))))

(define (subseq l offset (n (length l)))
  (if (and (< offset n) (>= offset 0) (< offset (length l)) (<= n (length l)) (>= n 0))
      (if (equal? n (length l))
          (drop l offset)
          (drop (take l n) offset))
      #f))

(define (position item list start)
    (cond
        ((or (> start (length list)) (null? (drop list start))) #f)
        ( (eqv? (car (drop list start)) item) start)
          (else (position item list (add1 start) ) )))

(define (segment-pattern? pattern)
  (and (cons? pattern)
       (starts-with? (car pattern) '?*)))

(define (starts-with? list x)
  (and (cons? list) (eqv? (car list) x)))

(define (match-variable var input bindings)
    (let ((binding (get-binding var bindings)))
        (cond ((not binding) (extend-bindings var input bindings))
              ((equal? input (binding-val binding)) bindings)
              (#t fail))))

(define (variable-p x)
  (and (symbol? x)
       (char=? (string-ref (symbol->string x) 0) #\?)))

; Asocia var con su valor (lo busca en bindings)
(define (get-binding var bindings)
 (assoc var bindings))

; Devuelve el resto de binding
(define (binding-val binding)
 (cdr binding))

; Asocia var con su valor y devuelve 'rest'
(define (lookup var bindings)
 (binding-val (get-binding var bindings)))

; Agrega el par var val a la lista de pares bindings
(define (extend-bindings var val bindings)
 (cons (cons var val)
       (if (eq? bindings no-bindings)
            null
            bindings)))
