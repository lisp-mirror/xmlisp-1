;;; LUI: The open source portable Lisp User Interface
;;; Platform specificity: generic
;;; Alexander Repenning and Andri Ioannidou
;;; Version: 0.3 04/10/09
;;;  04/26/09 use logical-pathname
;;;  05/20/09 mouse-moved events
;;;  07/15/09 do not confine mouse events to view content to get dragged events outside of window frame

(in-package :LUI)

;;********************************
;; Event Classes                 *
;;********************************

(defvar *Mouse-Down-View* nil "view last received a mouse down but not yet a mouse up. Upon mouse up view will be reset to nil")


(defvar *Mouse-Last-Moved-View* nil "view that received a moved event last. If mouse gets moved outside the view send a mouse exited event")


(defvar *Current-Event* nil "event")


(defvar *Last-Mouse-Event* nil "The last mouse event that occured")


(defclass EVENT () 
  ((event-type :accessor event-type :initarg :event-type :initform :mouse-down)
   (native-event :accessor native-event :initarg :native-event :initform nil :documentation "native event object"))
  (:documentation "LUI crossplatform event"))


(defclass MOUSE-EVENT (event)
  ((x :accessor x :initarg :x :type fixnum :documentation "pixel coordinate, increasing left to right")
   (y :accessor y :initarg :y :type fixnum :documentation "pixel coordinate, increasing top to bottom")
   (dx :accessor dx :initarg :dx :documentation "delta x, >0 for move right")
   (dy :accessor dy :initarg :dy :documentation "delta y, >0 for move down"))
  (:default-initargs 
      :dx 0
    :dy 0)
  (:documentation "LUI mouse crossplatform event"))


(defclass GESTURE-EVENT (mouse-event)
  ((magnification :accessor magnification :initarg :magnification :type float :documentation "degree of magnification")
   (rotation :accessor rotation :initarg :rotation :type float :documentation "degree of rotation"))
  (:documentation "Gesture multi touch event such as magnify, rotate, and swipe"))


(defclass KEY-EVENT (event)
  ((key-code :accessor key-code :initarg :key-code :type fixnum :documentation "hardware-independent code"))
  (:documentation "LUI key crossplatform event"))


(defgeneric NATIVE-TO-LUI-EVENT-TYPE (t)
  (:documentation "return LUI event type"))


(defgeneric GET-MODIFIER-FLAGS (event)
  (:documentation "Returns the modifier keys if this event"))

(defgeneric GET-CHARACTERS (event)
  (:documentation "Returns the characters of this event"))

;; Modifier Keys

(defgeneric COMMAND-KEY-P ()
  (:documentation "is Command key pressed?"))

(defgeneric SHIFT-KEY-P ()
  (:documentation "is Shift key pressed?"))

(defgeneric ALT-KEY-P ()
  (:documentation "is Alt/Option key pressed?"))

(defgeneric CONTROL-KEY-P ()
  (:documentation "is Control key pressed?"))

;; Special Clicks

(defgeneric DOUBLE-CLICK-P ()
  (:documentation "True if clicked a second time not too long ago"))

;**********************************
;* SUBVIEW-MANAGER-INTERFACE      *
;**********************************

(defclass SUBVIEW-MANAGER-INTERFACE ()
  ()
  (:documentation "Provide access to and process subviews"))


(defgeneric ADD-SUBVIEW (subview-manager-interface subview)
  (:documentation "Add a subview"))

(defgeneric ADD-SUBVIEWS (subview-manager-interface &rest subviews)
  (:documentation "Add subviews. Preserve order for display"))

(defgeneric MAP-SUBVIEWS (subview-manager-interface Function &rest Args)
  (:documentation "Call function in drawing order with each subview"))

(defgeneric RECURSIVE-MAP-SUBVIEWS (subview-manager-interface Function &rest Args)
  (:documentation "Call function in drawing order with each subview and all of its subviews"))

(defgeneric SUBVIEWS (subview-manager-interface)
  (:documentation "Return subviews as list"))

(defgeneric SUPERVIEW (subview-manager-interface)
  (:documentation "Return my superview"))

(defgeneric SWAP-SUBVIEW (subview-manager-interface old-subview new-subview)
  (:documentation "Swap <old-subview> of subview manager with <new-subview>. Prepare <new-subview> by making size and position compatible with <old-subview>"))


