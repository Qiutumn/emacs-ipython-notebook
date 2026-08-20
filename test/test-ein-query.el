;;; test-ein-query.el --- Tests for EIN HTTP queries  -*- lexical-binding:t -*-

(require 'ert)
(require 'ein-query)

(ert-deftest ein:query-origin-key-includes-local-port ()
  (should (equal (ein:query-origin-key "http://localhost:8888/")
                 "http://127.0.0.1:8888"))
  (should (equal (ein:query-origin-key "http://127.0.0.1:8889/")
                 "http://127.0.0.1:8889"))
  (should (equal (ein:query-origin-key "ws://127.0.0.1:8889/api/kernels")
                 "http://127.0.0.1:8889"))
  (should-not
   (equal (ein:query-origin-key "http://127.0.0.1:8888/")
          (ein:query-origin-key "http://127.0.0.1:8889/"))))

(ert-deftest ein:query-local-cookie-jars-are-isolated-by-port ()
  (let ((request-storage-directory temporary-file-directory)
        (request--curl-cookie-jar nil))
    (should (equal (ein:query-cookie-jar "http://localhost:8888/")
                   (ein:query-cookie-jar "http://127.0.0.1:8888/")))
    (should-not
     (equal (ein:query-cookie-jar "http://127.0.0.1:8888/")
            (ein:query-cookie-jar "http://127.0.0.1:8889/")))))

(provide 'test-ein-query)

;;; test-ein-query.el ends here
