(in-package :lui)

;**********************************
;* Browser-View                   *
;**********************************

(defclass BROWSER-VIEW (control)
  ((text :accessor text :initform "untitled" :initarg :text :type string :documentation "text associated with control")
   (columns :accessor columns :initform () :type list :documentation "A list of rows which in turn is a list of values for the row")
   (column-limit :accessor column-limit :type integer :initform 10 :initarg :column-limit :documentation "If this limit is set, the browser will not allow more columns then this limit")
   )
  (:documentation "colored rectangle and if it has transparency it is shown in one half of the view")
  (:default-initargs 
      :action 'default-browser-action
      :x 10
    :y 10))


(defgeneric NODES (browser-view)
  (:documentation "Returns the nodes of this object"))


(defgeneric GET-VALUE-OF-SELECTED-CELL (browser-view)
  (:documentation "Returns the value of the selcted cell in the browser view"))


(defgeneric GET-VALUE-OF-SELECTED-CELL-AT-COLUMN (browser-view column)
  (:documentation "Returns the value of the selcted cell in a given column in the browser view"))


(defgeneric GET-SELECTED-COLUMN (browser-view)
  (:documentation "Returns an integer identifying which column is selected in the browser view"))


(defgeneric SET-TITLE-OF-COLUMN (browser-view column title)
  (:documentation "Returns an integer identifying which column is selected in the browser view"))


(defmethod NODES ((self browser-view))
  nil)


(defmethod DEFAULT-BROWSER-ACTION ((window window)(Self browser-view))
  ;; Do nothing
  )

;**********************************
;* Node-Item                      *
;**********************************

(defclass NODE-ITEM ()
  ((node-name :accessor node-name :initform "Name" :initarg :node-name :documentation "the name of this node item")
   (image-path :accessor image-path :initform nil :initarg :image-path :documentation "The path to this node's images, if it has one"))
  (:documentation "A node item represents a node in a browser tree"))
  

(defgeneric NODES (node-item)
  (:documentation "Returns the nodes of this object"))


(defmethod NODES ((self node-item))
  nil)

;**********************************
;* Animal-Browser                 *
;**********************************

(Defclass ANIMAL-BROWSER-VIEW (browser-view)
  ()
  (:documentation "A browser that display a hieararchy of animals"))


(defmethod NODES ((self animal-browser-view))
  (list (make-instance 'mammal-node-item) (make-instance 'bird-node-item)))


(defclass MAMMAL-NODE-ITEM (node-item)
  ()
  (:documentation "A node item that represents a mammal in an animal browser tree")
  (:default-initargs 
      :name "Mammal"))


(defmethod NODES ((self mammal-node-item))
  '("Cow" "Bear" "Dog"))


(defclass BIRD-NODE-ITEM (node-item)
  ()
  (:documentation "A node item that represents a bird in an animal browser tree")
  (:default-initargs 
      :name "Bird"))


(defmethod NODES ((self bird-node-item))
  '("Eagle" "Hawk" "Sparrow" "Raven"))


#|  Example:
(defparameter *window*
  (make-instance 'window))

(add-subview *window* (make-instance 'animal-browser-view :width 300 :height 300))
|#