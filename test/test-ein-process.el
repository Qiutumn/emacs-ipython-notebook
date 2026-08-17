;; -*- lexical-binding:t -*-
(require 'ert)
(require 'ein-process)

(ert-deftest ein:process-check-suitable ()
  (should-not (equal (ein:process-suitable-notebook-dir (concat default-directory "features/support")) (concat default-directory "features/support"))))

(ert-deftest ein:process-divine ()
  (with-current-buffer "*scratch*"
    (erase-buffer))
  (ein:process-divine-dir 1 "" "*scratch*")
  (ein:process-divine-port 1 "" "*scratch*"))

(ert-deftest ein:process-refresh-processes-accepts-server-root-dir ()
  (let ((ein:%processes% (make-hash-table :test #'equal)))
    (cl-letf (((symbol-function 'ein:jupyter-process-lines)
               (lambda (&rest _args)
                 '("{\"pid\": 42, \"url\": \"http://localhost:8888/\", \"root_dir\": \"C:/notebooks\"}"))))
      (ein:process-refresh-processes)
      (let ((process (car (hash-table-values ein:%processes%))))
        (should process)
        (should (= (ein:$process-pid process) 42))
        (should (equal (downcase (ein:$process-dir process))
                       "c:/notebooks"))
        (should (equal (ein:$process-url process)
                       "http://127.0.0.1:8888"))))))
