(in-package :lui)

;;*******************************
;; Pop Up Image Menu            *
;;*******************************

(defclass POP-UP-IMAGE-MENU ()
  ((native-window :accessor native-window :initform nil)
   (native-view :accessor native-view :initform nil)
   (x :accessor x :initform 200 :initarg :x :documentation "screen position, pixels")
   (y :accessor y :initform 690 :initarg :y :documentation "screen position, pixels")
   (width :accessor width :initform 500 :initarg :width :documentation "width in pixels")
   (height :accessor height :initform 500 :initarg :height :documentation "height in pixels")
   (image-height :accessor image-height :initform 20 :documentation "height of image")
   (image-width :accessor image-width :initform 20 :documentation "height of image")
   (image-file-extension :accessor image-file-extension :initform "png" :initarg :image-file-extension :documentation "the extension of the image file")
   (image-pathname :accessor image-pathname :initform "lui:resources;buttons;direction;" :initarg :image-pathname :documentation "the path to where the image files are stored")
   (index-of-selection :accessor index-of-selection :initform nil :documentation "the index of the selected item")
   (name-of-selection :accessor name-of-selection :initform nil :initarg :name-of-selection :documentation "the name of the selected item")
   (window-offset-x :accessor window-offset-x :initform 0 :documentation "the X offset needed to display the window in the propper location")
   (window-offset-y :accessor window-offset-y :initform 0 :documentation "the Y offset needed to display the window in the propper location")
   (images :accessor images :initform nil :initarg :images :documentation "A list of images for the Menu"))
  (:documentation "This class will pop up an an image menu that tries to display the given list of strings in a way that is as close to a square as possible"))


;;_______________________________
;; Specification                 |
;;_______________________________

(defgeneric DISPLAY-POP-UP-MENU (pop-up-image-menu &key x y)
  (:documentation "Pops up the menu and returns the value of the selected image"))


(defgeneric IMAGE-NAMES (pop-up-image-menu)
  (:documentation "Returns the list of strings that will be used by the menu. Do not include file extensions, e.g. 'arrow' not 'arrow.png'"))


(defgeneric SELECTED-IMAGE-NAME (pop-up-image-menu)
  (:documentation "Return the name of the image last selected"))

;;_______________________________
;; Implementation                |
;;_______________________________

(defmethod IMAGE-NAMES ((Self pop-up-image-menu))
  (images self))


(defmethod IMAGE-NAME-PATHNAME ((Self pop-up-image-menu) Name)
  (native-path  (image-pathname self)  Name))


(defmethod NUMBER-OF-COLUMNS ((Self pop-up-image-menu))
  (case (length (image-names Self))
    (0 1)
    (t (isqrt (length (image-names Self))))))


(defmethod NUMBER-OF-ROWS ((Self pop-up-image-menu))
  (case (length (image-names Self))
    (0 1)
    (t (ceiling (length (image-names Self)) (number-of-columns Self)))))


(defmethod GET-X-GRID-POSITION ((Self pop-up-image-menu))
  (mod (index-of-selection self) (number-of-columns self)))


(defmethod GET-Y-GRID-POSITION ((Self pop-up-image-menu))
  (number-of-rows self) (floor (/ (index-of-selection self) (number-of-columns self))))


(defmethod GET-SELECTION-INDICES ((Self pop-up-image-menu))
  (values 
   (get-x-grid-position self)
   (get-y-grid-position self)))


(defmethod SELECTED-IMAGE-NAME ((self pop-up-image-menu))
  (elt (image-names self) (index-of-selection self)))
;;_______________________________
;; Direction Pop Up Menu         |
;;_______________________________

(defclass DIRECTION-POP-UP-IMAGE-MENU (pop-up-image-menu)
  ()
  (:documentation "An image pop up menu that is used as a directional picker"))


(defmethod IMAGE-NAMES ((Self direction-pop-up-image-menu))
  '("direction_north_west" "direction_north" "direction_north_east" "direction_west" "direction_center" "direction_east" "direction_south_west" "direction_south" "direction_south_east"))


#| Example:

(defparameter *Pop-Up-Menu* (make-instance 'direction-pop-up-image-menu :name-of-selection  "direction_north_west"))

(display-Pop-Up-menu *Pop-Up-Menu*)

(display-Pop-Up-menu *Pop-Up-Menu* :x 900 :y 900)

|#

