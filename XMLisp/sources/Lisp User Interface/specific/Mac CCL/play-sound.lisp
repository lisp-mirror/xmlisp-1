;; play-sound.lisp
;; status: feature spartan and no real attempt to manage memory but works
;; 11/30/08 Alexander Repenning
;;; updated: 05/13/09 
;;; todo: support parallel sound: new NSsound instance when old one is still playing sound

(in-package :lui)


(defparameter *Sounds* (make-hash-table :test #'equal) "Sound handles")

#+cocotron
(defparameter *BASS-SOUNDED-INITIALIZED-P* nil)

(defvar *Secondary-Sound-File-Directory-Hook* nil "lambda () ->  directory-pathname")


(defgeneric PLAY-SOUND (Name &key Loops)
  (:documentation "Play sound in resources/sounds/ folder"))


(defgeneric STOP-SOUND (Name)
  (:documentation "Stop playing sound"))


(defgeneric SET-VOLUME (Name Volume)
  (:documentation "Set volume of sound <Name> playing to <volume>. <volume> in range 0.0 ..1.0"))


(defgeneric SHUT-UP-SOUNDS ()
  (:documentation "Stop all sounds from playing"))


(defmethod PLAY-SOUND ((Name string) &key Loops (path nil))
  #+cocotron (declare (ignore Loops))
  

  
  #+cocotron
  (play-sound-from-dll Name :path path)
  
  #-cocotron
  (ccl::with-autorelease-pool
    (let ((Sound (or (gethash Name *Sounds*)
                     (let ((New-Sound
                            (#/initWithContentsOfFile:byReference: 
                             (#/alloc ns:ns-sound) 
                             (native-string (if path path (native-path "lui:resources;sounds;" Name)))
                             #$YES)))
                       ;; (print "loading sound")
                       (unless (%null-ptr-p New-Sound)
                         (setf (gethash Name *Sounds*) New-Sound))))))
      (unless Sound (return-from play-sound (error "sound \"~A\" is missing" Name)))
      #-cocotron
      (#/setLoops: Sound (if Loops #$YES #$NO))
      (#/play Sound))))




#+cocotron
(defmethod PLAY-SOUND-FROM-DLL ((Name string) &key (path nil))
  (unless  *BASS-SOUNDED-INITIALIZED-P*
    
    (open-shared-library (concatenate 'string (namestring (truename "lui:resources;dlls;"))  "dsptest.dll"))
    (external-call "initBASS")
    (setf  *BASS-SOUNDED-INITIALIZED-P* t))
  (let ((sound-path (if path path (native-path "lui:resources;sounds;" Name))))
    (ccl::with-cstr (c-string-sound-path sound-path)
      
      (let ((Sound (or (gethash Name *Sounds*)
                       (let ((New-Sound
                              (External-call "initBASSSound" :address c-string-sound-path :address)))
                         (unless (%null-ptr-p New-Sound)
                           (setf (gethash Name *Sounds*) New-Sound))))))
        (external-call "playBASSSound" :address Sound)
      )
  )))


(defmethod SET-VOLUME ((Name string) Volume)
  #+cocotron (Declare (ignore volume))
  #-cocotron
  (let ((Sound (gethash Name *Sounds*)))
    (when Sound (#/setVolume: Sound Volume))))


(defmethod SHUT-UP-SOUNDS ()
  (maphash 
   #'(lambda (Name Sound) 
       (declare (ignore Sound))
       (stop-sound Name))
   *Sounds*))


(defmethod STOP-SOUND (Name)
  (let ((Sound (gethash Name *Sounds*)))
    (when Sound #-cocotron (#/stop Sound)
      #+cocotron (external-call "stopBASSSound" :address Sound)
      )))


(defun SOUND-FILES-IN-SOUND-FILE-DIRECTORY () "
  out: Sound-Files lisp of pathname"
  (directory "lui:resources;sounds;*.*"))




#| Examples:

(play-sound "Radar-beep.mp3")

(play-sound "Inhale.mp3")

(play-sound "Explode.mp3")

(play-sound "RuinsMystique.mp3")

(play-sound "missing-sound.mp3")

(play-sound "Inhale.mp3" :loops t)

(play-sound "whiteNoise.mp3" :loops t)

(shut-up-sounds)


(progn
  (play-sound "whiteNoise.mp3" :loops t)
  (sleep 1.0)
  (set-volume "whiteNoise.mp3" 0.5)
  (sleep 1.0)
  (set-volume "whiteNoise.mp3" 0.1)  
  (sleep 1.0)
  (stop-sound "whiteNoise.mp3"))



|#
