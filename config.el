;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
(setq evil-escape-key-sequence nil)

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Aaron Trachtman"
      user-mail-address "aaron.trachtman@urbint.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Documents/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)
(menu-bar-mode t)

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; https://github.com/wandersoncferreira/code-review/issues/116#issuecomment-996384127
;; https://github.com/wandersoncferreira/code-review/pull/178
;; Not currently working
(defmacro code-review-ediff-buffers (quit &rest spec)
  (declare (indent 1))
  (let ((fn (if (= (length spec) 3) 'ediff-buffers3 'ediff-buffers))
        (char ?@)
        get make kill)
    (pcase-dolist (`(,g ,m) spec)
      (let ((b (intern (format "buf%c" (cl-incf char)))))
        (push `(,b ,g) get)
        (push `(if ,b
                   (if magit-ediff-use-indirect-buffers
                       (prog1
                           (make-indirect-buffer
                            ,b (generate-new-buffer-name (buffer-name ,b)) t)
                         (setq ,b nil))
                     ,b)
                 ,m)
              make)
        (push `(unless ,b
                 (ediff-kill-buffer-carefully
                  ,(intern (format "ediff-buffer-%c" char))))
              kill)))
    (setq get  (nreverse get))
    (setq make (nreverse make))
    (setq kill (nreverse kill))
    `(let ((conf (current-window-configuration))
           ,@get)
       (,fn
        ,@make
        (list (lambda ()
                (setq-local
                 ediff-quit-hook
                 (list ,@(and quit (list quit))
                       (lambda ()
                         ,@kill
                         (let ((magit-ediff-previous-winconf conf))
                           (run-hooks 'magit-ediff-quit-hook)))))))
        ',fn))))

(defun code-review-ediff-compare (revA revB fileA fileB)
  "Compare REVA:FILEA with REVB:FILEB using Ediff.
FILEA and FILEB have to be relative to the top directory of the
repository.  If REVA or REVB is nil, then this stands for the
working tree state.
If the region is active, use the revisions on the first and last
line of the region.  With a prefix argument, instead of diffing
the revisions, choose a revision to view changes along, starting
at the common ancestor of both revisions (i.e., use a \"...\"
range)."
  (interactive)
  (code-review-ediff-buffers nil
    ((if revA (magit-get-revision-buffer revA fileA) (get-file-buffer    fileA))
     (if revA (magit-find-file-noselect  revA fileA) (find-file-noselect fileA)))
    ((if revB (magit-get-revision-buffer revB fileB) (get-file-buffer    fileB))
     (if revB (magit-find-file-noselect  revB fileB) (find-file-noselect fileB)))))

(defun code-review-ediff-compare-file-at-point ()
  (interactive)
  (let* ((forge-pr
          (-first-item
           (mapcar
            (lambda (row)
              (closql--remake-instance 'forge-pullreq (forge-db) row))
            (forge-sql
             [:select $i1 :from pullreq
              :join repository :on (= repository:id pullreq:repository)
              :where (and (= repository:owner "eval-all-software")
                          (= repository:name "tempo")
                          (= pullreq:number 107))]
             (vconcat (closql--table-columns (forge-db) 'pullreq t))))))
         (default-directory "~/code/tempo"))
    (forge-checkout-pullreq forge-pr)
    (code-review-ediff-compare "main" "pr-test" "docker-compose.yml" "docker-compose.yml")))
