;;; v2ex-mode.el --- visiting v2ex.com site in emacs

;; Copyright (C) 2016 Aborn Jiang

;; Author: Aborn Jiang <aborn.jiang@gmail.com>
;; Version: 1.0
;; Package-Requires: ((cl-lib "0.5"))
;; Keywords: v2ex, v2ex.com
;; Homepage: https://github.com/aborn/v2ex-mode
;; URL: https://github.com/aborn/v2ex-mode

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Source code
;;
;; v2ex-mode code can be found here:
;;   http://github.com/aborn/v2ex-mode

;;; Commentary:

;; visiting ve2x.com freely in emacs.
;; M-x v2ex

;;; Code:

(require 'cl-lib)
(require 'json)

(defvar v2ex-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map widget-keymap)
    (define-key map "r" 'v2ex)
    (define-key map "h" 'v2ex/hot)
    (define-key map "l" 'v2ex/latest)
    (define-key map "q" 'v2ex/quit)
    map)
  "major mode for visiting v2ex.com")

(defvar v2ex-entry-format "%N. %[%T%] (%U@%S ,%R个回复)\n")

(define-derived-mode v2ex-mode nil "v2ex-mode"
  "Major mode for visit http://v2ex.com/"
  (widen)
  :group 'v2ex-mode)

(defcustom v2ex/buffer-name "*v2ex*"
  "the content display buffer name"
  :group 'v2ex-mode
  :type 'string)

(defcustom v2ex/hot-api-uri "https://www.v2ex.com/api/topics/hot.json"
  "the hot topic api"
  :group 'v2ex-mode
  :type 'string)

(defvar v2ex-current-visit
  '(:name "latest" :url v2ex/latest-api-uri :desc "最新主题")
  "the current visit")

(defcustom v2ex/latest-api-uri "https://www.v2ex.com/api/topics/latest.json"
  "the url of latest topics api"
  :group 'v2ex-mode
  :type 'string)

(defun v2ex/quit ()
  "quit the v2ex buffer"
  (interactive)
  (let ((buffer (current-buffer)))
    (unless (one-window-p)
      (delete-window))
    (kill-buffer buffer)))

(defun v2ex/read-http-data-as-json (http-data)
  (with-temp-buffer
    (insert http-data)
    (goto-char (point-min))
    (re-search-forward "^$")
    (json-read-from-string (buffer-substring (point) (point-max)))))

(defun v2ex/do-ajax-action (url &optional type)
  "get build status info"
  (let* ((buffer (url-retrieve-synchronously url))
         (http-content nil)
         (json-data nil)
         (result-data nil))
    (if (not buffer)
        (error "请求%s服务失败，请重试！"
               ;; FIXME What is this? I can't find the definition
               v2ex/build-status-url))
    (with-current-buffer buffer
      (unless (= 200 (url-http-parse-response)))
      (setq http-content (decode-coding-string (buffer-string) 'utf-8))
      ;; (message http-content)
      (if (string= type "html")
          (setq result-data http-content)
        (progn (setq json-data (v2ex/read-http-data-as-json http-content))
               ;; (princ json-data)
               (setq result-data json-data))))
    result-data))

;;;###autoload
(defun v2ex ()
  "open v2ex mode"
  (interactive)
  (message "open v2ex.com")
  (let* ((v2ex-buffer (get-buffer-create v2ex/buffer-name))
         (json-content nil)
         (url (eval (plist-get v2ex-current-visit :url)))
         (site-name (plist-get v2ex-current-visit :name))
         (site-desc (plist-get v2ex-current-visit :desc))
         (num 0))
    (with-current-buffer v2ex-buffer
      (v2ex-mode)
      (setq json-content (v2ex/do-ajax-action url))
      (erase-buffer)
      (insert (format "  %s ----- time:%s\n" site-desc
                      (format-time-string "%Y-%m-%d %H:%M:%S" (current-time))))
      (while (< num (length json-content))
        (let* ((item (aref json-content num))
               (url (assoc-default 'url item))
               (replies (assoc-default 'replies item)))
          (widget-create (v2ex/make-entry item num))
          )
        (setq num (1+ num))
        )
      (widget-setup)
      (goto-char (point-min))
      ))
  (unless (get-buffer-window v2ex/buffer-name)
    (if (one-window-p)
        (switch-to-buffer v2ex/buffer-name)
      (switch-to-buffer-other-window v2ex/buffer-name)))
  (message "v2ex updated!"))

;;;###autoload
(defun v2ex/latest ()
  "open v2ex latest topics"
  (interactive)
  (setq v2ex-current-visit
        '(:name "latest" :url v2ex/latest-api-uri :desc "最新主题")
        )
  (v2ex))

;;;###autoload
(defun v2ex/hot ()
  "open v2ex hot topics"
  (interactive)
  (setq v2ex-current-visit
        '(:name "hot" :url v2ex/hot-api-uri :desc "最热主题")
        )
  (v2ex))

(define-widget 'v2ex-entry 'url-link
  "A widget representing a v2ex entry."
  :format-handler 'v2ex-entry-format)

(defun v2ex/make-entry (data n)
  (let ()
    (v2ex/alet (title url replies id member node)
               data
               (list 'v2ex-entry
                     :format v2ex-entry-format
                     :value url
                     :help-echo url
                     :tab-order n
                     :v2ex-n n
                     :v2ex-title title
                     :v2ex-id id
                     :v2ex-member member
                     :v2ex-node node
                     :v2ex-replies replies))))

(defun v2ex-entry-format (widget char)
  (cl-case char
    (?N (insert (format "%3d" (1+ (widget-get widget :v2ex-n)))))
    (?T (insert (truncate-string-to-width (widget-get widget :v2ex-title) 80 nil nil t)))
    (?U (insert (format "%s" (assoc-default 'username (widget-get widget :v2ex-member)))))
    (?S (insert (format "%s" (assoc-default 'title (widget-get widget :v2ex-node)))))
    (?R (insert (format "%d" (widget-get widget :v2ex-replies))))
    (t (widget-default-format-handler widget char))))

(defmacro v2ex/alet (vars alist &rest forms)
  (let ((alist-var (make-symbol "alist")))
    `(let* ((,alist-var ,alist)
            ,@(cl-loop for var in vars
                       collecting `(,var (assoc-default ',var ,alist-var))))
       ,@forms)))

(provide 'v2ex-mode)
;;; v2ex-mode.el ends here
