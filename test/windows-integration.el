;;; windows-integration.el --- Native Windows Jupyter integration  -*- lexical-binding:t -*-

;; Run with:
;;   emacs --batch -Q -l test/windows-integration.el
;; EIN_TEST_PYTHON may name the Python executable that provides Jupyter.
;; EIN_TEST_JUPYTER_SUBCOMMAND may be "server" (default) or "notebook".

(unless (eq system-type 'windows-nt)
  (error "This integration test requires native Windows Emacs"))

(setq load-prefer-newer t)

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
  (setq default-directory root-directory))

(require 'ein-jupyter)
(require 'ein-notebook)
(require 'ein-notebooklist)

(defun eintest:windows-wait-until (predicate timeout label)
  "Wait up to TIMEOUT seconds for PREDICATE while servicing processes."
  (let ((deadline (+ (float-time) timeout)))
    (while (and (not (funcall predicate))
                (< (float-time) deadline))
      (accept-process-output nil 0.1))
    (unless (funcall predicate)
      (error "Timed out waiting for %s" label))))

(let* ((python (or (getenv "EIN_TEST_PYTHON")
                   (executable-find "python")))
       (_ (unless python
            (error "Set EIN_TEST_PYTHON to a Python executable with Jupyter")))
       (subcommand (or (getenv "EIN_TEST_JUPYTER_SUBCOMMAND") "server"))
       (_ (unless (member subcommand '("server" "notebook"))
            (error "EIN_TEST_JUPYTER_SUBCOMMAND must be server or notebook")))
       (command (list python "-m" "jupyter"))
       (directory (make-temp-file "ein-native-windows-" t))
       (listener (make-network-process :name "ein-port-probe"
                                       :server t :host "127.0.0.1"
                                       :service t :noquery t))
       (port (process-contact listener :service))
       (token "ein-native-windows-test")
       url notebook login-buffer notebook-ready saved save-error
       new-notebook new-notebook-ready new-notebook-saved
       new-notebook-save-error failure)
  (delete-process listener)
  (copy-file (expand-file-name "features/undo.ipynb" default-directory)
             (expand-file-name "native-windows.ipynb" directory))
  (setq ein:jupyter-server-command command
        ein:jupyter-server-use-subcommand subcommand
        ein:jupyter-server-args
        (append
         '("--no-browser")
         (if (string= subcommand "notebook")
             '("--NotebookApp.token=ein-native-windows-test"
               "--NotebookApp.password=")
           '("--IdentityProvider.token=ein-native-windows-test"
             "--ServerApp.password="))))
  (unwind-protect
      (condition-case err
          (progn
            (ein:jupyter-server-start command directory t nil port)
            (setq url (ein:jupyter-my-url-or-port))
            (unless (and url (process-live-p (ein:jupyter-server-process)))
              (error "Native Jupyter server was not discovered"))
            (message "Native Windows server discovery: %s" url)

            (ein:notebooklist-login
             (concat url "/?token=" token)
             (lambda (buffer _url)
               (setq login-buffer buffer))
             nil nil nil)
            (eintest:windows-wait-until
             (lambda () (buffer-live-p login-buffer)) 30 "EIN login")

            (setq notebook
                  (ein:notebook-open
                   url "native-windows.ipynb" "python3"
                   (lambda (_notebook _created)
                     (setq notebook-ready t))
                   (lambda (&rest args)
                     (error "Notebook open failed: %S" args))
                   t))
            (eintest:windows-wait-until
             (lambda () notebook-ready) 45 "notebook and kernel startup")

            (let* ((worksheet (car (ein:$notebook-worksheets notebook)))
                   (cell (car (ein:worksheet-get-cells worksheet))))
              (with-current-buffer (ein:cell-buffer cell)
                (ein:cell-set-text cell "print('EIN_NATIVE_WINDOWS_OK')")
                (ein:cell-execute cell))
              (eintest:windows-wait-until
               (lambda () (not (slot-value cell 'running)))
               30 "kernel execution")
              (unless (string-match-p
                       "EIN_NATIVE_WINDOWS_OK"
                       (format "%S" (slot-value cell 'outputs)))
                (error "Kernel output missing: %S"
                       (slot-value cell 'outputs))))

            (ein:notebook-save-notebook
             notebook (lambda () (setq saved t)) nil
             (lambda (&rest args)
               (setq save-error args)))
            (eintest:windows-wait-until
             (lambda () (or saved save-error)) 30 "notebook save")
            (when save-error
              (error "Notebook save failed: %S" save-error))
            (with-temp-buffer
              (insert-file-contents
               (expand-file-name "native-windows.ipynb" directory))
              (unless (search-forward "EIN_NATIVE_WINDOWS_OK" nil t)
                (error "Saved notebook does not contain executed source")))
            (message "Native Windows execute and save: ok")

            (ein:notebooklist-new-notebook
             url "python3"
             (lambda (created-notebook _created)
               (setq new-notebook created-notebook
                     new-notebook-ready t))
             t nil "")
            (eintest:windows-wait-until
             (lambda () new-notebook-ready) 45 "new notebook and kernel startup")
            (let* ((worksheet (car (ein:$notebook-worksheets new-notebook)))
                   (cell (car (ein:worksheet-get-cells worksheet))))
              (unless cell
                (error "New notebook has no editable cell"))
              (with-current-buffer (ein:cell-buffer cell)
                (ein:cell-set-text cell "print('EIN_NEW_NOTEBOOK_SAVE_OK')")))
            (ein:notebook-save-notebook
             new-notebook (lambda () (setq new-notebook-saved t)) nil
             (lambda (&rest args)
               (setq new-notebook-save-error args)))
            (eintest:windows-wait-until
             (lambda () (or new-notebook-saved new-notebook-save-error))
             30 "new notebook save")
            (when new-notebook-save-error
              (error "New notebook save failed: %S"
                     new-notebook-save-error))
            (with-temp-buffer
              (insert-file-contents
               (expand-file-name
                (ein:$notebook-notebook-path new-notebook) directory))
              (unless (search-forward "EIN_NEW_NOTEBOOK_SAVE_OK" nil t)
                (error "Newly saved notebook does not contain edited source")))
            (message "Native Windows create and save new notebook: ok")

            (let* ((worksheet (car (ein:$notebook-worksheets new-notebook)))
                   (cell (car (ein:worksheet-get-cells worksheet))))
              (with-current-buffer (ein:cell-buffer cell)
                (ein:cell-set-text
                 cell "print('EIN_NEW_NOTEBOOK_CLOSE_SAVE_OK')")))
            (cl-letf (((symbol-function 'y-or-n-p)
                       (lambda (&rest _args) t)))
              (unless (ein:notebook-ask-save new-notebook)
                (error "Synchronous save before close failed")))
            (with-temp-buffer
              (insert-file-contents
               (expand-file-name
                (ein:$notebook-notebook-path new-notebook) directory))
              (unless (search-forward "EIN_NEW_NOTEBOOK_CLOSE_SAVE_OK" nil t)
                (error "Close-saved notebook does not contain edited source")))
            (message "Native Windows save before close: ok")

            (ein:jupyter-server-stop nil url)
            (eintest:windows-wait-until
             (lambda ()
               (let ((process (ein:jupyter-server-process)))
                 (or (not process) (not (process-live-p process)))))
             15 "Jupyter shutdown")
            (with-current-buffer *ein:jupyter-server-buffer-name*
              (goto-char (point-min))
              (when (search-forward "Notebook JSON is invalid" nil t)
                (error "Jupyter rejected EIN's saved notebook JSON")))
            (message "Native Windows shutdown: ok"))
        (error (setq failure err)))
    (when-let ((process (ein:jupyter-server-process)))
      (when (process-live-p process)
        (delete-process process)))
    (when (get-buffer *ein:jupyter-server-buffer-name*)
      (when failure
        (with-current-buffer *ein:jupyter-server-buffer-name*
          (message "Jupyter server log:\n%s" (buffer-string))))
      (with-current-buffer *ein:jupyter-server-buffer-name*
        (setq kill-buffer-query-functions nil))
      (kill-buffer *ein:jupyter-server-buffer-name*))
    (delete-directory directory t))
  (when failure
    (signal (car failure) (cdr failure))))

(message "Native Windows EIN integration test passed")

;;; windows-integration.el ends here
