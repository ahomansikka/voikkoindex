;;; voikkoindex-mode.el --- Emacs-liittymä voikkoindex.sty -pakettiin.

;; Copyright (C) 2022-2023 Hannu Väisänen


;; Author: Hannu Väisänen
;; Maintainer: Hannu Väisänen
;; Created: 2022-10-21
;; URL: https://github.com/ahomansikka/voikkoindex
;; Keywords: text Finnish Voikko index

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; The license text: <http://www.gnu.org/licenses/gpl-3.0.html>



;; Esimerkkiä on katsottu Teemu Likosen ohjelmasta wcheck-mode.el
;; (https://github.com/tlikonen/wcheck-mode).

(eval-when-compile
  ;; Silence compiler.
  (declare-function show-entry "outline"))


;;;###autoload
(defgroup voikkoindex nil
  "Emacsin näppäimet voikkoindex.sty -pakettiin."
  :group 'applications)

(defvar voikkoindex-mode nil)
(defvar voikkoindex-mode-map (make-sparse-keymap)
  "Keymap for `voikkoindex-mode'.")


;;;###autoload
(define-minor-mode voikkoindex-mode
  "Liittymä voikkoindex.sty -pakettiin.

   Käyttöohjeet ovat tiedostossa ohje.tex"

  :init-value nil
  :lighter (" VX")
  :keymap voikkoindex-mode-map
  (message "Pantiin voikkoindex-mode päälle tai otettiin pois päältä.")
)



;;; Lisätään (viimeisen) sanan jälkeen "}" tai,
;;; jos sanan jälkeen tulee jokin merkeistä .;:;
;;; poistetaan välimerkki ja lisätään "}[.]" tai
;;; samalla tavalla muu välimerkki.
;;;
(defun voikkoindex--end (n)
  (interactive)
  (right-word n)
  (insert "}")
  (cond ((= (following-char) ?.) (goto-char (point)) (delete-char 1) (insert "[.]"))
        ((= (following-char) ?,) (goto-char (point)) (delete-char 1) (insert "[,]"))
        ((= (following-char) ?:) (goto-char (point)) (delete-char 1) (insert "[:]"))
        ((= (following-char) ?;) (goto-char (point)) (delete-char 1) (insert "[;]"))
  )
)

;;; Siirry sanan alkuun, paitsi jos ollaan jo sanan tai rivin alussa.
;;;
(defun voikkoindex--go-to-start-of-word()
  (if (not (looking-back "\\b")) (backward-word))
;;  (message "Huuhaa %s" (looking-back "\\b"))
)


(defun voikkoindex--f (s)
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert s)
  (voikkoindex--end 1)
)


;;; Johannes Angelokselle => \VXN{Johannes}{Angelokselle}
;;;
(defun voikkoindex--vxn()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXN{")
  (re-search-forward " +")
  (replace-match "}{")
  (voikkoindex--end 1)
)


;;; Johannes \emph{Angelokselle} => \VXN{Johannes}{\emph{Angelokselle}}
;;;
(defun voikkoindex--vxn-emph()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXN{")
  (re-search-forward " +[\\]emph{")
  (replace-match "}{\\\\emph{")
  (right-word 1)
  (if (looking-at "[.,:;]") (forward-char))
  (forward-char)
  (insert "}")
)


(defun voikkoindex--vxl()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXL{")
  (voikkoindex--end 2)
)


(defun voikkoindex--vxf()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXF{")
)

(defun voikkoindex--vxvon()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXVON{")
  (re-search-forward " +")
  (replace-match "}{")
  (re-search-forward " +")
  (replace-match "}{")
  (voikkoindex--end 1)
)


;;; Johannes Angelokselle  => \VXN{Johannes}{\emph{Angelokselle}}
;;; Johannes Angelokselle. => \VXN{Johannes}{\emph{Angelokselle.}}
;;; Johannes Angelokselle, => \VXN{Johannes}{\emph{Angelokselle,}}
;;; Johannes Angelokselle: => \VXN{Johannes}{\emph{Angelokselle:}}
;;;
(defun voikkoindex--emph()
  (interactive)
  (voikkoindex--go-to-start-of-word)
  (insert "\\VXN{")
  (re-search-forward " +")
  (replace-match "}{\\\\emph{")
  (right-word 1)
  (if (looking-at "[.,:;]") (forward-char))
  (insert "}}")
)


(defun voikkoindex--vxp() (interactive) (voikkoindex--f (setq  VXP "\\VXP{")))
(defun voikkoindex--vxs() (interactive) (voikkoindex--f (setq  VXS "\\VXS{")))
(defun voikkoindex--vxa() (interactive) (voikkoindex--f (setq  VXA "\\VXA{")))
(defun voikkoindex--vxi() (interactive) (voikkoindex--f (setq  VXI "\\VXI{")))
(defun voikkoindex--vxy() (interactive) (voikkoindex--f (setq  VXY "\\VXY{")))


(define-key voikkoindex-mode-map (kbd "ESC M-n") 'voikkoindex--vxn)
(define-key voikkoindex-mode-map (kbd "ESC M-p") 'voikkoindex--vxp)
(define-key voikkoindex-mode-map (kbd "ESC M-s") 'voikkoindex--vxs)
(define-key voikkoindex-mode-map (kbd "ESC M-a") 'voikkoindex--vxa)
(define-key voikkoindex-mode-map (kbd "ESC M-i") 'voikkoindex--vxi)
(define-key voikkoindex-mode-map (kbd "ESC M-y") 'voikkoindex--vxy)
(define-key voikkoindex-mode-map (kbd "ESC M-l") 'voikkoindex--vxl)
(define-key voikkoindex-mode-map (kbd "ESC M-f") 'voikkoindex--vxf)
(define-key voikkoindex-mode-map (kbd "ESC M-v") 'voikkoindex--vxvon)
(define-key voikkoindex-mode-map (kbd "ESC M-e") 'voikkoindex--emph)
(define-key voikkoindex-mode-map (kbd "ESC M-z") 'voikkoindex--vxn-emph)