(defmethod RECURSIVE-MAP-SUBVIEWS ((Self subview-manager-interface) Function &rest Args)
  (apply Function Self Args)
  (apply #'map-subviews Self #'recursive-map-subviews Function Args))


(defmacro DO-SUBVIEWS ((Subview-Var View) &body Body)
  (let ((View-Var (gensym)))
    `(let ((,View-Var ,View))
       (map-subviews ,View-Var
        #'(lambda (,Subview-Var)
            ,@Body)))))

;**********************************
;* EVENT-LISTENER-INTERFACE       *
;**********************************

(defclass EVENT-LISTENER-INTERFACE ()
  ()
  (:documentation "Receives and handles LUI events"))


(defgeneric VIEW-EVENT-HANDLER (event-listener-interface Event )
  (:documentation "Generic event handler: dispatch event types to methods. 
Call with most important parameters. Make other paramters accessible through *Current-Event*"))


(defgeneric VIEW-LEFT-MOUSE-DOWN-EVENT-HANDLER (event-listener-interface X Y)
  (:documentation "Mouse Click Event handler"))


(defgeneric VIEW-RIGHT-MOUSE-DOWN-EVENT-HANDLER (event-listener-interface X Y)
  (:documentation "Mouse Click Event handler"))


(defgeneric VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER (event-listener-interface X Y DX DY)
  (:documentation "Mouse dragged event handler"))


(defgeneric VIEW-MOUSE-ENTERED-EVENT-HANDLER (event-listener-interface)
  (:documentation "Mouse moved outside of the view last receiving mouse moved events"))


(defgeneric VIEW-MOUSE-EXITED-EVENT-HANDLER (event-listener-interface)
  (:documentation "Mouse moved outside of the view last receiving mouse moved events"))


(defgeneric VIEW-MOUSE-SCROLL-WHEEL-EVENT-HANDLER (event-listener-interface X Y DX DY)
  (:documentation "Scroll wheel events received by views that are contained in active or non active windows at the mouse position. Typically only <dx> <dy> is used"))

;; Gestures

(defgeneric GESTURE-BEGIN-EVENT-HANDLER (event-listener-interface x y)
  (:documentation "A swipe, rotate, or magnify gesture has begun"))


(defgeneric GESTURE-MAGNIFY-EVENT-HANDLER (event-listener-interface x y maginification)
  (:documentation "A swipe, rotate, or magnify gesture has begun"))


(defgeneric GESTURE-SWIPE-EVENT-HANDLER (event-listener-interface x y)
  (:documentation "A swipe, rotate, or magnify gesture has begun"))


(defgeneric GESTURE-ROTATE-EVENT-HANDLER (event-listener-interface x y rotation)
  (:documentation "rotate by <rotation> gesture"))


(defgeneric GESTURE-END-EVENT-HANDLER (event-listener-interface x y)
  (:documentation "A swipe, rotate, or magnify gesture has ended"))

;**********************************
;* LUI-FRAME                      *
;**********************************

(defclass LUI-FRAME()
  ((x :accessor x :initform 0 :initarg :x :documentation "relative x-position to container, pixels")
   (y :accessor y :initform 0 :initarg :y :documentation "relative y-position to container, pixels")
   (width :accessor width :initform 170 :initarg :width :documentation "width in pixels")
   (height :accessor height :initform 90 :initarg :height :documentation "height in pixels"))
  (:documentation "This struct represents the frame of a lui-view or lui-window"))

;**********************************
;* VIEW                           *
;**********************************

(defclass VIEW (subview-manager-interface event-listener-interface)
  ((x :accessor x :initform 0 :initarg :x :documentation "relative x-position to container, pixels")
   (y :accessor y :initform 0 :initarg :y :documentation "relative y-position to container, pixels")
   (width :accessor width :initform 170 :initarg :width :documentation "width in pixels")
   (height :accessor height :initform 90 :initarg :height :documentation "height in pixels")
   (part-of :accessor part-of :initform nil :initarg :part-of :documentation "link to container view or window")
   (native-view :accessor native-view :initform nil :documentation "native OS view object")
   (full-screen-p :accessor full-screen-p :initform nil :initarg :full-screen-p :type boolean :documentation "is the view in full screen mode")
   (current-cursor :accessor current-cursor :initform nil :initarg :current-cursor :documentation "the name of the current cursor of this view")
   (tooltip :accessor tooltip :initform nil :initarg :tooltip :documentation "If this accessor is set it will display this for the tool instead of the documentation")
   (hidden-p :accessor hidden-p :initform nil :documentation "This predicate will tell you if the view is currently hidden or not, should only be set by set-hidden")
   (lock :accessor lock :initform nil :documentation "Some views need to locks to prevent multiple threads from changing their content"))
  (:documentation "a view, control or window with position and size"))

;;_______________________________
;; Generic Methods               |
;;_______________________________

(defgeneric WINDOW (view-or-window)
  (:documentation "Return the window containing this view"))


(defgeneric SET-FRAME (view &key x y width height)
  (:documentation "set position and size"))


(defgeneric SET-SIZE (view-or-window Width Height)
  (:documentation "Set the size"))


(defgeneric SET-POSITION (view-or-window X Y)
  (:documentation "Set the position"))


(defgeneric WINDOW-X (view)
  (:documentation "x offset in window containing view"))


(defgeneric WINDOW-Y (view)
  (:documentation "y offset in window containing view"))


(defgeneric VIEW-CURSOR (view x y)
  (:documentation "Returns the name of the cursor this view should use.  This cursor returned may sometimes be dependent upon the x y position of the mouse in the view."))


(defgeneric VIEW-DID-MOVE-TO-WINDOW (view)
  (:documentation "Called when this view is moved into a window, sometimes a view may want to do some special setup once they are placed into a view hierarchy, if so override this method. "))


(defgeneric DISPLAY (view-or-window)
  (:documentation "Make the view draw: prepare view (e.g., locking, focusing), draw, finish up (e.g., unlocking)"))


(defgeneric DRAW (view-or-window)
  (:documentation "Draw view. Assume view is focused. Only issue render commands, e.g., OpenGL glBegin, and no preparation or double buffer flushing"))


(defgeneric LAYOUT (view-or-window)
  (:documentation "Adjust size and potentially position to container, adjust size and position of content if necesary"))


(defgeneric ALIGN-LUI-SIZE-TO-NATIVE-SIZE (view)
  (:documentation "This method should make sure the lui size and native size are the same"))


(defgeneric ADJUST-X-Y-FOR-WINDOW-OFFSET (view x y)
  (:documentation "On windows, it may be necessaryto adjust the x y coordinates in order to make up for cocotrons strange offsets"))


(defgeneric MAKE-NATIVE-OBJECT (view-or-window)
  (:documentation "Make and return a native view object"))


(defgeneric GET-TOOLIP (view x y)
  (:documentation "Returns a tooltip for this view or for this view's subview"))


(defgeneric ENABLE-TOOLTIPS (view)
  (:documentation "Enable Tooltips for this view"))


(defgeneric WINDOW-OF-VIEW-WILL-CLOSE (view)
  (:documentation "Notify the view that its window is closing so it may do any cleanup it needs done. "))


(defgeneric VIEW-DID-END-RESIZE (view)
  (:documentation "Notify the view that has just completed a resize"))


(defgeneric SET-HIDDEN (view hidden-p)
  (:documentation "Sets the hidden-p of the view to the value of the parameter hidden-p also hides the view if hidden-p is true and unhides it if hidden-p is false"))


(defgeneric HIDE (view)
  (:documentation "Hides this view and sets hidden to t"))


(defgeneric SHOW (view)
  (:documentation "Un hides this view and sets hidden to nil"))


(defgeneric FRAME (view)
  (:documentation "returns a frame representing this view"))


(defgeneric ENTER-FULL-SCREEN-MODE (view)
  (:documentation "switch to full screen mode"))


(defgeneric EXIT-FULL-SCREEN-MODE (view)
  (:documentation "exit from full screen mode"))


(defgeneric RELEASE-VIEW-LOCK (view)
  (:documentation "Release lock of view"))


(defgeneric GRAB-VIEW-LOCK (view)
  (:documentation "Grab lock of view"))

;;_______________________________
;; Default implementation        |
;;_______________________________

(defmethod SET-SIZE ((Self view) Width Height)
  (setf (width Self) Width)
  (setf (height Self) Height))


(Defmethod SET-FRAME-WITH-FRAME ((self view) frame)
  (set-size self (width frame) (height frame))
  (set-position self (x frame) (y frame))) 


(defmethod SET-POSITION ((Self view) X Y)
  (setf (x Self) X)
  (setf (y Self) Y))


(defmethod WINDOW-X ((Self view))
  (let ((x 0) (v Self))
    (loop
      (let ((Container (part-of v)))
        (unless Container (return x))
        (incf x (x v))
        (setq v Container)))))


(defmethod WINDOW-Y ((Self view))
  (let ((y 0) (v Self))
    (loop
      (let ((Container (part-of v)))
        (unless Container (return y))
        (incf y (y v))
        (setq v Container)))))


(defmethod VIEW-DID-MOVE-TO-WINDOW ((Self View))
  ;do nothing
  )


(defmethod VIEW-CURSOR ((Self View) x y)
  (declare (ignore x y))
  nil)


(defmethod INITIALIZE-INSTANCE ((Self view) &rest Args)
  (declare (ignore Args))
  (call-next-method)
  (setf (native-view Self) (make-native-object Self))
  )

(defmethod INITIALIZE-INSTANCE :after ((Self view) &rest Args)
  (declare (ignore Args))
  (enable-tooltips self))

(defmethod DRAW ((Self view))
  ;; nothing
  )


(defmethod LAYOUT ((Self view))
  ;; nothing
  )


(defun FIND-VIEW-AT-SCREEN-POSITION (screen-x screen-y &key Window-Type)
  (declare (ftype function find-window-at-screen-position))
  (let ((Window (find-window-at-screen-position screen-x screen-y :type Window-Type)))
    (when Window
      (find-view-containing-point Window (- Screen-x (x Window)) (- Screen-y (y Window))))))


(defun FIND-MOST-SPECIFIC-VIEW-AT-SCREEN-POSITION (screen-x screen-y &key Window-Type)
  (declare (ftype function find-window-at-screen-position))
  (let ((Window (find-window-at-screen-position screen-x screen-y :type Window-Type)))
    (when Window
      (most-specific-view-containing-point Window (- Screen-x (x Window)) (- Screen-y (y Window))))))


;; Events
(defmethod KEY-EVENT-HANDLER ((Self view) Event)
  (declare (ignore event))
  ;nada
  )

(defmethod VIEW-LEFT-MOUSE-DOWN-EVENT-HANDLER ((Self view) X Y)
  (declare (ignore X Y))
  ;; nada
  )


(defmethod VIEW-RIGHT-MOUSE-DOWN-EVENT-HANDLER ((Self view) X Y)
  (declare (ignore X Y))
  
  ;; nada
  )

(defmethod VIEW-LEFT-MOUSE-UP-EVENT-HANDLER ((Self view) X Y)
  (declare (ignore X Y))
  ;; nada
  )


(defmethod VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER ((Self view) X Y DX DY)
  (declare (ignore X Y DX DY))
  ;; nada
  )


(defmethod VIEW-MOUSE-ENTERED-EVENT-HANDLER ((Self view))
  ;; do nothing
  )


(defmethod VIEW-MOUSE-EXITED-EVENT-HANDLER ((Self view))
  ;; do nothing
  )


(defmethod VIEW-MOUSE-MOVED-EVENT-HANDLER ((Self view) x y dx dy)
  (declare (ignore DX DY)
           (ftype function get-cursor set-cursor))
  (unless (equal (view-cursor self x y) (get-cursor))
    (set-cursor (view-cursor self x y))
    (Setf (current-cursor self) (view-cursor self x y))))


(defmethod VIEW-MOUSE-SCROLL-WHEEL-EVENT-HANDLER ((Self view) x y dx dy)
  (declare (ignore x y dx dy))
  ;; do nothing
  )


(defmethod GESTURE-MAGNIFY-EVENT-HANDLER ((Self view) x y Maginification)
  (declare (ignore x y Maginification))
  ;; do nothing
  )


(defmethod GESTURE-ROTATE-EVENT-HANDLER ((Self view) x y Rotation)
  (declare (ignore x y Rotation))
  ;; do nothing
  )


(defmethod SIZE-CHANGED-EVENT-HANDLER ((Self view) Width Height)
  (declare (ignore Width Height))
  ;; nothing
  )

(defmethod ADJUST-X-Y-FOR-WINDOW-OFFSET ((Self view) X Y)
  (values
   X
   Y))

(defmethod  WINDOW-OF-VIEW-WILL-CLOSE  ((Self view))
  (when (subtypep (type-of self) (find-class 'view))
    (dolist (subview (subviews self))
      (window-of-view-will-close subview))))


(defmethod GET-TOOLTIP-OF-VIEW-AT-SCREEN-POSITION ((Self view) x y)
  (get-tooltip (find-view-at-screen-position x (- (Screen-height nil) y)) x (- (Screen-height nil) y)))


(defmethod GET-TOOLTIP-OF-MOST-SPECIFIC-VIEW-AT-SCREEN-POSITION ((Self view) x y)
  (get-tooltip (find-most-specific-view-at-screen-position x (- (Screen-height nil) y)) x (- (Screen-height nil) y)))


(defmethod GET-TOOLTIP ((Self view) x y)
  (declare (ignore x y))
  (tooltip self))

#|
(defmethod GET-TOOLTIP ((Self view) x y)
  (declare (ignore x y))
  (documentation (type-of self) 'type))
|#
(defmethod GET-TOOLTIP ((Self null) x y)
  (declare (ignore x y))
  nil)


(defmethod VIEW-DID-END-RESIZE ((self view))
  (map-subviews self #'(lambda (View) (view-did-end-resize View ))))


(defmethod FRAME ((self view))
  (make-instance 'lui-frame :x (x self)  :y (y self) :width (width self) :height (height self)))


(eval-when (:execute :load-toplevel :compile-toplevel)
(defmacro WITH-VIEW-LOCKED ((View) &rest Body)
  `(unwind-protect 
       (progn
         (grab-view-lock ,View)
         ,@Body)
     (release-view-lock ,View))))

;**********************************
;* SCROLL-VIEW                    *
;**********************************

(defclass SCROLL-VIEW (view)
  ((has-horizontal-scroller :accessor has-horizontal-scroller :initform t :type boolean :initarg :has-horizontal-scroller)
   (has-vertical-scroller :accessor has-vertical-scroller :initform t :type boolean :initarg :has-vertical-scroller)
   (native-color :accessor native-color :initform nil)
   (vertical-line-scroll :accessor vertical-line-scroll :initform 10.0 :initarg :vertical-line-scroll)
   )
  (:documentation "A scrollable view containing a view"))


(defmethod LAYOUT ((Self scroll-view))
  (set-size Self (width Self) (height Self)))

;**********************************
;* SCROLL-VIEW-ADJUSTING-CONTENTS *
;**********************************

(defclass SCROLL-VIEW-ADJUSTING-CONTENTS (scroll-view)
  ()
  (:documentation "A scrollable view containing a view"))


;**********************************
;* RECTANGLE-VIEW                 *
;**********************************

(defclass RECTANGLE-VIEW (view)
  ((native-color :accessor native-color :initform nil))
  (:documentation "colored rectangle")
  (:default-initargs 
    :x 10
    :y 10))

(defgeneric SET-COLOR (rectangle-view &key Red Green Blue Alpha)
  (:documentation "set RGBA fill color. Color values [0.0..1.0]. Default RGB to 0.0 and A to 1.0"))


;**********************************
;* COLOR-PALETTE-VIEW              *
;**********************************

(defclass COLOR-PALETTE-VIEW (rectangle-view)
  ((native-color :accessor native-color :initform nil)
   (opaque-native-color :accessor opaque-native-color :initform nil)
   (draw-transparency-triangles :accessor draw-transparency-triangles :initform nil))
  (:documentation "colored rectangle and if it has transparency it is shown in one half of the view")
  (:default-initargs 
    :x 10
    :y 10))



;**********************************
;* WINDOW                         *
;**********************************

(defclass WINDOW (subview-manager-interface event-listener-interface)
  ((title :accessor title :initform "untitled" :initarg :title :documentation "text in title bar")
   (x :accessor x :initform 0 :initarg :x :documentation "screen position, pixels")
   (y :accessor y :initform 0 :initarg :y :documentation "screen position, pixels")
   (width :accessor width :initform 170 :initarg :width :documentation "width in pixels")
   (height :accessor height :initform 90 :initarg :height :documentation "height in pixels")
   (track-mouse :accessor track-mouse :initform nil :type boolean :initarg :track-mouse :documentation "If true then window will receive mouse moved events")
   (zoomable :accessor zoomable :initform t :initarg :zoomable :type boolean :documentation "has a control to zoom to largest size needed")
   (minimizable :accessor minimizable :initform t :initarg :minimizable :type boolean :documentation "has control to minimize into dock/taskbar")
   (resizable :accessor resizable :initform t :initarg :resizable :type boolean :documentation "has resize control")
   (closeable :accessor closeable :initform t :initarg :closeable :type boolean :documentation "has close control")
   (borderless :accessor borderless :initform nil :initarg :borderless :type boolean :documentation "has border including title and other decoration")
   (floating-p :accessor floating-p :initform nil :initarg :floating-p :type boolean :documentation "Is the a floating window?")
   (window-needs-saving-p :accessor window-needs-saving-p :initform nil :type boolean :documentation "true if window contains objects that neeed saving")
   (full-screen :accessor full-screen :initform nil :initarg :full-screen :type boolean :documentation "is in full screen mode")
   (do-show-immediately :accessor do-show-immediately :initarg :do-show-immediately :initform t :documentation "if true will show window when creating instance")
   (native-window :accessor native-window :initform nil :documentation "native OS window object")
   (native-view :accessor native-view :initform nil :documentation "native OS view object")
   (min-height :allocation :class :accessor min-height :initarg :min-height :initform 100 :documentation "The minimum height allowed for this class of window")
   (min-width :allocation :class :accessor min-width   :initarg :min-width :initform 100 :documentation "The minimum width allowed for this class of window")
   (tooltip :accessor tooltip :initform nil :initarg :tooltip :documentation "If this accessor is set it will display this for the tool instead of the documentation")
   (hidden-p :accessor hidden-p :initform nil :documentation "This predicate will tell you if the view is currently hidden or not, should only be set by set-hidden")
   (use-custom-window-controller :accessor use-custom-window-controller :initform nil :initarg :use-custom-window-controller :documentation "Tells the window creating whether or not it should use a custom window controller or the default ccl controller")
   (background-color :accessor background-color :initarg :background-color :initform nil :documentation "the color used as a background for the window in the form (Red Green Blue Alpha)")
    #+cocotron (show-main-menu-on-windows :accessor show-main-menu-on-windows :initform nil :initarg :show-main-menu-on-windows :documentation "Should this window should a main menu on Windows?")
   (is-modal-p :accessor is-modal-p :initform nil :documentation "True if this window is currently running modally")
   (720p-mode-p :accessor 720p-mode-p :initform nil :documentation "If true this window will configured to be displayed well for high res video.")
   (window-shutting-down-p :accessor window-shutting-down-p :initform nil :documentation "If true the window has begun the process of closing")
   (window-can-go-full-screen-in-mountain-lion :accessor window-can-go-full-screen-in-mountain-lion :initform nil :initarg :window-can-go-full-screen-in-mountain-lion :documentation "If true when the window is created, this will add the full screen arrows to the window")
   (close-when-escape-is-pressed-p :accessor close-when-escape-is-pressed-p :initform nil :initarg :close-when-escape-is-pressed-p :documentation "if this is set to true, the window will close when escape is pressed, without beeping")
   (center-when-shown :accessor center-when-shown :initform nil :initarg :center-when-shown :documentation "if true center the window before we show it")
   )
  (:documentation "a window that can contain views, coordinate system: topleft = 0, 0")
  (:default-initargs 
      :x 100
      :y 100  
      :width 340
      :height 180))

;;_______________________________
;; Generic Methods               |
;;_______________________________

(defgeneric DISPLAY (Window)
  (:documentation "View draws its contents: needs to do all the focusing, locking, etc, necesssary"))

(defgeneric SHOW (Window)
  (:documentation "Make visible on screen"))

(defgeneric CENTER (Window)
  (:documentation "Put window into the center of the screen"))

(defgeneric HIDE (Window)
  (:documentation "Hide on screen"))

(defgeneric SCREEN-HEIGHT (Window)
  (:documentation "height of the screen that contains window. If window is not shown yet used main screen height"))

(defgeneric SCREEN-WIDTH (Window)
  (:documentation "width of the screen that contains window. If window is not shown yet used main screen width"))

(defgeneric SIZE-CHANGED-EVENT-HANDLER (Window Width Height)
  (:documentation "Size changes through user interaction or programmatically. Could trigger layout of content"))

(defgeneric SHOW-AND-RUN-MODAL (Window)
  (:documentation "show window, only process events for this window, 
after any of the window controls calls stop-modal close window and return value." ))

(defgeneric STOP-MODAL (Window return-value)
  (:documentation "Stop modal mode. Return return-value."))

(defgeneric CANCEL-MODAL (Window)
  (:documentation "Cancel modal mode, close window. Make throw :cancel"))

(defgeneric SWITCH-TO-FULL-SCREEN-MODE (window)
  (:documentation "Window becomes full screen. Menubar and dock are hidden"))

(defgeneric SWITCH-TO-WINDOW-MODE (window)
  (:documentation "Reduce full screen to window. Menubar returns. Dock, if enabled, comes back."))

(defgeneric FIND-VIEW-CONTAINING-POINT (window x y)
  (:documentation "Return the most deeply nested view containing point x, y"))

(defgeneric SUBVIEWS-SWAPPED (window Old-View New-View)
  (:documentation "Called then when subview <Old-View> of window got replaced with <New-View>"))

(defgeneric HAS-BECOME-MAIN-WINDOW (window)
  (:documentation "Called after the window has become the main, i.e., the foremost, window"))

(defgeneric MOUSE-EVENT-HANDLER (Window X Y DX DY Event)
  (:documentation "Invoked on mouse event"))

(defgeneric KEY-EVENT-HANDLER (Window Event)
  (:documentation "Invoked on key event"))

(defgeneric WINDOW-WILL-CLOSE (Window Notification)
  (:documentation "This method will be called by the window delegate whenever the window is about to be close"))

(defgeneric WINDOW-SHOULD-CLOSE (Window)
  (:documentation "This method will be called by the window delegate when the user clicks the close button or a perfomClose action is issued. Return non-nil value to have window closed"))

(defgeneric WINDOW-WILL-ZOOM (Window)
  (:documentation "This method will be called when the window is about to zoom"))


(defgeneric WINDOW-LOST-FOCUS (Window)
  (:documentation "This method will be called by the window delegate when the window is no longer the key window"))


(defgeneric WINDOW-DID-FINISH-RESIZE (Window)
  (:documentation "This method will be called when the window has finished a resize."))

(defgeneric MOST-SPECIFIC-VIEW-CONTAINING-POINT (Window window-x window-y)
  (:documentation "in: window, window-x, window-y; out: view, x, y; return the most specific, i.e., view that contains x, y but does not have subviews containing x, y"))


(defgeneric WINDOW-READY-FOR-ZOOM (Window)
  (:documentation "This method will be called to make sure that the window is ready for a zoom."))

;;_______________________________
;; default implementations       |
;;_______________________________

(defmethod INITIALIZE-INSTANCE ((Self window) &rest Args)
  (declare (ignore Args))
  (call-next-method)
  (setf (native-window Self) (make-native-object Self))
  (when (do-show-immediately Self)
    (show Self)))


(defmethod DISPLAY ((Self Window)) 
  ;; nada
  )


(defmethod DRAW ((Self Window)) 
  ;; nada
  )


(defmethod WINDOW ((Self Window))
  ;; that would be me
  Self)


(defmethod SET-SIZE ((Self Window) Width Height)
  (setf (width Self) Width)
  (setf (height Self) Height)
  (size-changed-event-handler Self Width Height))


(defmethod SET-POSITION ((Self Window) X Y)
  (setf (x Self) X)
  (setf (y Self) Y))


(defmethod WINDOW-X ((Self Window))
  ;; a window has no window offset
  0)


(defmethod WINDOW-Y ((Self Window))
  ;; a window has no window offset
  0)


(defmethod FIND-VIEW-CONTAINING-POINT ((Self window) x y)
  (labels ((find-view (View Superview x y)
             (declare (ignore superview))
             (do-subviews (Subview View)
               (when (and (<= (x Subview) x (+ (x Subview) (width Subview)))
                          (<= (y Subview) y (+ (y Subview) (height Subview))))
                 (find-view Subview View (- x (x Subview)) (- y (y Subview)))))
             ;; I contain point but not my subviews
             (return-from FIND-VIEW-CONTAINING-POINT View)))
    (find-view Self nil x y)))


(defmethod PART-OF ((Self window))
  ;; walking the hierarchy up from agent -> view -> window 
  ;; Window is not a part of anything
  nil)


(defmethod SUBVIEWS-SWAPPED ((Self Window) (Old-View view) (New-View view))
  (declare (ignore Old-View New-View))
  ;; do nothing
  )

(defmethod (SETF 720p-mode-p) :after (value (Self window))
  (when value
    (let ((menu-height 44))
      (set-size self 1280 (- 720 menu-height))
      (set-position self 0 menu-height))))


(defmethod MOST-SPECIFIC-VIEW-CONTAINING-POINT ((Self t) x y)
  (declare (ftype function get-x-y-offset-for-window-origin))
  (labels ((view-containing-point (View x y)
             (do-subviews (Subview View)
                          
               (when (and (<= (x Subview) x (+ (x Subview) (width Subview)))
                          (<= (y Subview) y (+ (y Subview) (height Subview))))
                 (view-containing-point Subview (- x (x Subview)) (- y (y Subview)))))
             ;; no subviews (if any) matched. I am the ONE!
             (unless (hidden-p View)
               (return-from most-specific-view-containing-point (values View x y)))))
    (when (and (<= x (width Self)) (<= y (height Self)))
      (let ((x-offset 0)(y-offset 0))
        (when (subtypep (type-of self) 'window)
          (multiple-value-bind (new-x new-y)
                               (get-x-y-offset-for-window-origin self)
            (setf x-offset new-x)
            (setf y-offset new-y)))
      (view-containing-point Self (- x x-offset) (+ y y-offset))))))






;; Events
(defmethod MOUSE-EVENT-HANDLER ((Self window) Window-x Window-y DX DY Event)
  (declare (ftype function get-x-y-offset-for-window-origin))
  (declare (ftype function convert-from-window-coordinates-to-view-coordinates))
  (catch-errors-nicely ("handling mouse event")
  (multiple-value-bind (View x y)
                       (most-specific-view-containing-point Self Window-x Window-y)
    (when view
      (unless (subtypep (type-of view) 'window)
        (multiple-value-bind (test-x test-y)
                             (convert-from-window-coordinates-to-view-coordinates view window-x (- (height (window self)) window-y))
          (setf x test-x)
          (setf y (- (height view) test-y)))))
    (case (event-type Event)
      ;; MOVED: also trigger enter and leave events
      (:mouse-moved
       (cond
        ;; still moving on same view
        ((equal View *Mouse-Last-Moved-View*)
         (when View
           (view-mouse-moved-event-handler View x y dx dy)))
        ;; different view
        (t
         (when *Mouse-Last-Moved-View*
           (view-mouse-exited-event-handler *Mouse-Last-Moved-View*)
           (setq *Mouse-Last-Moved-View* nil))
         (when View
           (view-mouse-entered-event-handler View)
           (setq *Mouse-Last-Moved-View* View)
           (view-mouse-moved-event-handler View x y dx dy)))))
      ;; DOWN: start the down/drag/up cycle, must be in view
      (:left-mouse-down
       (when View
         (setf *Mouse-Down-View* View)
         (view-left-mouse-down-event-handler View x y)))
      (:right-mouse-down 
       (when View
         (setf *Mouse-Down-View* View)
         (view-right-mouse-down-event-handler View x y)))
      ;; DRAG: use view set by down
      (:left-mouse-dragged
       (when *Mouse-Down-View*
         ;; coordinates relative to mouse Down view
         (let ((x-offset 0)(y-offset 0))
           (when (subtypep (type-of self) 'window)
             (multiple-value-bind (new-x new-y)
                                  (get-x-y-offset-for-window-origin self)
               (setf x-offset new-x)
               (setf y-offset new-y)))
         (view-left-mouse-dragged-event-handler 
          *Mouse-Down-View*
          (- Window-x (window-x *Mouse-Down-View*) x-offset) 
          (+ (- Window-Y (window-y *Mouse-Down-View*)) y-offset)
          dx
          dy))))
      ;; UP: use view set by down
      (:left-mouse-up
       (when *Mouse-Down-View*
         (let ((x-offset 0)(y-offset 0))
           (when (subtypep (type-of self) 'window)
             (multiple-value-bind (new-x new-y)
                                  (get-x-y-offset-for-window-origin self)
               (setf x-offset new-x)
               (setf y-offset new-y)))
         ;; coordinates relative to mouse Down view
         (view-left-mouse-up-event-handler 
          *Mouse-Down-View*
          (- Window-x (window-x *Mouse-Down-View*) x-offset)
          (+ (- Window-Y (window-y *Mouse-Down-View*)) y-offset))
         ;; cleanup time: nobody should use refer to the mouse down view anymore
         ;; the down/drag/up cycle is officially over
         (setq *Mouse-Down-View* nil))))
      ;; Scroll Wheel
      (:scroll-wheel
       (when View
         (view-mouse-scroll-wheel-event-handler View x y dx dy)))
      ;; Gestures
      (:magnify-gesture
       (gesture-magnify-event-handler view x y (magnification Event)))
      (:rotate-gesture
       (gesture-rotate-event-handler view x y (rotation Event)))
      ((:begin-gesture :swipe-gesture :end-gesture)
       ;; do not handle these yet
       )
      (t
       (warn "~%not handling ~A event yet, ~A" (event-type Event) (native-event Event)))))))


(defmethod KEY-EVENT-HANDLER ((Self window) Event)
  (setf *Current-Event* Event))


(defmethod VIEW-EVENT-HANDLER ((Self Window) Event)
  ;; generic event hander
  (let ((*Current-Event* Event))
    (warn "not handling ~A event yet~%" (event-type Event))))


(defmethod VIEW-EVENT-HANDLER ((Self Window) (Event mouse-event))
  (setf *last-mouse-event* event)
  (let ((*Current-Event* Event))
    (with-simple-restart (abandon-view-event-handler "Stop event handling of mouse event ~S of window ~S" Event Self)
      (mouse-event-handler Self (x Event) (y Event) (dx Event) (dy Event) Event))))


(defmethod VIEW-EVENT-HANDLER ((Self Window) (Event gesture-event))
  (let ((*Current-Event* Event))
    (with-simple-restart (abandon-view-event-handler "Stop event handling of gesture event ~S of window ~S" Event Self)
      (mouse-event-handler Self (x Event) (y Event) 0 0 Event))))


(defmethod VIEW-EVENT-HANDLER ((Self Window) (Event key-event))
  ;(setf *current-event* event)
  (let ((*Current-Event* Event))
    (with-simple-restart (abandon-view-event-handler "Stop event handling of key event ~S of window ~S" Event Self)
      (key-event-handler Self Event))))


(defmethod VIEW-LEFT-MOUSE-DOWN-EVENT-HANDLER ((Self window) X Y)
  (declare (ignore X Y))
  ;; nada
  )

(defmethod VIEW-RIGHT-MOUSE-DOWN-EVENT-HANDLER ((Self window) X Y)
  (declare (ignore X Y))
  ;; nada
  )

(defmethod VIEW-LEFT-MOUSE-UP-EVENT-HANDLER ((Self window) X Y)
  (declare (ignore X Y))
  ;; nada
  )


(defmethod VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER ((Self window) X Y DX DY)
  (declare (ignore X Y DX DY))
  ;; nada
  )


(defmethod VIEW-MOUSE-MOVED-EVENT-HANDLER ((Self window) x y dx dy)
  (declare (ignore X Y DX DY))
  ;; nothing
  )


(defmethod VIEW-MOUSE-SCROLL-WHEEL-EVENT-HANDLER ((Self window) x y dx dy)
  (declare (ignore x y dx dy))
  ;; nada
  )


(defmethod GESTURE-MAGNIFY-EVENT-HANDLER ((Self window) x y Maginification)
  (declare (ignore x y Maginification))
  ;; nada
  )


(defmethod GESTURE-ROTATE-EVENT-HANDLER ((Self window) x y Rotation)
  (declare (ignore x y rotation))
  ;; nada
  )


(defmethod SIZE-CHANGED-EVENT-HANDLER ((Self Window) Width Height)
  (declare (ignore Width Height))
  ;; nothing
  )


(defmethod VIEW-MOUSE-ENTERED-EVENT-HANDLER ((Self window))
  ;; do nothing
  )


(defmethod VIEW-MOUSE-EXITED-EVENT-HANDLER ((Self window))
  ;; do nothing
  )


;; notifications

(defmethod HAS-BECOME-MAIN-WINDOW ((Self window))
  )


(defmethod WINDOW-WILL-CLOSE ((Self window) Notification)
  (declare (ignore Notification))
  (when (and (subviews self) (first (subviews self)) )
    (dolist (subview (subviews (first (subviews self))))
      (window-of-view-will-close subview)))
  
  ;;Do nothing, override this method if you need to do any cleanup when the window closes.
  )


(defmethod WINDOW-SHOULD-CLOSE ((Self window))
  t ;; should be closed by default
  )


(defmethod WINDOW-LOST-FOCUS ((Self window))
  ;; Do nothing
  )


(defmethod WINDOW-DID-FINISH-RESIZE ((Self window))
  ;;Do nothing
  )


(defmethod WINDOW-READY-FOR-ZOOM ((Self window))
  t)

(defmethod WINDOW-WILL-ZOOM ((Self window))
  ;; Do nothing
  )

(defmethod GET-TOOLTIP ((Self window) x y)
  (declare (ignore x y))
  (tooltip self))



;****************************************************
; CONTROL                                           *
;****************************************************

(defclass CONTROL (view)
  ((target :accessor target :initform nil :initarg :target :documentation "the receiver of a action message when control is clicked. Default to self.")
   (action :accessor action :initform 'control-default-action :initarg :action :type symbol :documentation "method by this name will be called on the window containing control and the target of the control")
   (text :accessor text :initform "untitled" :initarg :text :type string :documentation "text associated with control")
   (start-disabled :accessor start-disabled :initform nil :type boolean :initarg :start-disabled :documentation "If true, the control will be disabled when it is initialized.")
   )
  (:documentation "LUI Control: when clicked will call the action method of its target, maintains a value"))


(defgeneric INVOKE-ACTION (control)
  (:documentation "invoke to main control action. Called via events or user"))

(defgeneric VALUE (control)
  (:documentation "Return the control value"))

(defgeneric DISABLE (control)
  (:documentation "Disable: control is faded out"))

(defgeneric ENABLE (control)
  (:documentation "Enable: completely visible"))

(defgeneric IS-ENABLED (control)
  (:documentation "true if control is enabled"))

(defgeneric INITIALIZE-EVENT-HANDLING (control)
  (:documentation "setup control that it invoke its action method when clicked"))

;__________________________________
; default implementation            |
;__________________________________/

(defmethod INITIALIZE-INSTANCE ((Self control) &rest Args)
  (declare (ignore Args))
  (call-next-method)
  (when (start-disabled self)
    (Disable self))
  (unless (target Self) (setf (target Self) Self)) ;; make me default target
  (initialize-event-handling Self))


(defmethod VALUE ((self control))
  (text self))


(defmethod CONTROL-DEFAULT-ACTION ((Window window) (Target Control))
  ;; do nothing
  )


(defmethod CONTROL-DEFAULT-ACTION ((Window null) (Target Control))
  ;; control may not be properly installed in window
  (warn "~%control default action: window=~A, target=~A" Window Target))


(defmethod MAKE-NATIVE-CONTROL ((Self control))
  ;; keep the view
  (native-view Self))


(defmethod INVOKE-ACTION ((Self control))  
  (funcall (action Self) (window Self) (target Self)))



;****************************************************
; Control Library                                   *
;****************************************************
;__________________________________
; Buttons                          |
;__________________________________/


(defclass BUTTON-CONTROL (control)
  ((default-button :accessor default-button :initform nil :type boolean :documentation "if true button is selectable with return key")
   (escape-button :accessor escape-button :initform nil :type boolean :documentation "if true button is selectable with escape key"))
  (:documentation "Button: fixed height")
  (:default-initargs 
    :width 72
    :height 32))


(defclass BEVEL-BUTTON-CONTROL (control)
  ((bezel-style :accessor bezel-style :initform nil :documentation "the bezel style of this button, if this is nil we will use rounded by default")
   (default-button :accessor default-button :initform nil :type boolean :documentation "if true button is selectable with return key")
   (color :accessor color :initform nil :initarg :color :documentation "A hex repsentation of the background color of this button")
   )
  (:documentation "Bevel Button: any height and width")
  (:default-initargs 
    :width 72
    :height 32))


(defclass CHECKBOX-CONTROL (control)
  ((start-checked :accessor start-checked :initform nil :initarg :start-checked )
   (image-on-right :accessor image-on-right :initform nil :initarg :image-on-right))
  (:documentation "Checkbox")
  (:default-initargs 
      :action 'default-action))


(defmethod DEFAULT-ACTION ((window window) (self checkbox-control))
  (declare (ignore window))
  (declare (ignore self)))


(defclass IMAGE-BUTTON-CONTROL (control)
  ((image :accessor image :initform nil :initarg :image :documentation "filename")
   (container :accessor container :initform nil)
   (in-cluster :accessor in-cluster :initform nil)
   (user-action :accessor user-action :initform nil)
   (selected-in-cluster :accessor selected-in-cluster :initform nil)
   (key-equivalent :accessor key-equivalent :initform "")
   (hide-border :accessor hide-border :initform nil :type boolean)
   (button-type :accessor button-type :initform "on-off" :documentation "Can be either on-off or push-in")
   )
  (:default-initargs
      :text "")
  (:documentation "Button Image"))


(defmethod DEFAULT-ACTION ((window window) (self image-button-control))
  (declare (ignore window))
  (declare (ignore self)))


(defclass POPUP-BUTTON-CONTROL (control)
  ((actions :initarg :actions :accessor actions  :initform ()
            :documentation "list of actions")
   (container :initarg :container :accessor container  :initform nil
            :documentation "The object that contains this control")
   )
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "Popup Button"))


(defclass POPUP-IMAGE-BUTTON-CONTROL (control)
  ((image :accessor image :initform nil :initarg :image :documentation "filename")
   (popup-menu-cell :accessor popup-menu-cell :initform nil :documentation "popup menu cell for this button")
   (menu :accessor menu :initform nil :documentation "popup menu cell for this button")
   (popup-button :accessor popup-button :documentation "an invisible popup butoton")
   (items :accessor items :initform nil  :documentation " a list of the items of control")
   (disclosure-image :accessor disclosure-image :initform nil )
   (draw-disclosure :accessor draw-disclosure :initform t :type boolean)
   )
  (:default-initargs
      :text ""
    :action 'popup-image-button-action)
  (:documentation "Popup Image Button"))


(defclass POPUP-IMAGE-BUTTON-ITEM-CONTROL (control)
  ((popup-image-button :accessor popup-image-button :initform nil :initarg :popup-image-button :documentation "the window this item is contained inside")
   (enable-predicate :accessor enable-predicate :initarg :enable-predicate :initform 'default-enable-predicate)
   )
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "Popup Image Button"))


(defclass POPUP-IMAGE-BUTTON-SUBMENU-CONTROL (control)
  ((popup-image-button :accessor popup-image-button :initform nil :initarg :popup-image-button :documentation "the window this item is contained inside")
   (enable-predicate :accessor enable-predicate :initarg :enable-predicate :initform 'default-enable-predicate))
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "Popup Image Button Submenu"))


(defmethod DEFAULT-ENABLE-PREDICATE ((window window) (self popup-image-button-item-control))
  t)


(defclass RADIO-BUTTON-CONTROL (control)
  ((elements :initarg :elements :accessor elements :initform nil)
   (actions :initarg :actions :accessor actions  :initform ()
            :documentation "list of actions"))
  (:default-initargs
      :text ""
   :action 'radio-action)
  (:documentation "radio-button"))





(defclass CHOICE-BUTTON-CONTROL (control)
  ((actions :initarg :actions :accessor actions  :initform ()
            :documentation "list of actions"))
  (:default-initargs
      :text ""
    :action 'choice-button-action)
  (:documentation "Popup Button"))


(defclass IMAGE-BUTTON-CLUSTER-CONTROL (control)
  ((elements :initarg :elements :accessor elements :initform nil)
   (actions :initarg :actions :accessor actions  :initform ()
            :documentation "list of actions"))
  (:default-initargs
      :text ""
   :action 'image-cluster-action)
  (:documentation "radio-button"))



(defmethod IMAGE-CLUSTER-ACTION ((window window) (self Radio-Button-Control))
  ;; do nothing
  )

;__________________________________
; JOG-BUTTON                       |
;__________________________________/

(defclass JOG-BUTTON-CONTROL (image-button-control)
  ((stop-value :accessor stop-value :initform 0.0 :type float :initarg :stop-value :documentation "The value of jog dial when not operated by user")
   (action-interval :accessor action-interval :initform 0.1 :type float :documentation "time in seconds between two calls to action when jog is active")
   (is-jog-active :accessor is-jog-active :initform nil))
  (:documentation "Unlike a regular slider a JOG slider keeps calling its control action as long as the mouse is down even if the knob is no longer moved. After mouse up the value of slide returns to stop value"))


(defgeneric START-JOG (jog-button-control)
  (:documentation "Called when user is starting Jog."))


(defgeneric STOP-JOG (jog-button-control)
  (:documentation "Called when user is done with Jog. Default action sets slides value to stop-value"))


;__________________________________
; default implementation           |
;__________________________________/

(defmethod START-JOG ((Self jog-button-control))
  ;; nothing
  )


(defmethod STOP-JOG ((Self jog-button-control))
  ;; reset slider to stop value
  (setf (is-jog-active Self) nil)
  ;(setf (value Self) (stop-value Self))
  )


;__________________________________
; String List                      |
;__________________________________/


(defclass STRING-LIST-CONTROL (control)
  ((lui-view :accessor lui-view :initform nil)
   (selected-string :accessor selected-string :initform nil)
   )
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "Popup Image Button Submenu"))


;__________________________________
; String List View                  |
;__________________________________/


(defclass STRING-LIST-VIEW-CONTROL (control)
  ((list-items :accessor list-items :initform nil :documentation "The list of strings displayed in this list")
   (item-height :accessor  item-height :initform 16 :documentation "The height of an item in the list")
   (selected-string :accessor selected-string :initform nil)
   )
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "Popup Image Button Submenu"))



;__________________________________
; ATTRIBUTE VALUE LIST VIEW CONTROL|
;__________________________________/


(defclass ATTRIBUTE-VALUE-LIST-VIEW-CONTROL (control)
  ((list-items :accessor list-items :initform nil :documentation "The list of strings displayed in this list")
   (item-height :accessor  item-height :initform 16 :documentation "The height of an item in the list")
   (selected-string :accessor selected-string :initform nil)
   (attribute-owner :accessor attribute-owner :initform nil :documentation "An owner can be associated with this object and if so, it will be notifed when this objects value-text-field is editted.  In order for this to work, you will need to an attribute-changed-action.")
   (attribute-changed-action :accessor attribute-changed-action :initform nil)
   (color-update-process :accessor color-update-process :initform nil)
   )
  (:default-initargs
      :text ""
    :action 'popup-action)
  (:documentation "A list of items with associated value"))


;__________________________________
; ATTRIBUTE VALUE LIST TEXT VIEW   |
;__________________________________/


(defclass ATTRIBUTE-EDITOR-VIEW (control)
  ((container :accessor container :initform nil :initarg :container)
   (value-save :accessor value-save :initform nil :documentation "if the user begins editing we save the old value in case they enter a bad value so we can restore the old value")
   (attribute-owner :accessor attribute-owner :initform nil :initarg :attribute-owner :documentation "An owner can be associated with this object and if so, it will be notifed when this objects value-text-field is editted.  In order for this to work, you will need to an attribute-changed-action.")
   (attribute-changed-action :accessor attribute-changed-action :initform 'default-attribute-changed-action :type symbol :initarg :attribute-changed-action )   
   )
  (:default-initargs
      :text "")
  (:documentation "This object is a specialized text field that will call the attribute-changed-action when text editing has ended in its text field.    "))


(defmethod MAP-SUBVIEWS ((Self attribute-editor-view) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )

(defmethod initialize-event-handling ((Self attribute-editor-view))
  ;; no event handling for rows
  )

(defmethod TEXT-DID-END-EDITING ((Self attribute-editor-view))
  "This method is called when the text of the text field is done being edited, the default behavior is to call the attribute-changed-action with the attribute-owner and the window, this method could be overwritten if you want to do something else instead"
  (unless (attribute-owner self)
      (setf (attribute-owner self) self))
  (funcall (attribute-changed-action self) (window self) (attribute-owner self)))


(defmethod DEFAULT-ATTRIBUTE-CHANGED-ACTION ((window window) (Self attribute-editor-view))
  ;; do nothing
  )

;__________________________________
; ATTRIBUTE VALUE LIST TEXT VIEW   |
;__________________________________/

(defclass ATTRIBUTE-VALUE-LIST-TEXT-VIEW (attribute-editor-view)
  ()
  (:default-initargs
      :text "")
  (:documentation "A text field that detects mouse events.  "))

;__________________________________
; Scroller                         |
;__________________________________/


(defclass SCROLLER-CONTROL (control)
  ((knob-proportion :accessor knob-proportion :initform .2 :documentation "This value must a float between 0.0 and 1.0 and is used to determine what portion of the scroller the knob takes up.  ")
   (small-scroller-size :accessor small-scroller-size :initform nil :type boolean :documentation "if this accessor is set to true the scroller will be created with the smaller size"))
  (:documentation "Scroller")
  (:default-initargs 
      :action 'scroll-action))


(defmethod SCROLL-ACTION ((window window) (self scroller-control))
  (declare (ignore window))
  (declare (ignore self)))


;__________________________________
; Seperator                        |
;__________________________________/

(defclass SEPERATOR-CONTROL (control)
  ()
  (:documentation "Seperator")
  (:default-initargs 
 
    :width 20
    :height 1))


(defmethod INITIALIZE-INSTANCE :after ((Self seperator-control) &rest Args)
  (declare (ignore Args)))

               
(defmethod initialize-event-handling ((Self seperator-control))
  ;; not clickable
  )


;__________________________________
; Sliders                          |
;__________________________________/

(defclass SLIDER-CONTROL (control)
  ((min-value :accessor min-value :initform 0.0 :initarg :min-value :type float :documentation "minimal value")
   (max-value :accessor max-value :initform 100.0 :initarg :max-value :type float :documentation "maximal value")
   (value :accessor value :initform 0.0 :initarg :value :type float :documentation "current value")
   (tick-marks :accessor tick-marks :initform 0 :initarg :tick-marks :type integer :documentation "number of tick marks, 0=no tick marks"))
  (:documentation "slider")
  (:default-initargs 
    :width 100
    :height 30))

;__________________________________
; JOG-SLIDER                       |
;__________________________________/

(defclass JOG-SLIDER-CONTROL (slider-control)
  ((stop-value :accessor stop-value :initform 0.0 :type float :initarg :stop-value :documentation "The value of jog dial when not operated by user")
   (action-interval :accessor action-interval :initform 0.1 :type float :documentation "time in seconds between two calls to action when jog is active")
   (is-jog-active :accessor is-jog-active :initform nil))
  (:default-initargs
      :tick-marks 3)
  (:documentation "Unlike a regular slider a JOG slider keeps calling its control action as long as the mouse is down even if the knob is no longer moved. After mouse up the value of slide returns to stop value"))


(defgeneric START-JOG (jog-slider-control)
  (:documentation "Called when user is starting Jog."))


(defgeneric STOP-JOG (jog-slider-control)
  (:documentation "Called when user is done with Jog. Default action sets slides value to stop-value"))


;__________________________________
; default implementation           |
;__________________________________/

(defmethod START-JOG ((Self jog-slider-control))
  ;; nothing
  )


(defmethod STOP-JOG ((Self jog-slider-control))
  ;; reset slider to stop value
  (setf (is-jog-active Self) nil)
  (setf (value Self) (stop-value Self)))

;__________________________________
; Text                             |
;__________________________________/

(defclass LABEL-CONTROL (control)
  ((align :accessor align :initform :left :initarg :align :type keyword :documentation ":left, :center , :right, :justified")
   (size :accessor size :initform 0.0 :initarg :size :type float :documentation "font size. 0.0 for default system font size")
   (bold :accessor bold :initform nil :initarg :bold :type boolean :documentation "whether or not the label text is bold"))
  (:documentation "static text label")
  (:default-initargs 
    :text ""
    :width 100
    :height 20))


(defmethod initialize-event-handling ((Self label-control))
  ;; not clickable
  )


(defclass EDITABLE-TEXT-CONTROL (control)
  ((align :accessor align :initform :left :initarg :align :type keyword :documentation ":left, :center , :right, :justified")
   (validation-text-storage :accessor validation-text-storage :initform "")
   (secure :accessor secure :initform nil :type boolean :documentation "If this is set to true, the text field will not show characters that are typed")
   (size :accessor size :initform 0.0 :initarg :size :type float :documentation "font size. 0.0 for default system font size"))
  (:documentation "editable text")
  (:default-initargs
    :text ""
    :width 100
    :height 20))


(defclass TEXT-VIEW-CONTROL (control)
  ((align :accessor align :initform :left :initarg :align :type keyword :documentation ":left, :center , :right, :justified")
   (size :accessor size :initform 0.0 :initarg :size :type float :documentation "font size. 0.0 for default system font size"))
  (:documentation "Text view")
  (:default-initargs
    :text ""
    :width 100
    :height 20))


(defmethod VALIDATE-TEXT-CHANGE ((self editable-text-control) text)
  "This Method is called whenever this editable-text-control's text changes, if this change is not acceptable this method should return nil and the old value will be restored"
  (declare (ignore text))
  ; Always return true by default
  t)


(defmethod VALIDATE-FINAL-TEXT-VALUE ((self editable-text-control) text)
  "This Method is called whenever this editable-text-control's text field is about to finish editing, if this change is not acceptable this method should return nil and the original value will be restored"
  (declare (ignore text))
  ; Always return true by default
  t)


(defmethod initialize-event-handling ((Self editable-text-control))
  ;; not clickable
  )


(defclass STATUS-BAR-CONTROL (control)
  ((align :accessor align :initform :left :initarg :align :type keyword :documentation ":left, :center , :right, :justified"))
  (:documentation "status bar")
  (:default-initargs
    :text ""
    :width 100
    :height 20))


(defmethod initialize-event-handling ((Self editable-text-control))
  ;; not clickable
  )

;__________________________________
; Progress Indicator               |
;__________________________________/

(defclass PROGRESS-INDICATOR-CONTROL (control)
  ((align :accessor align :initform :center :initarg :align :type keyword :documentation ":left, :center , :right, :justified"))
  (:documentation "This is a basic indeterminate progress indicator that will just show a busy progress bar.  This indicator is much simpler then the determinate progress indicator and must only be turned on and off.  ")
  (:default-initargs 
    :text ""
    :width 100
    :height 20))

;__________________________________
; Determinate Progress Indicator   |
;__________________________________/

(defclass DETERMINATE-PROGRESS-INDICATOR-CONTROL (control)
  ((align :accessor align :initform :center :initarg :align :type keyword :documentation ":left, :center , :right, :justified")
   (min-value :accessor min-value :initform 0.d0 :initarg :min-value :documentation "The min value of the determinate progress indicator")
   (max-value :accessor max-value :initform 100.d0 :initarg :max-value :documentation "The max value of the determinate progress indicator")
   )
  (:documentation "The determinate progress indicator must by incrimented from min-value to max-value using the increment-by method.  ")
  (:default-initargs 
    :text ""
    :width 100
    :height 20))

;__________________________________
; Image                             |
;__________________________________/

(defclass IMAGE-CONTROL (control)
  ((src :accessor src :initform nil :initarg :src :documentation "URL: so far only filename")
   (scale-proportionally :accessor scale-proportionally :initarg :scale-proportionally :type boolean :initform nil :documentation "If true the image will scale proportionally instead of scale to fit")
   (crop-to-fit :accessor crop-to-fit :initarg :crop-to-fit :type boolean :initform nil)
   (image-path :accessor image-path :initform nil :initarg :image-path :documentation "if this accesor is nil then the image-control will look for 
   the image in the resources;images directory, if not it will look for the src image at the location specified by this accessor")
   (downsample :accessor downsample :initform nil :type boolean :initarg :downsample :documentation "If true, downsample the actual Image file to the size of this image-control")
   (native-color :accessor native-color :initform nil))
  (:documentation "image. If size is 0,0 use original image size")
  (:default-initargs 
    :width 0
    :height 0))


(defgeneric SOURCE (image-control)
  (:documentation "If the src is local return a file specification"))


(defmethod SOURCE ((Self image-control))
  (if (image-path self)
    (native-path (image-path self) (src Self))
    (native-path "lui:resources;images;" (src Self))))


(defmethod initialize-event-handling ((Self image-control))
  ;; not clickable
  )

;__________________________________
; Image                             |
;__________________________________/

(defclass CLICKABLE-IMAGE-CONTROL (view)
  ((src :accessor src :initform nil :initarg :src :documentation "URL: so far only filename")
   (scale-proportionally :accessor scale-proportionally :initarg :scale-proportionally :type boolean :initform nil :documentation "If true the image will scale proportionally instead of scale to fit")
   (image-path :accessor image-path :initform nil :initarg :image-path :documentation "if this accesor is nil then the image-control will look for 
   the image in the resources;images directory, if not it will look for the src image at the location specified by this accessor")
   (downsample :accessor downsample :initform nil :type boolean :initarg :downsample :documentation "If true, downsample the actual Image file to the size of this image-control"))
  (:documentation "image. If size is 0,0 use original image size")
  (:default-initargs 
    :width 0
    :height 0))


(defgeneric SOURCE (clickable-image-control)
  (:documentation "If the src is local return a file specification"))


(defmethod SOURCE ((Self clickable-image-control))
  (if (image-path self)
    (native-path (image-path self) (src Self))
    (native-path "lui:resources;images;" (src Self))))

#|
(defmethod initialize-event-handling ((Self image-control))
  ;; not clickable
  )
|#

;__________________________________
; Color Well                       |
;__________________________________/

(defclass COLOR-WELL-CONTROL (control)
  ((color :accessor color :initform "FF0000" :type string :documentation "Hex RBB value for color e.g. FF0000 = RED")
   (show-alpha :accessor show-alpha :initform t :type boolean :documentation "If true include alpha controls in color picker")
   (user-action :accessor user-action :initform 'default-action2 :type symbol :documentation "The action that will be called once the default-action adjusts the color accessor"))
  (:default-initargs
      :text ""
    :action 'color-well-action)
  (:documentation "Color Well"))


(defmethod INITIALIZE-INSTANCE ((Self color-well-control) &rest Args)
  (declare (ignore Args))
  (call-next-method)
  (setf (user-action self) (action self))
  (setf (action self) 'color-well-action)
  (unless (target Self) (setf (target Self) Self)) ;; make me default target
  (initialize-event-handling Self))


(defgeneric GET-RED (color-well-control)
  (:documentation "Returns the red value of the RGB stored as a byte"))


(defgeneric GET-BLUE (color-well-control)
  (:documentation "Returns the blue value of the RGB stored as a byte"))


(defgeneric GET-GREEN (color-well-control)
  (:documentation "Returns the green value of the RGB stored as a byte"))


(defgeneric GET-ALPHA (color-well-control)
  (:documentation "Returns the alpha value stored as a byte"))


(defgeneric SET-COLOR (color-well-control &key Red Green Blue Alpha)
  (:documentation "Set the color of the color well"))


(defmethod COLOR-WELL-ACTION ((window window) (self COLOR-WELL-Control))
  (setf (color self) (concatenate 'string (write-to-string (get-red self) :base 16) (concatenate 'string (write-to-string (get-green self):base 16) (write-to-string (get-blue self):base 16))))
  (funcall (user-action self) window self))
  

;__________________________________
; Color Well Button                |
;__________________________________/

(defclass COLOR-WELL-BUTTON-CONTROL (control)
  ((color :accessor color :initform "FF0000" :type string :documentation "Hex RBB value for color e.g. FF0000 = RED")
   (show-alpha :accessor show-alpha :initform t :type boolean :documentation "If true include alpha controls in color picker")
   (user-action :accessor user-action :initform 'default-action2 :type symbol :documentation "The action that will be called once the default-action adjusts the color accessor"))
  (:default-initargs
      :text ""
    :action 'color-well-action)
  (:documentation "An alternative color well that will display the selected color in a button."))


(defmethod INITIALIZE-INSTANCE ((Self color-well-control) &rest Args)
  (declare (ignore Args))
  (call-next-method)
  (setf (user-action self) (action self))
  (setf (action self) 'color-well-action)
  (unless (target Self) (setf (target Self) Self)) ;; make me default target
  (initialize-event-handling Self))


(defgeneric GET-RED (color-well-control)
  (:documentation "Returns the red value of the RGB stored as a byte"))


(defgeneric GET-BLUE (color-well-control)
  (:documentation "Returns the blue value of the RGB stored as a byte"))


(defgeneric GET-GREEN (color-well-control)
  (:documentation "Returns the green value of the RGB stored as a byte"))


(defgeneric GET-ALPHA (color-well-control)
  (:documentation "Returns the alpha value stored as a byte"))


(defgeneric SET-COLOR (color-well-control &key Red Green Blue Alpha)
  (:documentation "Set the color of the color well"))


(defmethod COLOR-WELL-ACTION ((window window) (self COLOR-WELL-Control))
  (setf (color self) (concatenate 'string (write-to-string (get-red self) :base 16) (concatenate 'string (write-to-string (get-green self):base 16) (write-to-string (get-blue self):base 16))))
  (funcall (user-action self) window self))


;__________________________________
; Web                              |
;__________________________________/

(defclass WEB-BROWSER-CONTROL (control)
  ((URL :accessor URL :initform "http://www.agentsheets.com" :initarg :url :documentation "URL"))
  (:documentation "Web browser"))


(defmethod initialize-event-handling ((Self web-browser-control))
  ;; not clickable
  )


(defclass LINK-CONTROL (control)
  ((url :accessor url :initarg :url)
   (align :accessor align :initform :left :initarg :align :type keyword :documentation ":left, :center , :right, :justified")
   (size :accessor size :initform 0.0 :initarg :size :type float :documentation "font size. 0.0 for default system font size")
   (bold :accessor bold :initform nil :initarg :bold :type boolean :documentation "whether or not the label text is bold"))
  (:documentation "a link")
  (:default-initargs 
    :text "AgentSheets, Inc."
    :url "http://www.agentsheets.com"
    :width 100
    :height 20))


#| Examples:

;;***  EXAMPLE 1: a click and drag window containing a mouse controlled view

(defclass CLICK-AND-DRAG-WINDOW (window)
  ((blob :accessor blob :initform (make-instance 'rectangle-view))
   (drag-lag-rect :accessor drag-lag-rect :initform (make-instance 'rectangle-view))))


(defmethod INITIALIZE-INSTANCE :after ((Self click-and-drag-window) &rest Args)
  (declare (ignore Args))
  (set-color (blob Self) :red 0.5 :green 0.1)
  (set-frame (blob Self) :width 100 :height 100)
  (set-color (drag-lag-rect Self) :green 1.0)
  (set-frame (drag-lag-rect Self) :width 1 :height 1)
  (add-subviews Self (blob Self) (drag-lag-rect Self)))


(defmethod VIEW-LEFT-MOUSE-DOWN-EVENT-HANDLER ((Self click-and-drag-window) X Y)
  ;; (format t "click: x=~A, y=~A~%"  x y)
  (set-frame (blob Self) :x (- x 50) :y (- y 50)))


(defmethod  VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER ((Self click-and-drag-window) X Y dx dy)
  ;; (format t "click: x=~A, y=~A~%"  x y)
  (set-frame (blob Self) :x (- x 50) :y (- y 50))
  (set-frame (drag-lag-rect Self) :x (- x (abs dx) 3) :y (- y (abs dy) 3) 
             :width (abs dx) :height (abs dy)))


(defparameter *Window* (make-instance 'click-and-drag-window))


;;***  EXAMPLE 2: controls and targets
;; 3 buttons, red, green, and blue to switch the color of a view

;; define window and view subclasses

(defclass COLOR-SELECTION-WINDOW (window)
  ())


(defmethod INITIALIZE-INSTANCE :after ((Self color-selection-window) &rest Args)
  (declare (ignore Args))
  ;; make all views and link up the targets
  (let* ((Color-View (make-instance 'color-selection-view :y 50))
         (Red-Button (make-instance 'button-control :text "red" :target Color-View :action 'turn-red))
         (Green-Button (make-instance 'button-control :text "green" :x 100 :target Color-View :action 'turn-green))
         (Blue-Button (make-instance 'button-control :text "blue" :x 200 :target Color-View :action 'turn-blue)))
    (add-subviews Self Color-View Red-Button Green-Button Blue-Button)))


(defclass COLOR-SELECTION-VIEW (rectangle-view)
  ())

;; actions

(defmethod TURN-RED ((window color-selection-window) (view color-selection-view))
  (set-color View :red 1.0 :green 0.0 :blue 0.0)
  (display window))

(defmethod TURN-GREEN ((window color-selection-window) (view color-selection-view))
  (set-color View :red 0.0 :green 1.0 :blue 0.0)
  (display window))


(defmethod TURN-BLUE ((window color-selection-window) (view color-selection-view))
  (set-color View :red 0.0 :green 0.0 :blue 1.0)
  (display window))

;; done 

(defparameter *ColorWindow* (make-instance 'color-selection-window))

(do-subviews (View *ColorWindow*)
  (print View))

(map-subviews *ColorWindow* #'(lambda (view) (print View)))


;;*** EXAMPLE 3: sliders
;; Window with RGB sliders to adjust color

(defclass RGB-WINDOW (window)
  ((color-view :accessor color-view)
   (red-slider :accessor red-slider)
   (green-slider :accessor green-slider)
   (blue-slider :accessor blue-slider)
   (red-label :accessor red-label)
   (green-label :accessor green-label)
   (blue-label :accessor blue-label))
  (:default-initargs
      :width 200
    :height 200))


(defmethod initialize-instance :after ((Self rgb-window) &rest Args)
  (declare (ignore Args))
  ;; make slider views, target color view and use shared action method
  (setf (color-view Self) (make-instance 'color-view :y 100))
  (setf (red-slider Self) (make-instance 'slider-control :target (color-view Self) :x 50 :action 'adjust-color :max-value 1.0))
  (setf (green-slider Self) (make-instance 'slider-control :target (color-view Self) :x 50 :y 30 :action 'adjust-color :max-value 1.0))
  (setf (blue-slider Self) (make-instance 'slider-control :target (color-view Self) :x 50 :y 60 :action 'adjust-color :max-value 1.0))
  (add-subviews Self (color-view Self) (red-slider Self) (green-slider Self) (blue-slider Self))
  ;; add static labels
  (add-subviews 
   Self
   (make-instance 'label-control :text "red" :width 45)
   (make-instance 'label-control :text "green" :y 30 :width 45)
   (make-instance 'label-control :text "blue" :y 60 :width 45))
  ;; dynamic labels
  (setf (red-label Self) (make-instance 'label-control :text (format nil "~4,2F" (value (red-slider Self))) :x 160 :width 50))
  (setf (green-label Self) (make-instance 'label-control :text (format nil "~4,2F" (value (green-slider Self))) :x 160 :y 30 :width 50))
  (setf (blue-label Self) (make-instance 'label-control :text (format nil "~4,2F" (value (blue-slider Self))) :x 160 :y 60 :width 50))
  (add-subviews Self (red-label Self) (green-label Self) (blue-label Self)))


(defclass color-view (rectangle-view)
  ())

;; actions

(defmethod adjust-color ((window rgb-window) (view color-view))
  (set-color 
   view 
   :red (value (red-slider Window))
   :green (value (green-slider Window))
   :blue (value (blue-slider Window)))
  ;; update value labels
  (setf (text (red-label Window)) (format nil "~4,2F" (value (red-slider Window))))
  (setf (text (green-label Window)) (format nil "~4,2F" (value (green-slider Window))))
  (setf (text (blue-label Window)) (format nil "~4,2F" (value (blue-slider Window))))
  (display window))


(defparameter *RGB-Window* (make-instance 'rgb-window))


;*** EXAMPLE 4: Text

(defclass TEXT-WINDOW (window)
  ())


(defmethod initialize-instance :after ((Self text-window) &rest Args)
  (declare (ignore Args))
  (add-subviews Self (make-instance 'label-control :text "The quick brown fox jumps over the lazy dog" :width 500)))


(defparameter *text-window* (make-instance 'text-window))


;*** EXAMPLE 5: Modal Dialog

(defclass modal-window (window)
  ())


(defmethod initialize-instance :after ((Self modal-window) &rest Args)
  (declare (ignore Args))
  (add-subviews 
   Self
   (make-instance 'button-control :text "Cancel" :action 'cancel-action)
   (make-instance 'button-control :text "OK" :action 'OK-action :x 100)))


;; actions

(defmethod OK-action ((window modal-window) (button button-control))
  (stop-modal Window :ok))


(defmethod cancel-action ((window modal-window) (button button-control))
  (cancel-modal Window))



;; done 

(show-and-run-modal (make-instance 'modal-window :do-show-immediately nil :closeable nil))

|#