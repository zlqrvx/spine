;;; spine.el --- Interactive evaluation of perl code  -*- lexical-binding: t; -*-
;; Copyright (C) 2024  Mark Walker

;; Author: Mark Walker
;; Keywords:languages

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

;; spine is a mode for evaluating perl expressions in an interactive REPL.

;;; Code:

(require 'spine-client "spine-client.el")

;;
;; Minor mode for interacting from perl scripts
;;
(defvar spine-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-s") #'spine-eval-sub)
    (define-key map (kbd "C-c C-c") #'spine-eval-dwim)
    (define-key map (kbd "C-c C-l") #'spine-load-file)
    (define-key map (kbd "C-c C-z") #'spine-run)
    map)
  "Keymap for `spine-mode'.")

(define-minor-mode spine-mode
  "Simple Perl INteractive Evaluation mode"
  :lighter " spine"
  :keymap spine-mode-map)


;;
;; major mode for the repl buffer
;;
(defvar-keymap spine-repl-mode-map
  "RET" #'spine-repl-send
  "M-p" #'spine-insert-prev-history
  "M-n" #'spine-insert-next-history)

(define-derived-mode spine-repl-mode
  fundamental-mode "spine"
  "Major mode for interacting with the spine REPL")


(provide 'spine)
;;; spine.el ends here

