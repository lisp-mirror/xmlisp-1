;;-*- Mode: Lisp; Package: :LUI -*- 
;*********************************************************************
;*                                                                   *
;*           E R R O R    H A N D L I N G                            *
;*                                                                   *
;*********************************************************************
;* Author       : Alexander Repenning, alexander@agentsheets.com     *
;*                http://www.agentsheets.com                         *
;* Copyright    : (c) 1996-2010, AgentSheets Inc.                    *
;* Filename     : error-handling.lisp                                *
;* Last Update  : 06/24/10                                           *
;* Version      :                                                    *
;*    1.0       : 06/24/10                                           *
;* Systems      : OS X 10.6.4                                        *
;* Lisps        : CLozure CL 1.4                                     *
;* Licence      : LGPL                                               *
;* Abstract     : Catch errors and warnings in user friendly way.    *
;*********************************************************************


(in-package :lui)


(export '(catch-errors-nicely))


(defvar *Output-to-Alt-Console-p* t "If true output error info into Alt Console on Mac and Windows")
(defparameter *Last-AgentCubes-Bug* "No errors so far." "String containing last error that occurred in AgentCubes and was captured by the error handler")

(defun PRINT-TO-LOG (Control-String &rest Format-Arguments) "
  Print to platform specific log file. On Mac access output via Console.app"
  (cond (*Output-To-Alt-Console-P*
         (setq *Last-AgentCubes-Bug* (apply #'format nil Control-String Format-Arguments))
         (apply #'format t Control-String Format-Arguments))
        (t 
         (let ((NSString (#/retain (ccl::%make-nsstring (setq *Last-AgentCubes-Bug* (apply #'format nil Control-String Format-Arguments))))))
           (#_NSLog #@"%@" :address NSString)  ;; make sure NSString is not interpreted as format string
           (#/release NSString)))))


(defun PRINT-CONDITION-UNDERSTANDABLY (Condition &optional (Message "") (Stream t))
  (format Stream "~A " Message)
  (ccl::report-condition Condition Stream))


(defun PRINT-DATE-AND-TIME-STAMP (&optional (Stream t))
  (multiple-value-bind (second minute hour date month year day-of-week dst-p tz)
                       (get-decoded-time)
    (declare (ignore DST-P))
    (format Stream "~2,'0d:~2,'0d:~2,'0d of ~a, ~d/~2,'0d/~d (GMT~@d)"
            hour
            minute
            second
            (nth day-of-week '("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday"))
            month
            date
            year
            (- tz))))
  

(defgeneric REPORT-BUG () (:documentation "placeholder for bug-reporting in AgentCubes"))


(eval-when (:execute :load-toplevel :compile-toplevel)
(defmacro CATCH-ERRORS-NICELY ((Situation &key Before-Message After-Message) &body Forms) "Catch errors at high level. Also works in secondary threads. Tries to execute all forms. Any form raising an error will be reported. The remaining forms will not be executted."
  `(catch :wicked-error
     (handler-bind
         ((warning #'(lambda (Condition)
                       (print-to-log 
                        "~A"
                        (with-output-to-string (Out)
                          (print-condition-understandably Condition (format nil "~A warning, " ,Situation) Out)))
                       (muffle-warning)))
          (condition #'(lambda (Condition)
                         (let ((*XMLisp-Print-Synoptic* t))
                           ;; no way to continue
                           ,Before-Message
                           ;; What is the error
                           (ccl::with-autorelease-pool
                               (print-to-log
                                "~A"
                                (with-output-to-string (Log)
                                  (format Log "##############################################~%")
                                  (print-condition-understandably Condition "Error: " Log)
                                  (format Log "~%While ~A~%~%" ,Situation)
                                  (print-date-and-time-stamp Log)
                                  (format Log "~%##############################################~%")
                                  ;; produce a basic stack trace
                                  (format Log "~% ______________Exception in thread \"~A\"___(backtrace)___" (slot-value *Current-Process* 'ccl::name))
                                  (print-nice-call-history :start-frame-number 1 :detailed-p nil :stream Log)
                                  (format Log "~%~%~%")))
                             ;; show minmalist message to end-user
                             (in-main-thread () ;; OS X 10.7 is really insisting on using NSAlerts only in the mmain thread
                               (unless (standard-alert-dialog 
                                        (with-output-to-string (Out)
                                          (print-condition-understandably Condition "Error: " Out))
                                        :is-critical t
                                        :explanation-text (format nil "While ~A" ,Situation)
                                        :yes-text "OK"
                                        :no-text "Report bug")
                                 (report-bug)))
                             ,After-Message
                             (throw :wicked-error Condition))))))
       ,@Forms))))


(defun print-nice-call-history (&key context
                                     process
                                     origin
                                     (detailed-p t)
                                     (count target::target-most-positive-fixnum)
                                     (start-frame-number 0)
                                     (stream *debug-io*)
                                     (print-level *backtrace-print-level*)
                                     (print-length *backtrace-print-length*)
                                     (show-internal-frames *backtrace-show-internal-frames*)
                                     (format *backtrace-format*))
  (let ((*backtrace-print-level* print-level)
        (*backtrace-print-length* print-length)
        (*backtrace-format* format)
        (*standard-output* stream)
        (*print-circle* nil)
        (frame-number (or start-frame-number 0)))
    (format t "~%Call stack (good luck):~%")
    (map-call-frames (lambda (p context)
                       (multiple-value-bind (lfun ) (ccl::cfp-lfun p)
                         (unless (and (typep detailed-p 'fixnum)
                                      (not (= (the fixnum detailed-p) frame-number)))
                           (format t "  ~a :: ~a~%" frame-number (function-name lfun))
                           (incf frame-number))))
                     :context context
                     :process process
                     :origin origin
                     :count count
                     :start-frame-number start-frame-number
                     :test (and (not show-internal-frames) 'ccl::function-frame-p))
    (values)))

#| Examples:

(print (/ 3.4 (sin 0.0)))

(catch-errors-nicely
  ("trying to divide")
  (print (/ 3.4 (sin 0.0))))


(catch-errors-nicely ("various prints")
  (print 1)
  (print 2)
  (error "bad printing")
  (print 3)
  (print 4)
  (print 5))


(catch-errors-nicely ("trying to divide" :before-message (print :sandman))
  (print (/ 3.4 (sin 0.0))))


(process-run-function 
  "doing crazy stuff" 
   #'(lambda () (catch-errors-nicely 
                  ("trying to divide") 
                  (print (/ 3.4 (sin 0.0))))))

(in-main-thread () 
  (catch-errors-nicely
    ("trying to divide")
    (/ 3.4 (sin 0.0))))


(catch-errors-nicely
  ("running simulation")
  (warn "bad agent action"))


(hemlock::time-to-run (catch-errors-nicely ("no problem") nil))

(hemlock::time-to-run (+ 3 4))

(defmacro with-standard-fpu-mode (&body body)
 (let ((saved-mode (gensym)))
   `(let ((,saved-mode (get-fpu-mode)))
      (set-fpu-mode :rounding-mode :nearest :overflow t
		     :underflow nil :division-by-zero t
		     :invalid t :inexact nil)
      (unwind-protect
	    (progn
	      ,@body)
	 (apply #'set-fpu-mode ,saved-mode)))))


(in-main-thread () 
  (catch-errors-nicely
    ("trying to divide")
    (with-standard-fpu-mode
      (/ 3.4 (sin 0.0)))))


(print-to-log "this and that")

(print-to-log "only ~A bottles of beer" 69)


|#
  