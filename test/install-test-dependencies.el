;;; install-test-dependencies.el --- Install EIN test dependencies  -*- lexical-binding:t -*-

(let ((directory (getenv "EIN_TEST_PACKAGE_DIR")))
  (when directory
    (setq package-user-dir directory)))

(require 'package)
(require 'package-vc)

(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")))

(package-initialize)

;; Current with-editor releases require compat 31.  Installing compat from its
;; pinned official repository avoids intermittent GNU/NonGNU archive-index TLS
;; failures on the Windows runner while keeping the dependency reproducible.
(unless (package-installed-p 'compat '(31 0))
  (package-vc-install
   '(compat :url "https://github.com/emacs-compat/compat"
            :vc-backend Git)
   "df03e91f1fc47503ca71e11dd507ed18ca8b5ab0"))

(package-refresh-contents)

(dolist (dependency '(anaphora dash deferred f mocker polymode
                               request websocket with-editor))
  (unless (package-installed-p dependency)
    (package-install dependency)))

(message "EIN test dependencies installed")

;;; install-test-dependencies.el ends here
