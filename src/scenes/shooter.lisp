(in-package #:cl-user)
(defpackage #:glider/scenes/shooter
  (:use #:cl
        #:sdl2
        #:glider/const
        #:glider/util
        #:glider/vm
        #:glider/actors
        #:glider/combinators)
  (:export #:init-shooter))
(in-package #:glider/scenes/shooter)

(defun %aim-n-way (gw x y) ;; not primitive
  (lambda (vm a sfn)
    (multiple-value-bind (i n)
        (funcall sfn)
      (+ (atan y x) (to-rad (* (- i (/ n 2)) gw))))))

(defun %aim (x y)
  (lambda (vm a sfn)
    (atan y x)))

(defun %rotate (gw)
  (lambda (vm a sfn)
    (multiple-value-bind (i n)
        (funcall sfn)
      (to-rad (+ (* (actor-start-tick a) (actor-start-tick a) 0.03)
                 (* (- i (/ n 2)) gw))))))

(defun %move-1 (ang-fn v)
  (flet ((move (f)
           (lambda (vm a sfn)
             (* (funcall f (funcall ang-fn vm a sfn)) v))))
    (list (move #'cos) (move #'sin))))

(defun %move-2 (tri-fn ang-fn init-v v)
  (lambda (vm a sfn)
    (* (funcall tri-fn (funcall ang-fn vm a sfn))
       (+ init-v
          (/ v (+ 1 (/ (- (vm-tick vm) (actor-start-tick a)) 10)))))))

(defun %count-n? (n)
  (lambda (vm a sfn)
    (declare (ignore sfn))
    (zerop (mod (- (vm-tick vm) (actor-start-tick a)) n))))

(defun %out-of? (x1 y1 x2 y2)
  (lambda (vm a sfn)
    (declare (ignore vm sfn))
    (let ((x (actor-x a))
          (y (actor-y a)))
      (or (< x x1) (< x2 x)
          (< y y1) (< y2 y)))))

;; TODO: use queues (instead of plain lists)
(defun default-drawer (renderer a)
    (multiple-value-bind (x y)
        (onto-screen (actor-x a) (actor-y a))
      (set-render-draw-color renderer 0 255 100 100)
      (let* ((r 10)
             (r/2 (floor (/ r 2))))
        (render-fill-rect renderer (make-rect (- x r/2) (- y r/2) r r)))))

(defun make-event ()
  `((0 . (:fire ,(/ *shooter-width* 2) 100
          ,($when (%count-n? 2)
                  ($times ($fire ($progn ($move (%move-2 #'cos (%rotate 72) 1 14)
                                                (%move-2 #'sin (%rotate 72) 1 14))
                                         ($when (%out-of? 0 0 *shooter-width* *shooter-height*)
                                                ($disable))))
                          5))
          ,#'default-drawer))
    (100 . (:fire ,(- (/ *shooter-width* 2) 150) 70
            ,($when (%count-n? 13)
                    ($times ($fire ($progn (apply #'$move (%move-1 (%aim-n-way 10 1 3) 3))
                                           ($when (%out-of? 0 0 *shooter-width* *shooter-height*)
                                                  ($disable))))
                            7))
            ,#'default-drawer))
    (100 . (:fire ,(+ (/ *shooter-width* 2) 150) 70
            ,($when (%count-n? 13)
                    ($times ($fire ($progn (apply #'$move (%move-1 (%aim-n-way 10 -1 3) 3))
                                           ($when (%out-of? 0 0 *shooter-width* *shooter-height*)
                                                  ($disable))))
                            7))
          ,#'default-drawer))
    (200 . (:fire 0 50
            ,($progn (apply #'$move (%move-1 (%aim (/ *shooter-width* 2) (* 0.9 *shooter-height*)) 5))
                     ($schedule
                      `(10 . ,($fire (apply #'$move (%move-1 (%aim 10 10) 1))))
                      `(20 . ,($fire (apply #'$move (%move-1 (%aim 10 10) 1))))
                      `(30 . ,($fire (apply #'$move (%move-1 (%aim 10 10) 1))))))
          ,#'default-drawer))
    ))

(defun init-shooter (g)
  (let ((actors (init-actors)))
    (loop
      :for a :across actors
      :do (setf (actor-draw-fn a) #'default-drawer
                (actor-sfn a) (lambda () nil)))
    (setf (global-vm g) (make-vm :tick 0
                                 :actors actors
                                 :etable (make-event)))
  (lambda (renderer)
    (let ((vm (global-vm g)))
      (execute vm)
      (render-clear renderer)
      (set-render-draw-color renderer 0 0 25 255)
      (set-render-draw-blend-mode renderer :blend)
      (render-fill-rect renderer (make-rect 0 0 *screen-width* *screen-height*))
      (set-render-draw-blend-mode renderer :add)
      (loop
        :for a :across (vm-actors vm)
        :when (actor-available? a)
        :do (progn
              (funcall (actor-act-fn a) vm a (actor-sfn a))
              (funcall (actor-draw-fn a) renderer a)))
      (render-copy renderer (texture-texture (getf *game-images* :bg))
                   :dest-rect (make-rect 0 0 1200 800))
      (incf (vm-tick vm))))))
