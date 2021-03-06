(in-package :xlui)

;***********************************
;   Progress Window                *
;***********************************

(defclass PROGRESS-WINDOW (application-window xml-serializer)
  ((value :accessor value :initform nil :documentation "value returned")
   (title :accessor title :initarg :title :initform "Progress" :documentation "the title of this window")
   )
  (:default-initargs 
    :floating-p t
    :do-show-immediately nil
    :resizable nil
    :minimizable nil
    :closeable nil
    :zoomable nil
    :title "")
  (:documentation "A window that is made up of a progress indicator and a text field to display what is being loaded "))


(defmethod SHOW ((Self progress-window))
  (lui::in-main-thread ()        
    (#/orderFront: (lui::native-window self) nil)
    (#/makeKeyWindow (lui::native-window self))))


(defmethod WINDOW-SHOULD-CLOSE ((Self progress-window))
  ;; should not be closing window: only gets called on Windows with the X button
  nil)


;***********************************
;    Application Meter             *
;***********************************

(defclass PROGRESS-METER ()
  ((title :accessor title :initarg :title :initform "Progress:" :documentation "the title of this window")
   (progress-window :accessor progress-window :initarg :progress-window :initform (load-object "lui:resources;windows;progress.window" :package (find-package :xlui))))
  (:documentation "An indeterminite progress meter.  All you need to do is create the meter, start-animation, then stop-animation and hide the window when you're done.   "))


(defmethod INITIALIZE-INSTANCE :after ((Self progress-meter) &rest Args)
  (declare (ignore args))
  (#/setDrawsBackground: (lui::native-view (view-named (progress-window self) "status-bar")) #$NO)
  (#/setBordered:(lui::native-view (view-named (progress-window self) "status-bar")) #$NO)
  (#/setBezeled: (lui::native-view (view-named (progress-window self) "status-bar")) #$NO)
  (#/setTitle: (lui::native-window (progress-window self)) (native-string (title self)))
  (display (progress-window self)))

 
(defmethod UPDATE-STATUS-BAR ((self progress-meter) text)
  (setf (value (view-named (progress-window self) "status-bar")) text)
  (display (progress-window Self)))

 
(defmethod START-ANIMATION ((self progress-meter))
  (start-animation (view-named (progress-window self) "progress")))


(defmethod STOP-ANIMATION ((Self progress-meter) &key Stop-Function)
  (declare (ignore Stop-Function))
  (stop-animation (view-named (progress-window self) "progress")))


(defmethod HIDE-PROGRESS-WINDOW ((Self progress-meter) Return-Value)
  (declare (ignore return-value))
  (hide (progress-window self)))


(defmethod WINDOW-CLOSE ((Self progress-meter))
  (#/close (lui::native-window (progress-window Self))))


;***********************************
;  Determinite Progress Meter      *
;***********************************

(defclass DETERMINATE-PROGRESS-METER ()
  ((title :accessor title :initarg :title :initform "Progress:" :documentation "the title of this window")
   (progress-window :accessor progress-window :initarg :progress-window :initform (load-object "lui:resources;windows;determinate-progress.window" :package (find-package :xlui))))
  (:documentation "A determinite progress meter, this meter allows you to show the actual progress of your task.  This meter goes from 0 percent to 100 percent and needs increment-by to be caled everytime the meter's bar should be updated. "))


(defmethod INITIALIZE-INSTANCE :after ((Self determinate-progress-meter) &rest Args)
  (declare (ignore args))
  (#/setTitle: (lui::native-window (progress-window self)) (native-string (title self)))
  (display (progress-window self)))


(defmethod INCREMENT-BY ((self determinate-progress-meter) double)
  (increment-by (view-named (progress-window self) "progress") double))


(defmethod HIDE-PROGRESS-WINDOW ((Self determinate-progress-meter) Return-Value)
  (declare (ignore return-value))
  (hide (progress-window self)))

(defmethod SHOW-PROGRESS-WINDOW ((Self determinate-progress-meter) Return-Val)
  (declare (ignore return-val))
  (show (progress-window self)))


(defmethod UPDATE-STATUS-BAR ((self determinate-progress-meter) text)
  (setf (value (view-named (progress-window self) "status-bar")) text)
  (display (progress-window self)))


(defmethod WINDOW-CLOSE ((Self determinate-progress-meter))
  (#/close (lui::native-window (progress-window Self))))

