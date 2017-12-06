(defpackage :lem-vi-mode.core
  (:use :cl
        :lem
        :lem.universal-argument)
  (:export :*enable-hook*
           :*disable-hook*
           :vi-mode
           :define-vi-state
           :current-state
           :change-state
           :with-state
           :*command-keymap*
           :*insert-keymap*
           :command
           :insert))
(in-package :lem-vi-mode.core)

(defvar *enable-hook* '())
(defvar *disable-hook* '())

(defun enable-hook ()
  (run-hooks *enable-hook*))

(defun disable-hook ()
  (run-hooks *disable-hook*))

(define-minor-mode vi-mode
    (:global t
     :enable-hook #'enable-hook
     :disable-hook #'disable-hook))


(defvar *modeline-element*)

(define-attribute state-attribute
  (t :reverse-p t))

(defstruct (vi-modeline-element (:conc-name element-))
  name)

(defmethod convert-modeline-element ((element vi-modeline-element) window)
  (values (element-name element) 'state-attribute))

(defun initialize-vi-modeline ()
  (setf *modeline-element* (make-vi-modeline-element))
  (modeline-add-status-list *modeline-element*))

(defun finalize-vi-modeline ()
  (modeline-remove-status-list *modeline-element*))

(defun change-element-name (name)
  (setf (element-name *modeline-element*) name))


(defstruct vi-state
  name
  keymap
  function)

(defvar *current-state*)

(defmacro define-vi-state (name (&key keymap) &body body)
  `(setf (get ',name 'state)
         (make-vi-state :name ',name :keymap ,keymap :function (lambda () ,@body))))

(defun current-state ()
  *current-state*)

(defun change-state (name)
  (let ((state (get name 'state)))
    (assert (vi-state-p state))
    (setf *current-state* name)
    (setf (mode-keymap 'vi-mode) (vi-state-keymap state))
    (change-element-name (format nil "[~A]" name))
    (funcall (vi-state-function state))))

(defmacro with-state (state &body body)
  (alexandria:with-gensyms (old-state)
    `(let ((,old-state (current-state)))
       (change-state ,state)
       (unwind-protect (progn ,@body)
         (change-state ,old-state)))))


(defvar *command-keymap* (make-keymap :name '*command-keymap* :insertion-hook 'undefined-key))
(defvar *insert-keymap* (make-keymap :name '*insert-keymap*))
(defvar *inactive-keymap* (make-keymap))

(define-vi-state command (:keymap *command-keymap*))

(define-vi-state insert (:keymap *insert-keymap*)
  (message " -- INSERT --"))

(define-vi-state modeline (:keymap *inactive-keymap*))

(defun minibuffer-activate-hook () (change-state 'modeline))
(defun minibuffer-deactivate-hook () (change-state 'command))

(add-hook *enable-hook*
          (lambda ()
            (initialize-vi-modeline)
            (change-state 'command)
            (add-hook *minibuffer-activate-hook* 'minibuffer-activate-hook)
            (add-hook *minibuffer-deactivate-hook* 'minibuffer-deactivate-hook)))

(add-hook *disable-hook*
          (lambda ()
            (finalize-vi-modeline)
            (remove-hook *minibuffer-activate-hook* 'minibuffer-activate-hook)
            (remove-hook *minibuffer-deactivate-hook* 'minibuffer-deactivate-hook)))
