;;; spine-client.el --- client code for interacting with the perl backend  -*- lexical-binding: t; -*-
;; Copyright (C) 2024  Mark Walker

;; Author: Mark Walker
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defcustom spine-perl-command "perl" "The command used to run the inferior perl process")

(defvar spine-listen-port 43659
  "port of the server")

(defvar spine-listen-host "127.0.0.1"
    "host of the server")


(defvar *spine-client-process* nil)

(defvar *spine-repl* "perl REPL")

(defvar *spine-inferior-perl-process* nil)

(defvar *spine-inferior-perl* "*inferior-perl*")

(defvar *spine-repl-prompt* "perl> ")

(defvar *spine-inferior-server-command* nil)

(defvar-local spine-repl-history '())
(defvar-local spine-repl-history-recall-index 0)

(setq *spine-inferior-server-command*
      (if load-file-name
	  (format "%s %s/spine-server/spine-server.pl" spine-perl-command (file-name-directory load-file-name))
        (error "[spine] ERROR: cannot determine load path")))


(cl-defun sp-try-connect-listener ()
  "Repeatedly attempts to connect to the spine server as it starts up"
  (named-let retry ((num-attempts 0))
    (if (< num-attempts 30) ;; ~3 seconds
	(let (proc)
	  (condition-case err
	      (setq proc
		    (make-network-process :name *spine-repl*
				      :buffer *spine-repl*
				      :family 'ipv4
				      :host spine-listen-host
				      :service spine-listen-port
				      :sentinel #'sp-listen-sentinel
				      :filter #'sp-listen-filter))
	(file-error
	 (sleep-for 0.1)
	 (retry (1+ num-attempts)))
	(:success
	 (setq *spine-client-process* proc))))
      (message "spine failed to connect to server"))))

(defun sp-listen-start nil
    "starts an emacs tcp client listener"
    (and (process-live-p *spine-client-process*)
	 (delete-process *spine-client-process*))
    (sp-try-connect-listener))

(defun sp-listen-sentinel (proc msg)
  (when (string= msg "connection broken by remote peer\n")
    (message (format "client %s has quit" proc))))

(defun sp-send-string (str)
  (process-send-string
   *spine-client-process*
   (concat str "\n")))

(defun sp-eval-string (str)
  (sp-send-string
   (json-encode `(:eval ,str))))

(defun sp-load-file (fname)
  (interactive (list (read-file-name "load file: " nil nil nil (file-name-nondirectory (buffer-file-name)))))
  (sp-send-string
   (json-encode `(:load ,fname))))

(defun sp-doc-on-string (str)
  (sp-send-string
   (json-encode `(:doc ,str))))

(defun sp-doc-on-region (beg end)
  (interactive "r")
  (let ((str (buffer-substring-no-properties beg end)))
    (sp-send-string
     (json-encode `(:doc ,str)))))

(defun sp-eval-region (beg end)
  (interactive "r")
  (let ((code (buffer-substring-no-properties beg end)))
    (sp-eval-string code)))

(defun sp-eval-line ()
  (interactive)
  (let ((code (buffer-substring-no-properties
	       (point-at-bol)
	       (point-at-eol))))
    (sp-eval-string code)))


(defun sp-eval-sub ()
  (interactive)
  (let (pmin pmax)
    (save-excursion
      (setq pmin (search-backward-regexp "^sub"))
      (setq pmax (search-forward-regexp "^}\s*$")))
    (sp-eval-string
     (buffer-substring-no-properties pmin pmax))))


(defun sp-eval-dwim ()
  (interactive)
  (let ((code (buffer-substring-no-properties
	       (if (region-active-p) (region-beginning) (point-at-bol))
	       (if (region-active-p) (region-end) (point-at-eol)))))
    (sp-eval-string code)))



(defun sp-create-repl ()
  (with-current-buffer (get-buffer-create *spine-repl*)
    (sp-repl-mode)
    (sp-insert-repl-prompt)
    (pop-to-buffer *spine-repl*)))


(defun sp-insert-to-repl (str)
  (save-excursion
    (with-current-buffer *spine-repl*
      (let ((inhibit-read-only t))
	(goto-char (point-max))
	(search-backward-regexp (concat "^" *spine-repl-prompt*))
	(insert (propertize (concat str "\n") 'read-only t 'rear-nonsticky t 'front-sticky t))))))



(cl-defun sp-insert-repl-prompt (&optional (newline t))
  (with-current-buffer *spine-repl*
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert (propertize (concat (if newline "\n" "") *spine-repl-prompt*)
			  'read-only t 'rear-nonsticky t
			  'font-lock-face '(:foreground "blue"))))))


(defun sp-repl-send ()
  (interactive)
  (let (beg end str)
    (save-excursion
      (setq beg (point))
      (search-backward-regexp (concat "^" *spine-repl-prompt*))
      (setq end (+ (length *spine-repl-prompt*) (point)))
      (setq str (buffer-substring-no-properties beg end))
      (put-text-property beg end 'read-only t)
      (sp-insert-repl-prompt)
      (sp-eval-string str)
      (or (string= str "")
	  (push str spine-repl-history))
      (setq sp-repl-history-recall-index 0)))
  (goto-char (point-max)))

(defun sp-insert-history (n)
  (with-current-buffer *spine-repl*
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (search-backward-regexp (concat "^" *spine-repl-prompt*))
      (delete-line)
      (sp-insert-repl-prompt nil)
      (insert (nth n sp-repl-history)))))

(defun sp-insert-prev-history ()
  (interactive)
  (sp-insert-history sp-repl-history-recall-index)
  (and (< (+ 1 sp-repl-history-recall-index)
	  (length sp-repl-history))
       (cl-incf sp-repl-history-recall-index)))

(defun sp-insert-next-history ()
  (interactive)
  (and (> sp-repl-history-recall-index 0)
       (cl-decf sp-repl-history-recall-index)
       (sp-insert-history sp-repl-history-recall-index)))

(defun sp-listen-filter (proc response)
  (let ((res (json-read-from-string response))
	toshow)
    (and (assoc 'error res)
	 (add-to-list 'toshow (propertize (concat (alist-get 'error res) "\n")
					  'font-lock-face '(:foreground "red"))))
    (and (assoc 'result res)
	 (add-to-list 'toshow (alist-get 'result res)))
    (and (assoc 'output res)
	 (add-to-list 'toshow (propertize (concat (alist-get 'output res) "\n")
					  'font-lock-face '(:foreground "magenta"))))
    (sp-insert-to-repl (cl-reduce #'concat toshow))))

(defun sp-run-inferior-perl ()
  (and (process-live-p "inferior-perl")
       (yes-or-no-p "An inferior perl process is already running, kill it first?")
       (delete-process "inferior-perl"))
  (setq *spine-inferior-perl-process*
	(start-process-shell-command "inferior-perl" *spine-inferior-perl* *spine-inferior-server-command*)))

(defun sp-run ()
  (interactive)
  (sp-run-inferior-perl)
  (and (process-live-p *spine-repl*)
       (yes-or-no-p "A spine repl process is already running, kill it first?")
       (delete-process *spine-repl*))
  (sp-listen-start)
  (sp-create-repl))


(provide 'spine-client)
;;; spine-client.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("sp-" . "spine-"))
;; End:
