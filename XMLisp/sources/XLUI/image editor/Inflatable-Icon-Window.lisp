;;-*- Mode: Lisp; Package: AD3D -*-
;*********************************************************************
;*                                                                   *
;*    I N F L A T A B L E    I C O N   E D I T O R   W I N D O W     *
;*                                                                   *
;*********************************************************************
   ;* Author    : Alexander Repenning (alexander@agentsheets.com)    *
   ;*             http://www.agentsheets.com                         *
   ;* Copyright : (c) 1996-2010, AgentSheets Inc.                    *
   ;* Filename  : Inflatable-Icon-window.lisp                        *
   ;* Updated   : 08/16/07                                           *
   ;* Version   :                                                    *
   ;*    1.0    : 07/20/06                                           *
   ;*    1.1    : 01/04/07 Save/restore                              *
   ;*    1.2    : 05/30/07 Selection based inflation                 *
   ;*    1.2.1  : 08/16/07 if inflatable-icon has icon slot use      *
   ;*                       as image filename for image.             *
   ;*    2.0    : 02/09/10 CCL Cocoa version                         *
   ;* HW/SW     : G4, OS X 10.6.2, CCL 1.4                           *
   ;* Abstract  : Editor for inflatable icons                        *
   ;* Portable  : white                                              *
   ;*                                                                *
   ;******************************************************************

;; This file should move from XMLisp into AgentCubes

(in-package :xlui)
   

(defvar *ceiling-update-thread-should-stop* nil "Global variable that should be set if we want the ceiling update thread to stop, this can be used as a safe guard in case process-kill fails.")


 
;; Hack: this is a stop gap until we can develop a better locking mechanism.
(defvar *transparent-ceiling-update-lock* nil "Lock used to prevent annimation of ceilling fading to interfere with closing window")
                         

(defclass INFLATABLE-ICON-EDITOR-WINDOW (application-window)
  ((smoothing-cycles :accessor smoothing-cycles :initform 0 :initarg :smoothing-cycles)
   (selected-tool :accessor selected-tool :initform nil :type symbol :initarg :selected-tool :documentation "the name of the currently selected tool")
   (selected-camera-tool :accessor selected-camera-tool :initform nil :type symbol :initarg :selected-camera-tool :documentation "the name of the currently selected camera tool")
   (file :accessor file :initform nil :documentation "shape file")
   (destination-inflatable-icon :accessor destination-inflatable-icon :initform nil :initarg :destination-inflatable-icon :documentation "if present save edited icon into this inflatable icon")
   (close-action :accessor close-action :initform nil :initarg :close-action :documentation "called with self when inflatable icon window is being closed")
   (alert-close-action :accessor alert-close-action :initform nil :initarg :alert-close-action :documentation "The method that should be called when the window has closed, to alert the container of the closing")
   (alert-close-target :accessor alert-close-target :initform nil :initarg :alert-close-target :documentation "The target of the close-action, most likely the caller of the window.")
   (timer-triggers :accessor timer-triggers :initform nil :documentation "when to start TIME triggers")
   (ceiling-transparency :accessor ceiling-transparency :initform 0.0)
   (transparent-ceiling-starting-alpha :accessor transparent-ceiling-starting-alpha :initform .35 :documentation "The starting alpha value of the transparent ceiling.")
   (transparent-ceiling-decrement-value :accessor transparent-ceiling-decrement-value :initform .02 :documentation "The amount the transparent ceiling's alpha will be decremented by each time the timer is due. ")
   (transparent-ceiling-update-frequency :accessor transparent-ceiling-update-frequency :initform .02 :documentation "How often in seconds the transparency value will be udpated")
   (transparent-ceiling-should-fade :accessor transparent-ceiling-should-fade :initform nil :documentation "Fade will not begin until this is set.")
   (transparent-ceiling-update-process :accessor transparent-ceiling-update-process :initform nil :documentation "This process will update the transparency of the ceiling to cause a fade out when it is not used")
   (ceiling-process-should-stop-and-close-window-p :accessor ceiling-process-should-stop-and-close-window-p :initform nil :documentation "If true the ceiling update process should stop and then close the window")
   (command-manager :reader command-manager :initform (make-instance 'inflatable-icon-command-manager))
   (save-button-closure-action :accessor save-button-closure-action :initform nil :initarg :save-button-closure-action ))
  (:default-initargs
      :track-mouse t
    :resizable t
    )
  (:documentation "Editor used to create inflatable icons"))


(defmethod INITIALIZE-INSTANCE :after ((Self inflatable-icon-editor-window) &rest Args) 
  (declare (ignore Args))
  (setf (window (command-manager self)) self)
  (let ((Model-Editor (view-named self 'model-editor)))
    (if (is-upright (inflatable-icon Model-Editor))
      (enable (view-named self "upright"))))
  (set-cursor "drawCursor"))
  

(defun TRANSPARENT-CEILING-UPDATE-LOCK()
  ;; make lock if necessary
  (or *transparent-ceiling-update-lock*
    (setf *transparent-ceiling-update-lock* (ccl::make-lock))))


(defgeneric TOOL-SELECTION-EVENT (inflatable-icon-editor-window Tool-Name)
  (:documentation "called after tool has been selected"))


(defmethod TOOL-SELECTION-EVENT ((Self inflatable-icon-editor-window) Tool-Name)
  (setf (selection-in-progress (view-named self "icon-editor")) nil)
  (display (view-named self "icon-editor"))
  (setf (selected-tool Self) Tool-Name))


(defmethod CAMERA-TOOL-SELECTION-EVENT ((Self inflatable-icon-editor-window) Tool-Name)
  (setf (selected-camera-tool Self) Tool-Name))


(defmethod WINDOW-WILL-CLOSE ((Self inflatable-icon-editor-window) Notification)
  (declare (ignore Notification))
  (set-cursor "arrowCursor")
  (when (transparent-ceiling-update-process self)
    (setf *ceiling-update-thread-should-stop* t)
    (setf (transparent-ceiling-update-process self) nil))
  (when (and (alert-close-action self) (alert-close-target self))
    (ccl::with-lock-grabbed ((transparent-ceiling-update-lock))
      (funcall (alert-close-action self) (alert-close-target self) self))))


(defmethod KEY-EVENT-HANDLER ((Self inflatable-icon-editor-window) Event)
  (declare (ftype function redo-command undo-command))
  (let ((Icon-Editor (view-named Self 'icon-editor))
        (Inflatable-Icon (inflatable-icon (or (view-named (window self) 'model-editor) (error "model editor missing")))))
    (cond
   ((and (command-key-p) (shift-key-p))
      (case (key-code Event)
        (#.(key-name->code "Z")
           (redo-command (command-manager self)))))
   ((command-key-p)
    (case (key-code Event)
      (#.(key-name->code "Z")
         (undo-command (command-manager self)))
      (#.(key-name->code "A")
         (select-all Icon-Editor))
      (#.(key-name->code "D")
         (clear-selection Icon-Editor))
      (#.(key-name->code "I")
         (invert-selection Icon-Editor))))
   ((lui::alt-key-p)
    (case (key-code Event)
      
      (37
       (let ((path  (lui::choose-file-dialog :directory "lui:resources;textures;")))
         (when path 
           (load-image-from-file Self path))))
      #|
      (37
       (lui::in-main-thread ()
       (setup-icon-editor-with-image-at-path self (namestring (lui::choose-file-dialog :directory "lui:resources;textures;")) :shape-filename "index"))
       (inspect self)
       )
      |#
      (#.(key-name->code "delete")
       (fill-selected-pixels icon-editor))))
   (t
    (case (key-code Event)
      (#.(key-name->code "up arrow")
         (nudge-selection-up icon-editor))
      (#.(key-name->code "down arrow")
         (nudge-selection-down icon-editor))
      (#.(key-name->code "right arrow")
         (nudge-selection-right icon-editor))
      (#.(key-name->code "left arrow")
         (nudge-selection-left icon-editor))
      (#.(key-name->code "delete")
         (erase-selected-pixels icon-editor)))))
    (when (and (is-flat inflatable-icon) (texture-id inflatable-icon))
      ;; Force the creation of a new texture
      (update-texture-from-image inflatable-icon))
    (display (view-named self 'model-editor))))


(defmethod DOCUMENT-DEFAULT-DIRECTORY ((Self inflatable-icon-editor-window)) "
  out: Pathname
  When loading saving: where to look first."
  (when (file Self)
    (make-pathname :name nil :type nil :defaults (file Self))))


(defmethod WINDOW-CLOSE-EVENT-HANDLER ((Self inflatable-icon-editor-window))
  (close-window-with-warning Self))


(defmethod WINDOW-SHOULD-CLOSE ((Self inflatable-icon-editor-window))
  (ccl::with-lock-grabbed ((transparent-ceiling-update-lock))
  (when (window-needs-saving-p self)
    (let ((cancelled t)
          (yes-no-return-val nil))
      (lui::bring-to-front self)
      (catch :cancel
        (setf yes-no-return-val 
              (xlui::standard-alert-dialog (format nil "Are you sure you want to close the window ~A?" (title self))
                                           :explanation-text "Your inflatable icon is unsaved and any unsaved changes will be lost." 
                                           :yes-text    "Save" 
                                           :no-text     "Don't Save" 
                                           :cancel-text "Cancel"))
        (setf cancelled nil))
      (cond 
       (cancelled
        (return-from window-should-close nil))
       (yes-no-return-val
        ;; This will close the window
        (edit-icon-save-action self (make-instance 'button) :close-window nil) )
       (t
        (cond
         ((transparent-ceiling-update-process self)
          (setf (ceiling-process-should-stop-and-close-window-p self) t)
          (return-from window-should-close nil))
         (t
          (return-from window-should-close t)))))))
    (cond
     ((transparent-ceiling-update-process self)
      (setf (ceiling-process-should-stop-and-close-window-p self) t)
      nil)
      (t
       t))))
  
#|
(defmethod WINDOW-CLOSE ((Self inflatable-icon-editor-window))
  (when (window-should-close self)
    (set-cursor "arrowCursor")
    (hide self)
    (return-from window-close t))
  nil)


(defmethod WINDOW-CLOSE-DONT-HIDE ((Self inflatable-icon-editor-window))
  (when (window-should-close self)
    (window-will-close self nil)
    (close-with-no-questions-asked self)
    (return-from window-close-dont-hide t))
  nil)
|#


(defmethod SELECT-ALL ((Self inflatable-icon-editor-window))
  (select-all (view-named Self 'icon-editor)))


(defmethod VIEW-KEY-EVENT-HANDLER ((Self inflatable-icon-editor-window) Key)
  "Called when a key is typed while the image-editor-window has keyboard focus."
  (let ((Icon-Editor (view-named Self 'icon-editor)))
    (cond
     ((command-key-p)
      (case Key
        (#\l (load-image-from-file Self (choose-file-dialog :directory "lui:resources;textures;")))
        (#\a (select-all Icon-Editor))
        (#\d (clear-selection Icon-Editor))
        (#\I (invert-selection Icon-Editor))))
     (t
      (case Key
        (#\ESC (close-window-with-warning Self))
        (#\Delete 
         (cond
          ((lui::alt-key-p)
           (fill-selected-pixels Icon-Editor)
           (image-changed-event Icon-Editor))
          (t
           (erase-selected-pixels Icon-Editor)
           (image-changed-event Icon-Editor)))))))
    (call-next-method)))


(defmethod UPDATE-INFLATION ((Self inflatable-icon-editor-window))
  ;; need to update model editor
  (ccl::with-autorelease-pool
  (let ((Icon-Editor (or (view-named Self 'icon-editor) (error "icon editor missing")))
        (Model-Editor (or (view-named Self 'model-editor) (error "model editor missing"))))
    (let ((Inflatable-Icon (inflatable-icon Model-Editor)))
      ;; make sure model and icon editor image buffers are aligned
      (unless (image Inflatable-Icon)
        (get-rgba-color-at Icon-Editor 0 0)   ;; hack: make sure pixel buffer exists by accessing it once
        (setf (image Inflatable-Icon)
              (pixel-buffer Icon-Editor)))
      (labels ((pixel-selected-p-fn (Row Column) 
                 (or (not (selection-outline Icon-Editor))
                     (pixel-selected-p 
                      (selection-mask Icon-Editor)
                      Column
                      (- (height (selection-mask Icon-Editor)) Row)))))
        ;; inflate
        (inflate
         Inflatable-Icon
         :steps 10
         :pressure (pressure Inflatable-Icon)
         :max (- (max-value Inflatable-Icon) (distance Inflatable-Icon)  (value (view-named self "z_slider"))#|(if (>  (value (view-named self "z_slider"))0.0) (value (view-named self "z_slider")) 0.0) |#)
         :inflate-pixel-p-fn #'pixel-selected-p-fn)
        ;; introduce noise
        (inflate
         Inflatable-Icon
         :steps 1
         :pressure (pressure Inflatable-Icon)
         :max (- (max-value Inflatable-Icon) (distance Inflatable-Icon)  (value (view-named self "z_slider"))#|(if (>  (value (view-named self "z_slider"))0.0) (value (view-named self "z_slider")) 0.0) |#);(max-value Inflatable-Icon)
         :noise (noise Inflatable-Icon)
         :inflate-pixel-p-fn #'pixel-selected-p-fn)
        (dotimes (I (smoothing-cycles Self))
          (inflate
           Inflatable-Icon
           :steps 1
           :pressure (pressure Inflatable-Icon)
           :max (- (max-value Inflatable-Icon) (distance Inflatable-Icon)  (value (view-named self "z_slider"))#|(if (>  (value (view-named self "z_slider"))0.0) (value (view-named self "z_slider")) 0.0) |#);(max-value Inflatable-Icon)
           :inflate-pixel-p-fn #'pixel-selected-p-fn))
        #|
        (format t "~%Pressure ~A, altitutes, average  ~A, max ~A" 
        (pressure Inflatable-Icon)
        (average-altitude Inflatable-Icon :inflate-pixel-p-fn #'pixel-selected-p-fn)
                (maximum-altitude Inflatable-Icon :inflate-pixel-p-fn #'pixel-selected-p-fn))
        |#
        ;; update 
        (display Model-Editor))
      ;(adjust-ceiling-action self (view-named self "ceiling_slider"))
      (when (>= (maximum-altitude inflatable-icon) (ceiling-value Inflatable-Icon))
        (setf (ceiling-process-should-stop-and-close-window-p self) nil)
        (setf (ceiling-transparency self) (transparent-ceiling-starting-alpha self))
        (setf (transparent-ceiling-should-fade self) nil)
        (unless (transparent-ceiling-update-process self)
          (setf *ceiling-update-thread-should-stop* nil)
          (setf (transparent-ceiling-update-process self)
          (lui::process-run-function
         '(:name "transparent ceiling update process")
         #'(lambda ()
             (loop
               (catch-errors-nicely ("inflatable ceilling is animating")
                 (when *Ceiling-Update-Thread-Should-Stop*  (return))
                 (when (ceiling-process-should-stop-and-close-window-p self)  (return))
                 (unless (or (transparent-ceiling-should-fade self)
                             (not (timer-due-p self (truncate (* 2.0 internal-time-units-per-second)))))
                   (setf (transparent-ceiling-should-fade self) t))
                 (when (transparent-ceiling-should-fade self)
                   (ccl::with-lock-grabbed ((transparent-ceiling-update-lock))
                     (update-ceiling-transparency self)))
                 (sleep .04)))
             (when (ceiling-process-should-stop-and-close-window-p self) (close-with-no-questions-asked self))))))))))
  )


(defmethod LOAD-IMAGE-FROM-FILE ((Self inflatable-icon-editor-window) Pathname)
  "Loads the specified image file into the editor window."

    (multiple-value-bind (image-data #|height width bytes-per-pixel|#)
                         (lui::CREATE-IMAGE-DATA-OF-SIZE-FROM-FILE Pathname 32 32)    
      (load-image-from-data self image-data)))


(defmethod CAMERA-BUTTON-ACTION ((Self inflatable-icon-editor-window) button)
  (ccl::get-image-from-camera-for-window (ccl::get-picture-taker) self 'load-image-from-camera :return-ns-image-instead-of-file-path t))


(defmethod LOAD-IMAGE-FROM-DATA ((self inflatable-icon-editor-window) image-data)
  (let ((image-editor  (view-named self 'icon-editor)))
    (with-glcontext image-editor
      ; (setf (pixel-buffer image-editor) image-data)
      (dotimes (i 32)
        (dotimes (j 32)
          (let* ((offset (image-byte-offset image-editor i j))
                 (red  (get-byte image-data offset))
                 (green  (get-byte image-data (+ 1 offset)))
                 (blue  (get-byte image-data (+ 2 offset)))
                 (alpha  (get-byte image-data (+ 3 offset))))
            (set-rgba-color-at-without-gl-context image-editor i j red green blue alpha)
            ;(with-rgba-byte-vector &color (Red Green Blue Alpha)
            ;(glBindTexture GL_TEXTURE_2D (img-texture image-editor))
            ;(glTexSubImage2D GL_TEXTURE_2D 0 j (- (img-height image-editor) i 1) 1 1 GL_RGBA GL_UNSIGNED_BYTE &color)
            
            #|
            (let ((Byte-Offset (image-byte-offset image-editor i j)))
            (when (> Byte-Offset (sizeof (pixel-buffer image-editor))) (error "out of range"))
            (set-byte (pixel-buffer image-editor) Red Byte-Offset)
            (set-byte (pixel-buffer image-editor) Green (+ Byte-Offset 1))
            (set-byte (pixel-buffer image-editor) Blue (+ Byte-Offset 2))
            (set-byte (pixel-buffer image-editor) Alpha (+ Byte-Offset 3)))
            |#
            
            ;)
            )))
      (compute-connectors (inflatable-icon (view-named self 'model-editor)))
      (display self)
      )))


(defmethod LOAD-IMAGE-FROM-CAMERA ((Self inflatable-icon-editor-window) image)
  (when image
    (multiple-value-bind (image-data #|height width bytes-per-pixel|#)
                         (lui::CREATE-IMAGE-DATA-OF-SIZE-FROM-IMAGE image 32 32)   
      
      (load-image-from-data self image-data)
      (let* ((model-editor (view-named self 'model-editor))
             (inflatable-icon (inflatable-icon model-editor)))
        (compute-connectors inflatable-icon) 
        
        (when (and (is-flat inflatable-icon) (texture-id inflatable-icon))
          ;; Force the creation of a new texture
          (update-texture-from-image inflatable-icon))
        
        (display  model-editor)
        ))))

(defmethod SAVE-IMAGE-TO-FILE ((Self inflatable-icon-editor-window) Pathname)
  "Saves the current image in the editor window to the specified file."
  (save-image (image-editor-view Self) Pathname))

;______________________________________________
; File menu support                            |
;______________________________________________

(defmethod DOCUMENT-TYPE-NAME ((Self inflatable-icon-editor-window))
  "inflatable icon")


(defmethod DOCUMENT-TYPE-FILE-EXTENSION ((Self inflatable-icon-editor-window))
  "shape")


#|
(defmethod WINDOW-NEEDS-SAVING-P ((Self inflatable-icon-editor-window))
  t)
|#


(defmethod IMAGE-FILE-NAME ((Self inflatable-icon-editor-window))
  (when (file Self)
    (format nil "~A.png" (pathname-name (file Self)))))


(defmethod IMAGE-FILE ((Self inflatable-icon-editor-window))
  (when (file Self)
    ;; allow icon of inflatable icon to overwrite the default image file name+extension
    (make-pathname
     :directory (pathname-directory (file Self))
     :name (pathname-name (file Self))
     :type "png"
     :host (pathname-host (file Self))
     :defaults (file Self))))


(defmethod WINDOW-FILENAME ((Self inflatable-icon-editor-window))
  ;; needed for proxy icons
  (file Self))


(defmethod WINDOW-SAVE-AS ((Self inflatable-icon-editor-window) &optional External-Format)
  (declare (ignore External-Format))

  (let ((File  #-windows-target (easygui::choose-new-file-dialog  ;; HACK
                                 ;;; :name (format nil "untitled.~A" (document-type-file-extension Self))
                                 ;;; :window-title (format nil "Save ~A As:" (document-type-name Self))
                                 :directory (document-default-directory Self))
               #+windows-target "image999.png"))
    (setf (file Self) File)
    ;;   (setf (icon (document-root Self)) (image-file-name Self))     ;; set icon attribute
    ;;   (store-window-state-in-document-root Self)
    ;;   (save-object (document-root Self) File :if-exists :error)
    ;;   (add-window-proxy-icon Self File)
    ;; set file to this new file
    ;;   (setf (window-needs-saving-p Self) nil)
    (save-image (view-named Self 'icon-editor) (image-file Self))))


(defmethod WINDOW-SAVE ((Self inflatable-icon-editor-window))
  (cond
   ;; saved before
   ((file Self) 
    ;;    (call-next-method)
    (save-image (view-named Self 'icon-editor) (image-file Self))  ;; save image
    ;;    (store-window-state-in-document-root Self)
    ;;    (save-object (document-root Self) (file Self) :if-exists :supersede)
    )
   ;; never saved
   (t 
    ;; indirectly call window save as
    (window-save-as Self))))

  

;***********************************************
; XMLisp GUI Components                        *
;***********************************************

;________________________________________________
;  Icon Editor                                   |
;________________________________________________

(defclass ICON-EDITOR (image-editor)
  ((action :accessor action :initform 'control-default-action :initarg :action :type symbol :documentation "method by this name will be called on the window containing control and the target of the control"))
  (:default-initargs
    :x 0
    :y 0
    :width 200
    :height 200)
  (:documentation "Edit icons with me"))


(defmethod INSTALL-VIEW-IN-WINDOW :after ((Self icon-editor) Window)
  (declare (ignore Window))
  ;; center camera straight over image
  (setf (camera Self) 
        (duplicate <camera eye-x="0.0" eye-y="0.0" eye-z="1.7379" 
                   center-x="0.0" center-y="0.0" center-z="0.0" 
                   up-x="0.0" up-y="1.0" up-z="0.0" fovy="60.0" 
                   near="0.005" far="2000.0" azimuth="0.0" zenith="0.0"/>
                   (find-package :xlui)))
  (setf (view (camera Self)) Self)
  ;(setf (Tracking-rect self) (add-tracking-rect self))
  (prepare-opengl Self)
  ;; create the texture
  (new-image Self (img-width Self) (img-height Self)))


(defmethod PRINT-SLOTS ((Self icon-editor))
  '(img-height img-width))


(defmethod IMAGE-CHANGED-EVENT ((Self icon-editor) &optional Column1 Row1 Column2 Row2)
  (declare (ignore Column1 Row1 Column2 Row2))
  (invoke-action Self))


(defmethod VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER ((Self icon-editor) X Y DX DY)
  (declare (ignore X y dx dy))
  (call-next-method)
  (case (selected-tool (window self))
    ((or draw erase paint-bucket)
     (let ((Inflatable-Icon (inflatable-icon (or (view-named (window self) 'model-editor) (error "model editor missing")))))
       (when (equal (surfaces inflatable-icon) 'xlui::front-and-back-connected)
         (compute-connectors inflatable-icon))
       (when (and (is-flat inflatable-icon) (texture-id inflatable-icon))
         ;; Force the creation of a new texture
         (update-texture-from-image inflatable-icon)))
     (display (view-named (Window self) 'model-editor)))
    (t 
     (display (view-named (Window self) 'model-editor)))))


(defmethod VIEW-LEFT-MOUSE-DOWN-EVENT-HANDLER ((Self icon-editor) X Y)
  (declare (ignore X y))
  (call-next-method)
  (case (selected-tool (window self))
    ((or draw erase paint-bucket)
     (let ((Inflatable-Icon (inflatable-icon (or (view-named (window self) 'model-editor) (error "model editor missing")))))
       (when (equal (surfaces inflatable-icon) 'xlui::front-and-back-connected)
         (compute-connectors inflatable-icon))
       (when (and (is-flat inflatable-icon) (texture-id inflatable-icon))
         ;; Force the creation of a new texture
         (update-texture-from-image inflatable-icon)))
     (display (view-named (Window self) 'model-editor)))
    (t 
     (display (view-named (Window self) 'model-editor)))))

#|
(defmethod VIEW-LEFT-MOUSE-UP-EVENT-HANDLER ((Self icon-editor) X Y)
  (let ((Inflatable-Icon (inflatable-icon (or (view-named (window self) 'model-editor) (error "model editor missing")))))
    (when (equal (surfaces inflatable-icon) 'xlui::front-and-back-connected)
      (compute-connectors inflatable-icon))))
|#
;_______________________________________________
;  Lobster Icon Editor                           |
;________________________________________________


(defclass LOBSTER-ICON-EDITOR (icon-editor)
  ()
  (:documentation "Demo specific Lobster icon"))


(defmethod INSTALL-VIEW-IN-WINDOW :after ((Self lobster-icon-editor) Window)
  (declare (ignore Window))
  ;; center camera straight over image
  (setf (camera Self) 
        (duplicate <camera eye-x="0.0" eye-y="0.0" eye-z="1.7379" 
                   center-x="0.0" center-y="0.0" center-z="0.0" 
                   up-x="0.0" up-y="1.0" up-z="0.0" fovy="60.0" 
                   near="0.005" far="2000.0" azimuth="0.0" zenith="0.0"/>
                   (find-package :xlui)))
  (setf (view (camera Self)) Self)
  (prepare-opengl Self)
  ;; create the texture
  (load-image Self "ad3d:resources;images;redlobster.png"))


;________________________________________________
;  Inflated-Icon-Editor                          |
;________________________________________________

(defclass INFLATED-ICON-EDITOR (opengl-dialog)
  ((inflatable-icon :accessor inflatable-icon :initarg :inflatable-icon))
  (:default-initargs
    :use-global-glcontext t
    :inflatable-icon (make-instance 'inflatable-icon :auto-compile nil))
  (:documentation "3d inflated icon editor"))


(defmethod PREPARE-OPENGL ((Self inflated-icon-editor))
  (call-next-method)
  (glShadeModel gl_smooth)
  ;; define material
  (glmaterialfv gl_front_and_back gl_specular {0.5 0.5 0.5 0.0})
  (glmaterialf gl_front_and_back gl_shininess 20.0)
  (glmaterialfv gl_front_and_back gl_ambient_and_diffuse {1.0 1.0 1.0 1.0})
  ;; light
  (gllightfv gl_light0 gl_position {0.0 5.0 5.0 1.0})
  (gllightfv gl_light0 gl_diffuse {1.0 1.0 1.0 1.0})
  (gllightfv gl_light0 gl_specular {1.0 1.0 1.0 1.0})
  ;; enablers
  (glenable gl_lighting)
  (glenable gl_light0)
  (glenable gl_depth_test)
  ;; alpha
  (glEnable gl_blend)
  (glBlendFunc gl_src_alpha gl_one_minus_src_alpha)
  ;; Transparency Hack for low alpha values http://www.opengl.org/wiki/Transparency_Sorting
  (glAlphaFunc GL_GREATER 0.1)
  (glEnable GL_ALPHA_TEST)
  ;; top down 45 degree angle view
 
  (setf (view (camera Self)) Self))


(defmethod INITIALIZE-LAYOUT :after ((Self inflated-icon-editor))
  ;; initialize based on values of icon-editor
  (let ((Icon-Editor (view-named (window Self) 'icon-editor)))
    (unless Icon-Editor (error "cannot find Icon Editor"))
    ;; (setf (image (inflatable-icon Self)) (pixel-buffer Icon-Editor))
    (setf (altitudes (inflatable-icon Self))
          (make-array (list (img-height Icon-Editor) (img-width Icon-Editor))
                      :element-type 'short-float
                      :initial-element 0s0))))
  
(defmethod INITIALIZE-INSTANCE :after ((Self inflated-icon-editor) &rest Args)
  (declare (ignore Args))
  (when (camera self)
    (setf (camera Self)
          (duplicate <camera eye-x="-0.6211211173151155" eye-y="1.1633405705811566" eye-z="1.503611410725895" 
                     center-x="0.0" center-y="0.0" center-z="0.0" 
                     up-x="0.881440029667134" up-y="-1.6509098120484733" up-z="0.418499485826859149" fovy="60.0" 
                     near="0.005" far="2000.0" azimuth="-3.6320001408457756" zenith="0.7200000360608101"/>
                     (find-package :xlui)))))


(defmethod DRAW-SKY-BOX ((Self inflated-icon-editor))
  (glpushmatrix)
  (glenable gl_texture_2d)
  (glEnable gl_cull_face) ;; cull to see through walls
  (gltexenvi gl_texture_env gl_texture_env_mode gl_modulate)
  (use-texture Self "floorTile.png")
  (gltexparameteri gl_texture_2d gl_texture_wrap_s gl_repeat)
  (gltexparameteri gl_texture_2d gl_texture_wrap_t gl_repeat)
  (glRotatef 90.0 1.0 0.0 0.0)
  (glbegin gl_quads)
  ;; floor
  (glnormal3f 0.0 1.0 0.0)
  (gltexcoord2f 0s0 0s0) (glvertex3f -1s0 0s0 -1s0)
  (gltexcoord2f 0s0 10s0) (glvertex3f -1s0 0s0 1s0)
  (gltexcoord2f 10s0 10s0) (glvertex3f  1s0 0s0 1s0)
  (gltexcoord2f 10s0 0s0) (glvertex3f  1s0 0s0 -1s0)
  ;; wall 1
  (glnormal3f 0.0 0.0 1.0)
  (gltexcoord2f 10.0 0.0) (glvertex3f  1s0 0s0 -1s0)
  (gltexcoord2f 10.0 10.0) (glvertex3f  1s0  2s0 -1s0)
  (gltexcoord2f 0.0 10.0) (glvertex3f -1s0  2s0 -1s0)
  (gltexcoord2f 0.0 0.0) (glvertex3f -1s0 0s0 -1s0)
  ;; wall 2
  (glnormal3f 0.0 0.0 -1.0)
  (gltexcoord2f 0.0 0.0) (glvertex3f -1s0 0s0 1.0)
  (gltexcoord2f 0.0 10.0) (glvertex3f -1s0  2s0 1.0)
  (gltexcoord2f 10.0 10.0) (glvertex3f  1s0  2s0 1.0)
  (gltexcoord2f 10.0 0.0) (glvertex3f  1s0 0s0 1.0)
  ;; wall 3
  (glnormal3f  -1.0 0.0 0.0)
  (gltexcoord2f 0s0 0s0) (glvertex3f 1s0 0s0 -1s0)
  (gltexcoord2f 0s0 10s0) (glvertex3f 1s0 0s0  1s0)
  (gltexcoord2f 10s0 10s0) (glvertex3f 1s0 2s0  1s0)
  (gltexcoord2f 10s0 0s0) (glvertex3f 1s0 2s0 -1s0)
  ;; wall 4
  (glnormal3f  1.0 0.0 0.0)
  (gltexcoord2f 10s0 0s0) (glvertex3f -1s0 2s0 -1s0)
  (gltexcoord2f 10s0 10s0) (glvertex3f -1s0 2s0  1s0)
  (gltexcoord2f 0s0 10s0) (glvertex3f -1s0 0s0  1s0)
  (gltexcoord2f 0s0 0s0) (glvertex3f -1s0 0s0 -1s0)
  (glend)
  (glpopmatrix)
  (glDisable gl_cull_face))


(defmethod DRAW ((Self inflated-icon-editor)) 
  (glClearColor 0.9 0.9 0.9 1.0) 
  (glClear (logior GL_COLOR_BUFFER_BIT gl_depth_buffer_bit))
  (draw-sky-box Self)
  ;; floor
  (glpushmatrix)
  (glTranslatef -0.5s0 -0.5s0 0.0s0)
  ;(glRotatef -90s0 1.0s0 0.0s0 0.0s0)
  (draw (inflatable-icon Self))
  (glpopmatrix)
  (use-texture self "whiteBox.png")
  (if (<=  (ceiling-transparency (window self)) 0.0)
    ;; if it is fully transparent kill the process if it is still runnning
    (when (transparent-ceiling-update-process (window self))
      (setf *ceiling-update-thread-should-stop* t)
      (Setf (transparent-ceiling-update-process (window self)) nil))
    (progn
      ;; draw the transparent ceiling
      (let ((ceiling-height (+ .02 *flat-shape-z-offset* (max-value (inflatable-icon (view-named (Window self) 'model-editor)))))
            (z-offset (value (view-named (Window self) "z_slider"))))
        (glpushmatrix)
        ;(value (view-named (Window self) "z_slider"))
        (case (surfaces (inflatable-icon (view-named (window self) 'model-editor)))
          ((or front-and-back front-and-back-connected)
           (if (is-upright (inflatable-icon (view-named (Window self) 'model-editor)))
             (progn
               (glTranslatef 0.0s0 0.0s0 1.0s0)
               ;(glRotatef 90s0 1.0s0 0.0s0  0.0s0 )
               (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
               (glscalef 1s0 -1s0 1s0)
               (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
               )
             (progn
               (glRotatef 90s0 1.0s0 0.0s0  0.0s0 )
               (draw-ceiling-quad (ceiling-transparency (window self)) ceiling-height)
               (glscalef 1s0 -1s0 1s0)
               (draw-ceiling-quad (ceiling-transparency (window self)) (- ceiling-height (* 2 (value (view-named (Window self) "z_slider")) ))))))
          (cube 
           (when (is-upright (inflatable-icon (view-named (Window self) 'model-editor)))
             (glTranslatef 0.0s0 0.5s0 0.0s0))
           (glTranslatef 0.0s0 -0.5s0 0.5s0)
           ;(glTranslatef 0.0s0  (Value (view-named (Window self) "z_slider")) 0.0s0)
           ;;top
           (draw-ceiling-quad (ceiling-transparency (window self)) ceiling-height)
           ;;bottom
           (glpushmatrix)
           (glscalef 1s0 -1s0 1s0)
           (glTranslatef 0.0s0 (* -2.0 z-offset) 0.0s0)
           (draw-ceiling-quad (ceiling-transparency (window self)) ceiling-height)
           (glpopmatrix)
           ;;Right side (when window opens)
           (glpushmatrix)
           (glTranslatef 0.0s0  (Value (view-named (Window self) "z_slider")) 0.0s0)
           (glRotatef -90s0 0.0s0 0.0s0  1.0s0 )
           (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
           (glpopmatrix)
           ;;Left side (when window opens)
           (glpushmatrix)
           (glTranslatef 0.0s0  (Value (view-named (Window self) "z_slider")) 0.0s0)
           (glRotatef 90s0 0.0s0 0.0s0  1.0s0 )
           
           (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
           (glpopmatrix)
           ;; Front (when window opens)
           (glpushmatrix)
           (glTranslatef 0.0s0  (Value (view-named (Window self) "z_slider")) 0.0s0)
           (glRotatef 90s0 1.0s0 0.0s0  0.0s0 )
           (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
           (glpopmatrix)
           ;; back (when window opens)
           (glpushmatrix)
           (glTranslatef 0.0s0  (Value (view-named (Window self) "z_slider")) 0.0s0)
           (glRotatef 90s0 -1.0s0 0.0s0  0.0s0 )
           (draw-ceiling-quad (ceiling-transparency (window self)) (-  ceiling-height z-offset))
           (glpopmatrix))
          (t 
           (if (is-upright (inflatable-icon (view-named (Window self) 'model-editor)))
             (progn
               ;(glTranslatef 0.0s0 1.0s0 0.0s0)
               (glTranslatef 0.0s0 0.0s0 1.0s0)
               (glscalef 1s0 -1s0 1s0)
               (draw-ceiling-quad (ceiling-transparency (window self)) (+ 0.0  (-  ceiling-height z-offset))))
             (progn
               (glRotatef 90s0 1.0s0 0.0s0  0.0s0 )
               (draw-ceiling-quad (ceiling-transparency (window self)) (+ 0.0  ceiling-height))))))
        (glpopmatrix)
        (glEnable GL_DEPTH_TEST) 
        (glColor4f 1.0 1.0 1.0 1.0)))))


(defun DRAW-CEILING-QUAD (ceiling-transparency ceiling-height)

  (glColor4f .5 .7 1.0 ceiling-transparency )
  (glbegin gl_quads)
  (glnormal3f 0.0 1.0 0.0)
  (gltexcoord2f 0s0 0s0) (glvertex3f -1s0 ceiling-height -1s0)
  (gltexcoord2f 0s0 10s0) (glvertex3f -1s0 ceiling-height 1s0)
  (gltexcoord2f 10s0 10s0) (glvertex3f  1s0 ceiling-height 1s0)
  (gltexcoord2f 10s0 0s0) (glvertex3f  1s0 ceiling-height -1s0)
  (glend)
  ;; grid
  (glColor4f 1.0 1.0 0.0 ceiling-transparency )
  (glBegin GL_LINES)
  (loop for i from -1.0 to 1.0 by .2 do
    (glVertex3f i (+ .01 ceiling-height) -1.0)
    (glVertex3f i (+ .01 ceiling-height) 1.0))
  (loop for j from -1.0 to 1.0 by .2 do
    (glVertex3f -1.0 (+ .01 ceiling-height) j)
    (glVertex3f 1.0 (+ .01 ceiling-height) j))
  (glEnd))


(defmethod VIEW-CURSOR ((Self inflated-icon-editor) x y)
  (declare (ignore x y))
  (case (selected-camera-tool (window Self))
    (zoom "zoomCursor")
    (pan "panCursor")
    (rotate "rotateCursor")))

;*************************************************
;  Event Handlers                                *
;*************************************************

(defmethod VIEW-LEFT-MOUSE-DRAGGED-EVENT-HANDLER ((Self inflated-icon-editor) X Y DX DY)
  (declare (ignore X Y))
  (case (selected-camera-tool (window Self))
    (pan
     (track-mouse-pan (camera Self) dx dy (if (shift-key-p) 0.01 0.05)))
    (zoom
     (track-mouse-zoom (camera Self) dx dy (if (shift-key-p) 0.01 0.05)))
    (t
     (track-mouse-3d (camera Self) Self dx dy)))
  (unless (is-animated Self) (display Self)))


(defmethod VIEW-MOUSE-SCROLL-WHEEL-EVENT-HANDLER ((Self inflated-icon-editor) x y dx dy)
  (declare (ignore x y))
  (with-animation-locked
      (track-mouse-pan (camera Self) dx dy 0.0005)
    (display Self)))


(defmethod GESTURE-MAGNIFY-EVENT-HANDLER ((Self inflated-icon-editor) x y Magnification)
  (declare (ignore x y))
  (with-animation-locked
      (track-mouse-zoom (camera Self) 0 Magnification -2.0)
    (display Self)))


(defmethod GESTURE-ROTATE-EVENT-HANDLER ((Self inflated-icon-editor) x y Rotation)
  (declare (ignore x y))
  (with-animation-locked
      (track-mouse-spin (camera Self) Rotation 0.0 +0.2)
    (display Self)))


(defmethod VIEW-MOUSE-EXITED-EVENT-HANDLER ((Self inflated-icon-editor))
  (set-cursor "arrowCursor"))


;*************************************************
;  Specialized Controls                          *
;*************************************************

(defclass INFLATION-JOG-BUTTON (jog-button)
  ((initial-time :accessor initial-time :initform nil :documentation "The time when this jog button was lasted started")
   (time-of-last-text-update :accessor time-of-last-text-update :initform nil :documentation "The last time the pressure text was updated")
   (pressure-ramp-delay :accessor pressure-ramp-delay :initform .25 :documentation "The number of seconds before the pressure will begin to ramp up")
   (initial-pressure-per-cycle :accessor initial-pressure-per-cycle :initform .001 :documentation "The amount the pressure will be incremented or decremented by each cycle before the ramp begins")
   (pressure-per-cycle :accessor pressure-per-cycle :initform nil :documentation "The amount that the pressure is actually increased by each cycle")
   (max-pressure-per-cycle :accessor max-pressure-per-cycle :initform .2 :documentation "The max amount the pressure per cycle can ramp up too")
   (pressure-ramp-per-cycle :accessor pressure-ramp-per-cycle :initform .0025 :documentation "the speed at which the pressure-per-cycle will increase each cycle after the reaching the pressure ramp delay")
   )
  (:documentation "Used to adjust inflation. During adjustment play inflation sound"))


(defmethod START-JOG ((Self inflation-jog-button))
  (call-next-method)
  (setf (initial-time self) (get-internal-real-time))
  (setf (pressure-per-cycle self) (initial-pressure-per-cycle self))
  ;; the sound is kind of annoying, especially on Windows where we cannot set the volume
  ;#-cocotron
  ;(play-sound "whiteNoise.mp3" :loops t)
  )


(defmethod STOP-JOG ((Self inflation-jog-button))
  (call-next-method)
  (setf (time-of-last-text-update self)  nil)
  ;; the sound is kind of annoying, especially on Windows where we cannot set the volume
  ;#-cocotron
  ;(stop-sound "whiteNoise.mp3")
  ;(setf (text (view-named (window self) 'pressuretext)) (format nil "0.0"))
  )

(defmethod ADJUST-PRESSURE-ACTION ((Window inflatable-icon-editor-window) (Button inflation-jog-button))
  (ccl::with-autorelease-pool 
    (enable (view-named Window "flatten-button"))
    (when (and (< (pressure-per-cycle button) (max-pressure-per-cycle button)) (>= (get-internal-real-time) (+ (initial-time button) (* (pressure-ramp-delay button) internal-time-units-per-second))))
      (setf (pressure-per-cycle button) (+ (pressure-per-cycle button) (pressure-ramp-per-cycle button))))
    (set-document-editted Window :mark-as-editted t)
    (let ((Pressure (if (equal (name Button) "inflate") (pressure-per-cycle button) (* -1 (pressure-per-cycle button)))))
      ;; audio feedback
      #-cocotron
      (set-volume "whiteNoise.mp3" (abs Pressure))
      ;; model update
      (let ((Text-View (view-named Window 'pressuretext)))
        ;; update label
        ;; update model editor
        (let ((Model-Editor (view-named Window 'model-editor)))
          (incf (pressure (inflatable-icon Model-Editor)) (* 0.02 Pressure))
          (update-inflation Window)
          (setf (is-flat (inflatable-icon Model-Editor)) nil)
          (when  #-cocotron t #+cocotron (or (not (time-of-last-text-update button)) (>= (get-internal-real-time) (+ (time-of-last-text-update button) (* .155 internal-time-units-per-second))))
            (setf (time-of-last-text-update button)  (get-internal-real-time))
            (setf (text Text-View) (format nil "~4,2F" (* 1000 (pressure (inflatable-icon Model-Editor)))))))))))


;*************************************************
;  Component Actions                             *
;*************************************************

;; Tool Bar Actions

(defmethod DRAW-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'draw))


(defmethod ERASE-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'erase))


(defmethod EYE-DROPPER-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'eye-dropper))


(defmethod PAINT-BUCKET-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'paint-bucket))


(defmethod MAGIC-WAND-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'magic-wand))


(defmethod POLYGON-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'select-polygon))


(defmethod RECT-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'select-rect))


(defmethod ELLIPSE-TOOL-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (tool-selection-event Window 'select-ellipse))


(defmethod PICK-COLOR-ACTION ((w inflatable-icon-editor-window) (Color-Well color-well))
  (set-pen-color (view-named w "icon-editor") (get-red Color-Well) (get-green Color-Well) (get-blue Color-Well) (get-alpha Color-Well)))


(defmethod PICK-COLOR-ACTION ((w inflatable-icon-editor-window) (Color-Well color-well-button))
  (multiple-value-bind (red green blue alpha)
                       (get-color-from-user :red (/ (get-red Color-Well) 255.0) :green (/ (get-green Color-Well) 255.0) :blue (/ (get-blue Color-Well) 255.0) :alpha (/ (get-alpha Color-Well) 255.0))
    (unless red (return-from pick-color-action))
    (set-color color-well :red red :green green :blue blue :alpha alpha))
  (set-pen-color (view-named w "icon-editor") (get-red Color-Well) (get-green Color-Well) (get-blue Color-Well) (get-alpha Color-Well)))


(defmethod GET-MIRROR-STATE ((self inflatable-icon-editor-window))
  (let ((current-mirror-state nil)
        (image-editor (view-named self 'icon-editor)))
    (cond
     ((and (equal (is-horizontal-line-on image-editor) t) (equal (is-vertical-line-on image-editor) t))
      (setf current-mirror-state :both))
     ((and (equal (is-horizontal-line-on image-editor) nil) (equal (is-vertical-line-on image-editor) nil))
      (setf current-mirror-state :none))
     ((and (equal (is-horizontal-line-on image-editor) t) (equal (is-vertical-line-on image-editor) nil))
      (setf current-mirror-state :horizontal))
     ((and (equal (is-horizontal-line-on image-editor) nil) (equal (is-vertical-line-on image-editor) t))
      (setf current-mirror-state :vertical)))
    current-mirror-state))


(defmethod SET-MIRROR-STATE ((Window inflatable-icon-editor-window) state)
  (case state
    (:none
     (change-cluster-selections (view-named window "mirror-cluster") (view-named window "mirror-none-button"))
     (toggle-mirror-lines (view-named Window'icon-editor) nil nil))
    (:both
     (change-cluster-selections (view-named window "mirror-cluster") (view-named window "mirror-both-button"))
     (toggle-mirror-lines (view-named Window'icon-editor) t t))
    (:horizontal
     (change-cluster-selections (view-named window "mirror-cluster") (view-named window "mirror-horizontally-button"))
     (toggle-mirror-lines (view-named Window 'icon-editor) t nil))
    (:vertical
     (change-cluster-selections (view-named window "mirror-cluster") (view-named window "mirror-vertically-button"))
     (toggle-mirror-lines (view-named Window 'icon-editor) nil t))))


(defmethod MIRROR-NONE-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (declare (ftype function execute-command))
  (unless (and  (not (is-vertical-line-on (view-named window 'icon-editor))) (not (is-vertical-line-on (view-named window 'icon-editor))))
    (execute-command (command-manager window) (make-instance 'mirror-changed-command :window window :mirror-state (get-mirror-state window) :image-editor (view-named window 'icon-editor) :image-snapeshot (create-image-array (view-named window 'icon-editor)))))
  (toggle-mirror-lines (view-named Window 'icon-editor) nil nil)
  (display (view-named Window 'model-editor)))


(defmethod MIRROR-VERTICALLY-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (declare (ftype function execute-command))
  (unless (and (not (is-horizontal-line-on (view-named window 'icon-editor))) (is-vertical-line-on (view-named window 'icon-editor)))
    (execute-command (command-manager window) (make-instance 'mirror-changed-command :window window :mirror-state (get-mirror-state window) :image-editor (view-named window 'icon-editor) :image-snapeshot (create-image-array (view-named window 'icon-editor)))))
  (toggle-mirror-lines (view-named Window'icon-editor) nil t)
  (display (view-named Window 'model-editor)))


(defmethod MIRROR-HORIZONTALLY-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (declare (ftype function execute-command))
  (unless (and  (is-horizontal-line-on (view-named window 'icon-editor)) (not (is-vertical-line-on (view-named window 'icon-editor))))
    (execute-command (command-manager window) (make-instance 'mirror-changed-command :window window :mirror-state (get-mirror-state window) :image-editor (view-named window 'icon-editor) :image-snapeshot (create-image-array (view-named window 'icon-editor)))))
  (toggle-mirror-lines (view-named Window 'icon-editor) t nil)
  (display (view-named Window 'model-editor)))


(defmethod MIRROR-BOTH-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (declare (ftype function execute-command))
  (unless (and  (is-horizontal-line-on (view-named window 'icon-editor)) (is-vertical-line-on (view-named window 'icon-editor)))
    (execute-command (command-manager window) (make-instance 'mirror-changed-command :window window :mirror-state (get-mirror-state window) :image-editor (view-named window 'icon-editor) :image-snapeshot (create-image-array (view-named window 'icon-editor)))))
  (toggle-mirror-lines (view-named Window 'icon-editor) t t)
  (display (view-named Window 'model-editor)))


(defmethod CAMERA-PAN-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (camera-tool-selection-event Window 'pan))


(defmethod CAMERA-ZOOM-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (camera-tool-selection-event Window 'zoom))


(defmethod CAMERA-ROTATE-ACTION ((Window inflatable-icon-editor-window) Button)
  (declare (ignore Button))
  (camera-tool-selection-event Window 'rotate))



(defmethod SET-DOCUMENT-EDITTED :AFTER ((Self inflatable-icon-editor-window)  &key (mark-as-editted t) )
  (setf (window-needs-saving-p (window self)) mark-as-editted))

#|
;; Content Actions
(defmethod ADJUST-PRESSURE-ACTION ((Window inflatable-icon-editor-window) (Slider inflation-jog-slider) &optional do-not-display)
  (ccl::with-autorelease-pool
    (enable (view-named Window "flatten-button"))
    (set-document-editted Window :mark-as-editted t)
    (let ((Pressure (value Slider)))
      ;; audio feedback
      #-cocotron
      (set-volume "whiteNoise.mp3" (abs Pressure))
      ;; model update
      (let ((Text-View (view-named Window 'pressuretext)))
        ;; update label
        (setf (text Text-View) (format nil "~4,2F" Pressure))  
        (unless do-not-display
          (display Text-View))   
        ;; update model editor
        (let ((Model-Editor (view-named Window 'model-editor)))
          (incf (pressure (inflatable-icon Model-Editor)) (* 0.02 Pressure))
          (update-inflation Window)
          (setf (is-flat (inflatable-icon Model-Editor)) nil))))))
|#




(defmethod ADJUST-CEILING-ACTION ((Window inflatable-icon-editor-window) (Slider slider) &key (update-inflation t) (draw-transparent-ceiling t))
  (when draw-transparent-ceiling
    (setf (ceiling-transparency window) (transparent-ceiling-starting-alpha window))
    (setf (transparent-ceiling-should-fade window) nil)
    (unless (transparent-ceiling-update-process window)
      (setf *ceiling-update-thread-should-stop* nil)
      (setf (transparent-ceiling-update-process window)
        (lui::process-run-function
         '(:name "transparent ceiling update process")
         #'(lambda ()
             (loop
               (catch-errors-nicely ("inflatable ceilling is animating")
                 (when *Ceiling-Update-Thread-Should-Stop*  (return))
                 (when (ceiling-process-should-stop-and-close-window-p window)  (return))
                 (unless (or (transparent-ceiling-should-fade window)
                             (not (timer-due-p window (truncate (* 2.0 internal-time-units-per-second)))))
                   (setf (transparent-ceiling-should-fade window) t))
                 (when (transparent-ceiling-should-fade window)
                   (ccl::with-lock-grabbed ((transparent-ceiling-update-lock))
                     (update-ceiling-transparency window)))
                 (sleep .04)))
            (when (ceiling-process-should-stop-and-close-window-p window) (close-with-no-questions-asked window)))))))
  (let ((Ceiling (value Slider)))
    (set-document-editted Window :mark-as-editted t)
    (let ((Text-View (view-named Window 'ceilingtext)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" Ceiling))
      (display Text-View)
      ;; update model editor
      (let ((Model-Editor (view-named Window 'model-editor)))
        (setf (ceiling-value (inflatable-icon Model-Editor)) Ceiling)
        (setf (max-value (inflatable-icon Model-Editor)) (+ Ceiling (value (view-named window "z_slider")) ))
        (when update-inflation
          (update-inflation Window))))))


(defmethod UPDATE-CEILING-TRANSPARENCY ((Self inflatable-icon-editor-window))
  (when (timer-due-p self (truncate (* (transparent-ceiling-update-frequency self) internal-time-units-per-second)))
    (setf (ceiling-transparency self)  (- (ceiling-transparency self) (transparent-ceiling-decrement-value self)))
    (display (view-named self 'model-editor))
    ;; The following code was causing a memory leak
    ;(#/setNeedsDisplay: (lui::native-view (view-named self 'model-editor)) #$YES)
    ))

  
(defmethod ADJUST-NOISE-ACTION ((Window inflatable-icon-editor-window) (Slider slider))
  (let ((Noise (value Slider))
        (Model-Editor (view-named Window 'model-editor)))
    (set-document-editted Window :mark-as-editted t)
    (if (equal Noise 0.0)
      (progn
        (setf (value (view-named window "smooth_slider")) 0.0)
        (disable (view-named window "smooth_slider"))
        (let ((Text-View (view-named window 'smooth-text)))
          ;; update label
          (setf (text Text-View) (format nil "~A" 0.0))
          (display Text-View))
        (setf (smoothing-cycles Window) 0)
        (setf (smooth (inflatable-icon Model-Editor)) 0))
      (enable (view-named window "smooth_slider")))
    (let ((Text-View (view-named Window 'noise-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" Noise))
      (display Text-View)
      ;; update model editor
      (setf (noise (inflatable-icon Model-Editor)) Noise)
      (update-inflation Window)
      (setf (is-flat (inflatable-icon Model-Editor)) nil))))


(defmethod ADJUST-SMOOTH-ACTION ((Window inflatable-icon-editor-window) (Slider slider))
  (set-document-editted Window :mark-as-editted t)
  (let ((Smooth (truncate (value Slider))))
    (let ((Text-View (view-named Window 'smooth-text)))
      ;; update label
      (setf (text Text-View) (format nil "~A" Smooth))
      (display Text-View)
      ;; update model editor
      (setf (smoothing-cycles Window) Smooth)
      (setf (smooth (inflatable-icon (view-named Window 'model-editor))) smooth)
      (update-inflation Window))))


(defmethod ADJUST-Z-OFFSET-ACTION ((Window inflatable-icon-editor-window) (Slider slider))
  (set-document-editted Window :mark-as-editted t)
  (let ((Offset (value Slider)))
    (let ((Text-View (view-named Window 'z-offset-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" Offset))
      (display Text-View)
      ;; update model editor
      (let* ((Model-Editor (view-named Window 'model-editor)))
        (setf (dz (inflatable-icon Model-Editor)) Offset)
        (adjust-ceiling-action window (view-named window "ceiling_slider") :update-inflation nil)
        (display Model-Editor)))))


(defmethod ADJUST-DISTANCE-ACTION ((Window inflatable-icon-editor-window) (Slider slider) &optional do-not-display)
  (set-document-editted Window :mark-as-editted t)
  (let ((Distance  (value Slider)))
    (let ((Text-View (view-named Window 'distance-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" Distance))
      (display Text-View))
    ;; set distance of inflatable icon
    (let ((Model-Editor (view-named Window 'model-editor)))
      (setf (distance (inflatable-icon Model-Editor)) Distance)
      (unless do-not-display
        (display Model-Editor)
        ))))


(defmethod CHANGE-ICON-ACTION ((Window inflatable-icon-editor-window) (Icon-Editor icon-editor))
  (update-inflation Window))


(defmethod UPRIGHT-ACTION ((Window inflatable-icon-editor-window) (Check-Box check-box))
  (set-document-editted Window :mark-as-editted t)
  (let ((Model-Editor (view-named Window 'model-editor)))
    (setf (is-upright (inflatable-icon Model-Editor))
          (value Check-Box))
    (display Model-Editor)))

;; surface actions

(defmethod FRONT-SURFACE-ACTION ((Window inflatable-icon-editor-window) (Pop-Up pop-up))
  (declare (ignore Pop-Up))
  (set-document-editted Window :mark-as-editted t)
  (enable (view-named window "upright"))
  (let ((Model-Editor (view-named Window 'model-editor)))
    (setf (value (view-named window "distance-slider")) 0.0)
    (adjust-distance-action window (view-named window "distance-slider") t)
    (disable (view-named window "distance-slider"))
    (setf (surfaces (inflatable-icon Model-Editor)) 'front)
    (display Model-Editor)))


(defmethod FRONT-AND-BACK-SURFACE-ACTION ((Window inflatable-icon-editor-window) (Pop-Up pop-up))
  (declare (ignore Pop-Up))
  (set-document-editted Window :mark-as-editted t)
  (enable (view-named window "upright"))
  (let ((Model-Editor (view-named Window 'model-editor)))
    (enable (view-named window "distance-slider"))
    (setf (surfaces (inflatable-icon Model-Editor)) 'front-and-back)
    (display Model-Editor)))


(defmethod FRONT-AND-BACK-CONNECTED-SURFACE-ACTION ((Window inflatable-icon-editor-window) (Pop-Up-Item pop-up))
  (declare (ignore Pop-Up-item))
  (set-document-editted Window :mark-as-editted t)
  (enable (view-named window "upright"))
  (let ((Model-Editor (view-named Window 'model-editor)))
    (enable (view-named window "distance-slider"))
    (setf (surfaces (inflatable-icon Model-Editor)) 'front-and-back-connected)
    (display Model-Editor)))


(defmethod CUBE-SURFACE-ACTION ((Window inflatable-icon-editor-window) (Pop-Up-Item pop-up))
  (declare (ignore Pop-Up-item))
  (set-document-editted Window :mark-as-editted t)
  (let ((Model-Editor (view-named Window 'model-editor)))
    (setf (is-upright (inflatable-icon Model-Editor))  nil)
    (turn-off (view-named window "upright"))
    (disable (view-named window "upright"))
    (enable (view-named window "distance-slider"))
    (setf (value (view-named window "z_slider")) .5)
    (setf (value  (view-named window "ceiling_slider")) (+ (value  (view-named window "ceiling_slider")) (- .5 (value (view-named window "distance-slider")))))
    (setf (value (view-named window "distance-slider")) .5)
    (adjust-distance-action window (view-named window "distance-slider") t)
    (adjust-z-offset-action window (view-named window "z_slider") )
    (adjust-ceiling-action window (view-named window "ceiling_slider") :update-inflation nil)
    (setf (surfaces (inflatable-icon Model-Editor)) 'cube)
    (display Model-Editor)))


(defmethod EDIT-ICON-FLATTEN-ACTION ((Window inflatable-icon-editor-window) (Button bevel-button))
  ;(set-document-editted Window :mark-as-editted t)
  (let ((Model-Editor (view-named Window 'model-editor)))
    (flatten (inflatable-icon Model-Editor))
    (unless (> (distance (inflatable-icon Model-Editor)) 0.0)
      (setf (value (view-named Window "distance-slider")) 0.0)
      (setf (distance (inflatable-icon (view-named Window 'model-editor))) 0.0))
    ;; update GUI: pressure is 0.0
    ;(setf (value (view-named Window 'pressure_slider)) 0.0)
    ;(setf (text (view-named Window 'pressuretext)) "0.0")
    (setf (pressure (inflatable-icon (view-named Window 'model-editor))) 0.0)
    ;; enable flat texture optimization
    (setf (is-flat (inflatable-icon (view-named Window 'model-editor))) t)
    (change-icon-action Window (view-named Window 'icon-editor))
    (update-texture-from-image (inflatable-icon (view-named Window 'model-editor)))
    (setf (text (view-named window 'pressuretext)) (format nil "0.0" ))
    (disable button)
    ;; update for user
    (display Model-Editor)))


(defmethod CLOSE-WINDOW-WITH-WARNING ((Self inflatable-icon-editor-window))
  #-cocotron
  (when (easygui::y-or-n-dialog "Close window without saving changes?" )
    ;; forget current content
    (when (close-action Self) 
      (funcall (close-action Self) Self))
    (when (and (alert-close-action self) (alert-close-target self))
      (funcall (alert-close-action self) (alert-close-target self)))
    (window-close Self)))


(defmethod EDIT-ICON-CANCEL-ACTION ((Window inflatable-icon-editor-window) (Button button))
  (window-close Window))


(defmethod CLEAR-ACTION ((Window inflatable-icon-editor-window) (Button bevel-button))
  (declare (ftype function execute-command))
  (let* ((Model-Editor (or (view-named window 'model-editor) (error "model editor missing")))
         (Inflatable-Icon (inflatable-icon Model-Editor)))
    (setf (noise inflatable-icon) 0.0)
    (setf (smooth inflatable-icon) 0)
    (setf (smoothing-cycles window) 0)
    (setf (max-value inflatable-icon) 2.0)
    (setf (distance inflatable-icon) 0.0)
    ;(setf (surfaces inflatable-icon) 'front)
    (turn-off (view-named window "upright"))
    (setf (is-upright inflatable-icon) nil)
    (set-selected-item-with-title (view-named window "surfaces") "front")
    (setf (surfaces (inflatable-icon Model-Editor)) 'front)
    (execute-command (command-manager window) (make-instance 'pixel-update-command :image-editor (view-named window 'icon-editor) :image-snapeshot (create-image-array (view-named window 'icon-editor))) :set-editted nil)
    
    (erase-all (view-named window 'icon-editor))
    (dotimes (Row (rows Inflatable-Icon ))
      (dotimes (Column (columns Inflatable-Icon ))
        (setf (aref (altitudes Inflatable-Icon ) Row Column) 0.0)))
    (when (texture-id Inflatable-Icon)
      (ccl::rlet ((&Tex-Id :long (texture-id Inflatable-Icon)))
        (glDeleteTextures 1 &Tex-Id))
      (setf (texture-id Inflatable-Icon) nil))
    (Setf (pressure Inflatable-Icon) 0.0)
    (setf (value (view-named window "distance-slider")) 0.00)
    (setf (distance (inflatable-icon Model-Editor)) 0.0)
    (setf (value (view-named window "ceiling_slider")) 1.0)
    (setf (value (view-named window "smooth_slider")) 0.0)
    (setf (value (view-named window "noise_slider")) 0.0)
    (setf (value (view-named window "z_slider")) 0.0)
    ; (set-selected-item-with-title (view-named window "surfaces") "Front")
    (setf (dz (inflatable-icon Model-Editor) ) 0.0)
    (let ((Text-View (view-named window 'distance-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" 0.0))
      (display Text-View))
    (let ((Text-View (view-named window 'ceilingtext)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" 1.0))
      (display Text-View))
    (let ((Text-View (view-named window 'z-offset-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" 0.0))
      (display Text-View))
    (let ((Text-View (view-named window 'noise-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" 0.0))
      (display Text-View))
    
    (let ((Text-View (view-named window 'smooth-text)))
      ;; update label
      (setf (text Text-View) (format nil "~A" 0.0))
      (display Text-View))
    (edit-icon-flatten-action window (view-named window "flatten-button"))
    (clear-selection (view-named window 'icon-editor))
    (display Model-Editor)))


(defmethod EDIT-ICON-SAVE-ACTION ((Window inflatable-icon-editor-window) (Button button) &key (close-window t))
  (declare (ftype function shape project-window display-world save shape lui::save-button-pressed lui::apply-button-pressed))  ;; this file is in the wrong place: should move into AgentCubes
  (set-document-editted window :mark-as-editted nil)
  (setf  (window-needs-saving-p window) nil)
  (window-save Window)
  (let* ((shape-manager (load-object (make-pathname :name "index" :type "shape"  :directory (pathname-directory (file window))):package (find-package :xlui)))
        (Model-Editor (view-named Window 'model-editor))
        (thumbnail-name #-cocotron "thumbnail.jpeg" #+cocotron "thumbnail.png")
        (thumbnail-path (native-path (native-pathname-directory (file window)) thumbnail-name)))
    (compute-depth (inflatable-icon Model-Editor))
    (let ((image-editor (view-named window 'icon-editor))
          (colors  ""))
      (dotimes (Column  (Columns (inflatable-icon Model-Editor)))
        (dotimes (Row  (Rows (inflatable-icon Model-Editor)))
          (multiple-value-bind (red green blue alpha)
                               (get-rgba-color-at  image-editor  (- 31 column) row)                   
            (setf colors (concatenate 'string colors (if (equal red 0)   "00" (write-to-string red :base 16))))
            (setf colors (concatenate 'string colors (if (equal green 0) "00" (write-to-string green :base 16))))
            (setf colors (concatenate 'string colors (if (equal blue 0)  "00" (write-to-string blue :base 16))))
            (setf colors (concatenate 'string colors (if (equal alpha 0) "00" (write-to-string alpha :base 16)))))))
      (setf (colors (inflatable-icon Model-Editor)) colors))
    ;(window-save Window)
    (setf (shape shape-manager) (inflatable-icon Model-Editor)) 
    ;  (lui::dump-buffer (image (shape shape-manager)) 32 32)
    (cond
     ((not (is-flat (inflatable-icon Model-Editor)))
      (lui::save-frame-buffer-as-image Model-Editor
                                       ;(format nil "~Athumbnail.png"  (pathname-directory (file window)))
                                       ;(namestring (make-pathname :name "thumbnail" :type "png"  :directory (pathname-directory (file window))))
                                       thumbnail-path
                                       #-cocotron :Image-Type #-cocotron :jpeg
                                       ))
     ((probe-file (native-path (native-pathname-directory (file window)) thumbnail-name))
     (ccl::delete-file thumbnail-path)))
    (setf (thumbnail-name (inflatable-icon (view-named Window 'model-editor))) thumbnail-name)
    (save shape-manager))
  (let ((Model-Editor (view-named Window 'model-editor)))
    ;; finalize geometry
    (when (save-button-closure-action window)
      (funcall (save-button-closure-action window) (inflatable-icon Model-Editor))))  
  (when close-window 
    (window-close window)))


;___________________________________________
; Update Thread                             |
;___________________________________________

(defmethod TIMER-DUE-P ((Self inflatable-icon-editor-window) Ticks) 
  (let ((Time (getf (timer-triggers Self) Ticks 0))
        (Now (get-internal-real-time)))
    (when (or (>= Now Time)                          ;; it's time
              (> Time (+ Now Ticks Ticks)))    ;; timer is out of synch WAY ahead
      (setf (getf (timer-triggers Self) Ticks) (+ Now Ticks))
      t)))


;___________________________________________
; Modal Methods                            |
;___________________________________________


(defmethod READ-RETURN-VALUE ((Self inflatable-icon-editor-window))
  ;; We want to return the actual window instead of the selected button so that we can create a window and show it later.
  self)

(defmethod BEFORE-GOING-MODAL ((Self inflatable-icon-editor-window))
  (display (view-named self "icon-editor")))


(defmethod STOP-MODAL :after ((Self inflatable-icon-editor-window) Return-Value)
  (declare (ignore return-value)))

;___________________________________________
; Open & New                                |
;___________________________________________

(defun NEW-INFLATABLE-ICON-EDITOR-WINDOW (&key (Width 32) (Height 32)) "
  Create and return a new inflatable icon editor window"
  (let* ((Window (load-object "lui:resources;windows;inflatable-icon-editor.window" :package (find-package :xlui)))
         (Icon-Editor (view-named Window "icon-editor"))
         (Inflated-Icon-Editor (view-named Window "model-editor")))
    ;; 2D
    (new-image Icon-Editor Width Height)
    (center-canvas Icon-Editor)
    (get-rgba-color-at Icon-Editor 0 0) ;;; HACK!! make sure buffer is allocated 
    ;; 3D
    (setf (inflatable-icon Inflated-Icon-Editor)
          (make-instance 'inflatable-icon :columns Width :rows Height :view Inflated-Icon-Editor))
    (setf (auto-compile (inflatable-icon Inflated-Icon-Editor)) nil)  ;;; keep non compiled for editing
    (setf (altitudes (inflatable-icon Inflated-Icon-Editor))
          (make-array (list Height Width)
                      :element-type 'short-float
                      :initial-element 0.0))
    ;; share the pixel buffer of the icon editor
    (setf (image (inflatable-icon Inflated-Icon-Editor))
                  (pixel-buffer Icon-Editor))
    (display Window)
    Window))


(defun NEW-INFLATABLE-ICON-EDITOR-WINDOW-FROM-IMAGE (Pathname &key save-button-closure-action Shape-Name Shape-Filename Destination-Inflatable-Icon Close-Action Alert-Close-Action Alert-Close-Target) "
  Create and return an new inflatable icon editor by loading an image. 
  If folder contains .shape file matching image file name then load shape file."
  (declare (ignore Close-Action Destination-Inflatable-Icon)
           (ftype function shape))
  (catch-errors-nicely 
   ("editing Inflatable Icon")
   (let* ((Window #-cocotron (load-object "lui:resources;windows;inflatable-icon-editor.window" :package (find-package :xlui)) #+cocotron (load-object "lui:resources;windows;inflatable-icon-editor-windows.window" :package (find-package :xlui)))
          (Inflated-Icon-Editor (view-named Window "model-editor")))
     (setf (save-button-closure-action window) save-button-closure-action)
    (if shape-name
      (setf (title window) (format nil "Inflatable Icon: ~A" (String-capitalize shape-name)))
      (setf (title window) (format nil "Inflatable Icon: ~A" (pathname-name Pathname))))
     (if alert-close-action
       (setf (alert-close-action window) alert-close-action))
     (if alert-close-target 
       (setf (alert-close-target window) alert-close-target))
     (setup-icon-editor-with-image-at-path window pathname :shape-filename shape-filename)

     
     (initialize-gui-components Window (inflatable-icon Inflated-Icon-Editor))
     (camera-rotate-action window (View-named window "rotate button"))
     (Set-button-on (View-named window "rotate button"))
     window)))

(defmethod SETUP-ICON-EDITOR-WITH-IMAGE-AT-PATH ((Window inflatable-icon-editor-window) pathname &key (shape-filename nil))
  (let ((Icon-Editor (view-named Window "icon-editor"))
        (Inflated-Icon-Editor (view-named Window "model-editor")))
       ;; 2D
     (load-image Icon-Editor Pathname)
     (center-canvas Icon-Editor)
     (get-rgba-color-at Icon-Editor 0 0) ;;; HACK!! make sure buffer is allocated 
     ;; 3D
     (let ((Shape-Pathname (make-pathname
                            :directory (pathname-directory Pathname)
                            :name (or Shape-Filename (pathname-name Pathname))
                            :type "shape"
                            :host (pathname-host Pathname)
                            :defaults Pathname)))
       ;; make shape 
       (cond
        ;; make shape from shape file
        ((probe-file Shape-Pathname)
         
         
         (let ((shape (load-object Shape-Pathname :package (find-package :xlui))))
          (if (equal (type-of shape) 'xlui::inflatable-icon)
            (setf (inflatable-icon Inflated-Icon-Editor) shape)
            (setf (inflatable-icon Inflated-Icon-Editor) 
                  (shape shape))))
         
         (setf (view (inflatable-icon Inflated-Icon-Editor)) Inflated-Icon-Editor))
        ;; make new one
        (t
         (setf (inflatable-icon Inflated-Icon-Editor) 
               (make-instance 'inflatable-icon 
                 :columns (img-width Icon-Editor)
                 :rows (img-height Icon-Editor)
                 :view Inflated-Icon-Editor))
         (setf (altitudes (inflatable-icon Inflated-Icon-Editor))
               (make-array (list (img-height Icon-Editor) (img-width Icon-Editor))
                           :element-type 'short-float
                           :initial-element 0.0))))
       ; (initialize-gui-components Window (inflatable-icon Inflated-Icon-Editor))
       (setf (auto-compile (inflatable-icon Inflated-Icon-Editor)) nil))  ;; keep editable
     ;; use the icon editor image, not the new inflatable icon editor one
     (setf (image (inflatable-icon Inflated-Icon-Editor))
           (pixel-buffer Icon-Editor))
     ;; proxy icons
     ;;; some day (add-window-proxy-icon Window Shape-Pathname)
     ;; wrap up
     (setf (file window) pathname)
     (display Window)
     (display (view-named Window "icon-editor"))
    (make-key-window Window )))
           

(defmethod INITIALIZE-GUI-COMPONENTS ((Self inflatable-icon-editor-window) Inflatable-Icon)
  (setf (value (view-named self "distance-slider")) (distance inflatable-icon))
  (setf (value (view-named self "ceiling_slider")) (ceiling-value inflatable-icon))
  (setf (value (view-named self "smooth_slider")) (float (smooth inflatable-icon)))
  (setf (value (view-named self "noise_slider")) (noise inflatable-icon))
  (setf (value (view-named self "z_slider")) (dz inflatable-icon))
  (unless (> (value (view-named self "noise_slider")) 0.0)
    (disable (view-named self "smooth_slider")))
  (when (equal (surfaces inflatable-icon) 'cube)
    (disable (view-named self "upright")))
  (let ((Text-View (view-named self 'distance-text)))
    ;; update label
    (setf (text Text-View) (format nil "~4,2F"(distance inflatable-icon)))
    (display Text-View))
  (let ((Text-View (view-named self 'ceilingtext)))
    ;; update label
    (setf (text Text-View) (format nil "~4,2F" (Ceiling-value inflatable-icon)))
    (display Text-View))
  (let ((Text-View (view-named self 'z-offset-text)))
    ;; update label
    (setf (text Text-View) (format nil "~4,2F" (dz inflatable-icon)))
    (display Text-View))
  (let ((Text-View (view-named self 'noise-text)))
      ;; update label
      (setf (text Text-View) (format nil "~4,2F" (Noise inflatable-icon)))
      (display Text-View))
  (let ((Text-View (view-named self 'smooth-text)))
      ;; update label
      (setf (text Text-View) (format nil "~A" (Smooth inflatable-icon)))
      (display Text-View))
  (when (equal (surfaces Inflatable-Icon) 'front)
    (disable (view-named self "distance-slider")))
  (set-selected-item-with-title (view-named self "surfaces")  (string-downcase(substitute #\space #\-  (string (surfaces Inflatable-Icon)) :test 'equal)))
  (when (is-flat Inflatable-icon)
    (disable (view-named self "flatten-button")))
  (when (is-upright Inflatable-Icon)
    (enable (view-named self "upright"))
    (turn-on (view-named self "upright"))))
  
 
#| Examples:


(defparameter *Inflatable-Icon-Editor* (new-inflatable-icon-editor-window :width 32 :height 32))

(defparameter *Inflatable-Icon-Editor* (new-inflatable-icon-editor-window-from-image "lui:resources;templates;shapes;redLobster;redLobster.png"))

(new-inflatable-icon-editor-window-from-image "lui:resources;templates;shapes;redLobster;redLobster.png" :shape-filename "index")



(defparameter *Inflatable-Icon-Editor40* (new-inflatable-icon-editor-window :width 40 :height 40))


(defparameter *Inflatable-Icon-Editor* (new-inflatable-icon-editor-window :width 64 :height 64))

(defparameter *Inflatable-Icon-Editor2* (new-inflatable-icon-editor-window-from-image  (easygui::choose-file-dialog)))





|#