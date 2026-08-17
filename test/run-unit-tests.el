;;; run-unit-tests.el --- Run the complete EIN unit suite  -*- lexical-binding:t -*-

(let ((directory (getenv "EIN_TEST_PACKAGE_DIR")))
  (when directory
    (setq package-user-dir directory)))

(require 'package)
(package-initialize)

(let* ((test-directory (file-name-directory
                        (or load-file-name buffer-file-name)))
       (root-directory (file-name-directory
                        (directory-file-name test-directory))))
  (add-to-list 'load-path (expand-file-name "lisp" root-directory))
  (add-to-list 'load-path test-directory)
  (load "testein")
  (dolist (file (directory-files test-directory t "\\`test-ein.*\\.el\\'"))
    (load file nil nil t)))

(ert-run-tests-batch-and-exit)

;;; run-unit-tests.el ends here
