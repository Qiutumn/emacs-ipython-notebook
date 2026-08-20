;; -*- lexical-binding:t -*-
(require 'ein-notebooklist)
(require 'ein-testing-notebook)

(defun eintest:notebooklist-make-empty (&optional url-or-port)
  "Make empty notebook list buffer."
  (let ((url-or-port (or url-or-port ein:testing-notebook-dummy-url)))
    (cl-letf (((symbol-function 'ein:need-kernelspecs) #'ignore)
              ((symbol-function 'ein:content-query-sessions) #'ignore))
      (ein:notebooklist-open--finish url-or-port #'ignore
        (make-ein:$content :url-or-port url-or-port
                           :notebook-api-version "5"
                           :path "")))))

(defmacro eintest:notebooklist-is-empty-context-of (func)
  `(ert-deftest ,(intern (format "%s--notebooklist" func)) ()
     (with-current-buffer (eintest:notebooklist-make-empty)
       (should-not (,func)))))

(ert-deftest ein:get-url-or-port--notebooklist ()
  (with-current-buffer (eintest:notebooklist-make-empty)
    (should (equal (ein:get-url-or-port) ein:testing-notebook-dummy-url))))

(ert-deftest ein:notebooklist-clean-token-url ()
  (should
   (equal (ein:notebooklist--clean-url-and-token
           "http://localhost:8889/?token=a%2Bb")
          '("http://127.0.0.1:8889" . "a+b")))
  (should
   (equal (ein:notebooklist--clean-url-and-token
           "https://example.test/jupyter/?view=tree&token=test-token#ignored")
          '("https://example.test/jupyter?view=tree" . "test-token"))))

(ert-deftest ein:notebooklist-login-accepts-token-url ()
  (let (login-arguments)
    (cl-letf (((symbol-function 'ein:notebooklist-login--iteration)
               (lambda (&rest arguments)
                 (setq login-arguments arguments)))
              ((symbol-function 'ein:notebooklist-token-or-password)
               (lambda (_url-or-port)
                 (ert-fail "A pasted token URL should not query credentials"))))
      (ein:notebooklist-login
       "http://localhost:8889/?token=test-token" #'ignore)
      (should
       (equal login-arguments
              '("http://127.0.0.1:8889" ignore nil "test-token" 0 nil))))))

(eintest:notebooklist-is-empty-context-of ein:get-notebook)
(eintest:notebooklist-is-empty-context-of ein:get-kernel)
(eintest:notebooklist-is-empty-context-of ein:get-cell-at-point)
(eintest:notebooklist-is-empty-context-of ein:get-traceback-data)
