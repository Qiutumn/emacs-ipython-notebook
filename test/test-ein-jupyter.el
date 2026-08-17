;; -*- lexical-binding:t -*-
(require 'ert)
(require 'ein-jupyter)

(ert-deftest ein:jupyter-command-parts-string-and-list ()
  (should (equal (ein:jupyter-command-parts "jupyter") '("jupyter")))
  (should (equal (ein:jupyter-command-parts '("python" "-m" "jupyter"))
                 '("python" "-m" "jupyter")))
  (should-error (ein:jupyter-command-parts '(42))))

(ert-deftest ein:jupyter-process-lines-preserves-fixed-arguments ()
  (let (invocation)
    (cl-letf (((symbol-function 'ein:jupyter-resolve-command)
               (lambda (_command) '("python.exe" "-m" "jupyter")))
              ((symbol-function 'call-process)
               (lambda (program _infile _destination _display &rest args)
                 (setq invocation (cons program args))
                 (insert "first\nsecond\n")
                 0)))
      (should (equal (ein:jupyter-process-lines
                      nil '("python.exe" "-m" "jupyter")
                      "server" "list" "--json")
                     '("first" "second")))
      (should (equal invocation
                     '("python.exe" "-m" "jupyter"
                       "server" "list" "--json"))))))

(ert-deftest ein:jupyter-server-run-preserves-fixed-arguments ()
  (let ((buffer-name " *ein-jupyter-command-test*")
        invocation)
    (unwind-protect
        (cl-letf (((symbol-function 'ein:jupyter-resolve-command)
                   (lambda (_command)
                     '("C:/Python/python.exe" "-m" "jupyter")))
                  ((symbol-function 'start-process)
                   (lambda (name buffer program &rest args)
                     (setq invocation (list name buffer program args))
                     'test-process))
                  ((symbol-function 'set-process-query-on-exit-flag) #'ignore)
                  ((symbol-function 'ein:debug-p) (lambda () nil)))
          (let ((ein:jupyter-server-use-subcommand "server")
                (ein:jupyter-server-args '("--no-browser")))
            (should (eq (ein:jupyter-server--run
                         buffer-name '("python.exe" "-m" "jupyter")
                         "C:/notebooks" '("--port" "9000"))
                        'test-process))
            (should (equal
                     invocation
                     (list *ein:jupyter-server-process-name*
                           buffer-name
                           "C:/Python/python.exe"
                           '("-m" "jupyter" "server"
                             "--notebook-dir=C:/notebooks"
                             "--port" "9000" "--no-browser"))))))
      (when (get-buffer buffer-name)
        (kill-buffer buffer-name)))))

(ert-deftest ein:jupyter-my-url-falls-back-to-root-directory ()
  (let ((directory (file-name-as-directory temporary-file-directory)))
    (cl-letf (((symbol-function 'ein:jupyter-server-process)
               (lambda () 'test-process))
              ((symbol-function 'process-id) (lambda (_process) 101))
              ((symbol-function 'ein:jupyter-running-notebook-directory)
               (lambda () directory))
              ((symbol-function 'ein:jupyter-crib-running-servers)
               (lambda ()
                 `((:pid 202 :url "http://localhost:8888/"
                         :root_dir ,directory)))))
      (should (equal (ein:jupyter-my-url-or-port)
                     "http://127.0.0.1:8888")))))

(ert-deftest ein:jupyter-my-url-prefers-process-id ()
  (let ((directory (file-name-as-directory temporary-file-directory)))
    (cl-letf (((symbol-function 'ein:jupyter-server-process)
               (lambda () 'test-process))
              ((symbol-function 'process-id) (lambda (_process) 101))
              ((symbol-function 'ein:jupyter-running-notebook-directory)
               (lambda () directory))
              ((symbol-function 'ein:jupyter-crib-running-servers)
               (lambda ()
                 `((:pid 202 :url "http://localhost:8888/"
                         :root_dir ,directory)
                   (:pid 101 :url "http://localhost:9999/"
                         :root_dir "C:/other")))))
      (should (equal (ein:jupyter-my-url-or-port)
                     "http://127.0.0.1:9999")))))

(ert-deftest ein:jupyter-my-url-rejects-ambiguous-root-directory ()
  (let ((directory (file-name-as-directory temporary-file-directory)))
    (cl-letf (((symbol-function 'ein:jupyter-server-process)
               (lambda () 'test-process))
              ((symbol-function 'process-id) (lambda (_process) 101))
              ((symbol-function 'ein:jupyter-running-notebook-directory)
               (lambda () directory))
              ((symbol-function 'ein:jupyter-crib-running-servers)
               (lambda ()
                 `((:pid 202 :url "http://localhost:8888/"
                         :root_dir ,directory)
                   (:pid 303 :url "http://localhost:9999/"
                         :root_dir ,directory)))))
      (should-not (ein:jupyter-my-url-or-port)))))
