;;; install-test-dependencies.el --- Install EIN test dependencies  -*- lexical-binding:t -*-

(let ((directory (getenv "EIN_TEST_PACKAGE_DIR")))
  (when directory
    (setq package-user-dir directory)))

(require 'package)

(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

(package-initialize)
(package-refresh-contents)

(dolist (dependency '(anaphora dash deferred f mocker polymode
                               request websocket with-editor))
  (unless (package-installed-p dependency)
    (package-install dependency)))

(message "EIN test dependencies installed")

;;; install-test-dependencies.el ends here
