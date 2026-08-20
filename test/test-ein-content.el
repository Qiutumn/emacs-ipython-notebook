;;; test-ein-content.el --- Testing content interface  -*- lexical-binding:t -*-

;; Copyright (C) 2015 John Miller

;; Authors: Takafumi Arakaki <aka.tkf at gmail.com>
;;          John M. Miller <millejoh at mac.com>

;; This file is NOT part of GNU Emacs.

;; test-ein-content.el is free software: you can redistribute it
;; and/or modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; test-ein-content.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with ein-testing-notebook.el.
;; If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'ein-contents-api)
(require 'ert)

(defvar *list-content-result* nil)

(defun ein-test-list-contents-1 ()
  (ein:content-list-contents "" )
  )

(ert-deftest ein:content-to-json-does-not-hide-encoding-errors ()
  (let ((content (make-ein:$content
                  :name "Untitled.ipynb"
                  :path "Untitled.ipynb"
                  :type "notebook"
                  :notebook-api-version 3
                  :raw-content '((metadata . invalid-json-object)))))
    (cl-letf (((symbol-function 'ein:json-encode)
               (lambda (&rest _args)
                 (error "deliberate encoding failure"))))
      (should-error (ein:content-to-json content)
                    :type 'error))))

(ert-deftest ein:content-save-error-reports-server-response-and-callback-data ()
  (let* ((response (make-request-response
                    :status-code 500
                    :error-thrown '(error http 500)))
         logged callback-args)
    (cl-letf (((symbol-function 'ein:log-wrapper)
               (lambda (_level message-function)
                 (setq logged (funcall message-function)))))
      (ein:content-save-error
       "http://127.0.0.1:8889/api/contents/Untitled.ipynb"
       (lambda (&rest args) (setq callback-args args))
       '(callback-prefix)
       :data "{\"message\": \"file is locked\"}"
       :response response
       :symbol-status 'error))
    (should (string-match-p "status 500" logged))
    (should (string-match-p "file is locked" logged))
    (should (equal callback-args
                   `(callback-prefix
                     :data "{\"message\": \"file is locked\"}"
                     :response ,response
                     :symbol-status error
                     :error-thrown nil)))))
