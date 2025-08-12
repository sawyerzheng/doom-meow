;;; editor/meow/config.el -*- lexical-binding: t; -*-

(use-package! meow

;;; Loading

  ;; Eager-load Meow, so that if there are errors later in our config, at least
  ;; we have Meow set up to fix them.
  :demand t

  ;; Enable after modules have loaded.
  :hook (doom-after-modules-config . meow-global-mode)

  :init

;;; `meow-motion-remap-prefix'

  ;; Rebind all keys shadowed by Meow's Motion state to 'C-<key>'.
  ;; Different from the Meow default 'H-<key>', because how many users actually
  ;; have that key on their keyboard?
  ;; 'C-j' and 'C-k' are unlikely to be rebound by any modes as they're basic
  ;; editing keys. 'C-]' can't be remapped under the 'C-' prefix, but it's
  ;; unlikely that any mode will shadow `abort-recursive-edit'.
  (setq meow-motion-remap-prefix "C-")

  :config

;;; Cursor configuration

  ;; In Emacs, unlike Evil, the cursor is /between/ two characters, not on top
  ;; of a character. Since this module will likely attract a lot of Evil users,
  ;; use the 'bar' cursor shape instead of the default 'block' to reflect this
  ;; fact.
  ;; In addition, blink the cursor in insert state.

  (defvar +meow-want-blink-cursor-in-insert t
    "Whether `blink-cursor-mode' should be enabled in INSERT state.")

  (setq meow-cursor-type-normal 'box
        meow-cursor-type-insert 'bar
        meow-cursor-type-beacon 'bar
        meow-cursor-type-default 'box
        blink-cursor-delay 0 ; start blinking immediately
        blink-cursor-blinks 0 ; blink forever
        blink-cursor-interval 0.15) ; blink time period

  ;; Toggle blink on entering/exiting insert mode
  (add-hook 'meow-insert-mode-hook #'+meow-maybe-toggle-cursor-blink)

  ;; When we switch windows, the window we switch to may be in a different state
  ;; than the previous one
  (advice-add #'meow--on-window-state-change
              :after #'+meow-maybe-toggle-cursor-blink)

;;; Continuing commented lines

  ;; Since `meow-open-below' just runs `newline-and-indent', it will perform
  ;; Doom's behavior of continuing commented lines (if
  ;; `+default-want-RET-continue-comments' is non-nil). Prevent this.
  (defvar +meow-want-meow-open-below-continue-comments nil
    "If non-nil `meow-open-below' will continue commented lines.")

  (defadvice! +meow--newline-indent-and-continue-comments-a (&rest _)
    "Support `+meow-want-meow-open-below-continue-comments'.
Doom uses `+default--newline-indent-and-continue-comments-a' to continue
comments. Prevent that from running if necessary."
    :before-while #'+default--newline-indent-and-continue-comments-a
    (interactive "*")
    (if (eq real-this-command #'meow-open-below)
        +meow-want-meow-open-below-continue-comments
      t))


;;; Expansion hints
  ;; These should not be disabled anywhere by default; if users find that they
  ;; cause problems due to variable-width fonts etc., they can configure this
  ;; variable themselves.
  (setq meow-expand-exclude-mode-list nil)


;;; Alternate states

  ;; Use a consistent key for exiting EMACS state and `meow-temp-normal'.
  ;; We use 'C-]' as our binding to toggle this state, both in Motion and Emacs
  ;; states. This binding was chosen based on the notion that it is rare to use
  ;; its default binding `abort-recursive-edit'. It is rare to encounter
  ;; recursive editing levels outside the minibuffer, and that specific case is
  ;; handled by `doom/escape'.
  ;; If it is really needed, `abort-recursive-edit' is also bound to `C-x X a'.

  (defvar +meow-alternate-state-key "C-]"
    "Key to switch to an alternate state in Meow.
- Invoke `meow-temp-normal' in Motion state
- In EMACS state, return to previous/Motion state.")

  (meow-motion-overwrite-define-key
   (cons +meow-alternate-state-key #'meow-temp-normal))

;;; Emacs state
  ;; Meow's Motion state, as configured by the suggested bindings, is mainly
  ;; useful in modes where moving the cursor between lines is meaningful, and
  ;; the mode doesn't bind SPC. For anything else, it tends to get in the way.
  ;; In such cases, it's best to configure our own bindings for the mode rather
  ;; than relying on Motion state.
  ;; In Meow, every mode starts in a particular state, defaulting to Motion. So,
  ;; if we want a mode to not have any Meow bindings, it needs to start in a
  ;; state without any bindings.
  ;; To this end, we define a custom EMACS state to switch to. This state will
  ;; have no bindings except one to switch back to the previous state (or to
  ;; Motion state if the buffer started in Emacs state), and a binding to invoke
  ;; Keypad state (we use M-SPC as it's unlikely to be bound by other modes, and
  ;; the default binding of `cycle-spacing' probably won't be relevant in the
  ;; special modes we're using this state for).

  (defvar +meow-emacs-state--previous nil
    "Meow state before switching to EMACS state.")

  (defface meow-emacs-cursor
    `((t (:inherit unspecified
          :background ,(face-foreground 'warning))))
    "BEACON cursor face."
    :group 'meow)

  (defvar meow-emacs-state-keymap
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd +meow-alternate-state-key) #'+meow-toggle-emacs-state)
      (define-key map (kbd "M-SPC") #'meow-keypad)
      map)
    "Keymap for EMACS state.
Should only contain `+meow-toggle-emacs-state'.")

  (meow-define-state emacs
    "Meow EMACS state minor mode.
This is a custom state having no bindings except `+meow-toggle-emacs-state' and
`meow-keypad'."
    :lighter " [E]"
    :keymap meow-emacs-state-keymap
    :face meow-emacs-cursor)

  (defun +meow-toggle-emacs-state ()
    "Toggle EMACS state.
If EMACS state was manually switched to via this command, switch back to the
previous state. Otherwise, assume that the buffer started in EMACS state, and
switch to MOTION state."
    (interactive)
    (if (meow-emacs-mode-p)
        (progn
          (meow--switch-state
           (or +meow-emacs-state--previous 'motion))
          (setq +meow-emacs-state--previous nil))
      (setq +meow-emacs-state--previous meow--current-state)
      (meow--switch-state 'emacs)))

;;; misc. settings

  ;; Wait for longer before removing the expansion hints. One second is too
  ;; short, especially for people using them for the first time.
  (setq meow-expand-hint-remove-delay 4.0)

  ;; Don't self-insert keypad-mode keys if they're undefined, in order to be
  ;; consistent with Emacs' standard behavior with undefined keys.
  (setq meow-keypad-self-insert-undefined nil)

;;; Bindings

;;;; Suggested bindings

  (cond ((modulep! +qwerty) (+meow--setup-qwerty))
        ((modulep! +qwertz) (+meow--setup-qwertz))
        ((modulep! +dvorak) (+meow--setup-dvorak))
        ((modulep! +dvp) (+meow--setup-dvp))
        ((modulep! +colemak) (+meow--setup-colemak))
        (t nil))

;;;; Doom leader/localleader

  ;; FIXME: When these are invoked via Keypad, the descriptions of prefixes are
  ;; not shown. This could be a Doom problem, a general.el problem, or a
  ;; `meow--which-key-describe-keymap' problem.
  (when (modulep! :config default +bindings)

    ;; Doom uses a complicated system involving `general-override-mode' to set
    ;; up its leader and localleader keys. I don't pretend to understand how it
    ;; works. But as far as I can tell, we can rely on it to work in the
    ;; following way -
    ;; `doom-leader-alt-key' (default 'C-c') is treated as the leader key when
    ;; Doom's emacs bindings are in use, and all leader keybindings should be
    ;; accessible under this key.
    ;; So we can simply tell Meow to prefix the Keypad key sequence with 'C-c',
    ;; and all leader key bindings should be accessible when Keypad is invoked.
    ;; With `meow-keypad' bound to 'SPC' as expected, this parallels the
    ;; behavior in :editor evil.
    (setq meow-keypad-leader-dispatch "C-c")

    ;; A minor tweak - 'SPC c' will translate to 'C-c' rather than invoking
    ;; `doom-leader-code-map'. So we must use another prefix key. 'k' was chosen
    ;; because it wasn't already in use, and because it makes
    ;; `+lookup/documentation', a very handy command, easy to invoke
    ;; ('SPC k k').
    ;; (We need a hook since this module is loaded before the bindings are, due to ':demand')
    (add-hook! 'doom-after-modules-config-hook
      (defun +meow-leader-move-code-map-h ()
        (when (boundp 'doom-leader-code-map)
          (define-key doom-leader-map "k" (cons "code" doom-leader-code-map))
          ;; Unbind the 'c' prefix; we'll use it in our localleader hack.
          (define-key doom-leader-map "c" nil)))
      (defun +meow-leader-move-toggle-map-h ()
        (when (boundp 'doom-leader-toggle-map)
          (define-key doom-leader-map "u" (cons "toggle" doom-leader-toggle-map))
          ;; Unbind the 'c' prefix; we'll use it in our localleader hack.
          (define-key doom-leader-map "t" nil))))

    ;; Also note that the Git commands are now under 'SPC v', unlike in
    ;; :editor evil.

    ;; Next, the localleader. For non-Evil users, this is invoked by 'C-c l'.
    ;; Since 'l' isn't used as a prefix in `doom-leader-map', we can use it as
    ;; the prefix for localleader. ('SPC m' would translate to 'M-' in Keypad
    ;; state, so we can't use it.)
    ;; I do not understand how Doom accomplishes the localleader bindings and do
    ;; not want to tangle with general.el, so we'll accomplish this with a HACK.
    ;;
    ;; Doom binds `doom-leader-map' under 'C-c' (the default value of
    ;; `doom-leader-alt-key'. Ideally we want to bind locallleader under this
    ;; prefix as well. Since we just freed up the 'c' prefix in
    ;; `doom-leader-map', we use that -
    (add-hook! 'doom-after-modules-config-hook
      (defun +meow-set-localleader-alt-key-h ()
        (setq doom-localleader-alt-key "C-c c")))
    ;;
    ;; Then, we define a command that calls 'C-c c', and bind it to 'l':
    (define-key doom-leader-map "l"
                (cons "+localleader" (cmd! (meow--execute-kbd-macro "C-c c"))))
    ;; ...and now the localleader bindings are accessible with 'SPC l' (or with
    ;; 'SPC c SPC c', for that matter).
    )

;;;; Layout-independent Rebindings

;;;;; Keypad

;;;;;; SPC u -> C-u
  ;; Like in Doom's evil config.
  ;; (define-key doom-leader-map "u" #'meow-universal-argument)

;;;;; 'M-SPC'

  ;; As in our EMACS state, make 'M-SPC' trigger the leader-key bindings in
  ;; Insert state.
  (meow-define-keys 'insert '("M-SPC" . meow-keypad))

;;;;; `+meow-escape'

  ;; By default, ESC does nothing in Meow normal state (bound to `ignore'). But
  ;; we need to run `doom-escape-hook' for things like :ui popup to function as
  ;; expected. In addition, it makes sense to extend `doom/escape's incremental
  ;; behavior to Meow.
  ;; Hence, `+meow-escape' - a command that cancels the selection if it's
  ;; active, otherwise falling back to `doom/escape'.
  ;; This also has the nice effect of requiring one less normal-state
  ;; keybinding - `meow-cancel-selection' is no longer needed as this command
  ;; invokes it when necessary, so the user can rebind 'g' if they want.
  (meow-normal-define-key '("<escape>" . +meow-escape))

;;;;; Esc in Motion state

  ;; Popups will be in Motion state, and Doom's popup management relies on
  ;; `doom-escape-hook'. So we can't have <escape> bound to `ignore'.
  (meow-motion-overwrite-define-key '("<escape>" . doom/escape))

;;;; Emacs tutorial
  ;; It teaches the default bindings, so make it start in our Emacs state.
  (defadvice! +meow-emacs-tutorial-a (&rest _)
    :after #'help-with-tutorial
    (+meow-toggle-emacs-state)
    (insert
     (propertize
      "Meow: this Tutorial buffer has been started in Emacs state. Meow
bindings are not active.\n\n"
      'face 'warning))))


(defun my/meow-setup ()
  (interactive)
  (when (modulep! :editor meow +qwerty)
    (setq meow-use-clipboard t)
    (setq delete-active-region t)

    (map! "ESC ESC" #'+meow-escape)
    (map! "ESC <escape>" #'+meow-escape)
    ;; (setq meta-prefix-char nil)

    (meow-motion-overwrite-define-key
     ;; (cons "q" my/search-keymap)
     ;; '("Q" . "H-q")
     '("j" . meow-next)
     '("k" . meow-prev)
     '("C-M-j" . "H-j")
     '("C-M-k" . "H-k")
     '("\\" . my/meow-quit)
     )
    (meow-normal-define-key
     '("=" . back-button-local-backward)
     '("+" . back-button-local-forward)
     '("d" . meow-backward-delete)
     ;; '("D" . meow-delete)
     '("D" . recenter-top-bottom)
     '("Q" . consult-goto-line)
     ;; insert new empty line below
     '("S" . open-line)
     '("U" . undo-redo)
     '("Z" . xah-comment-dwim)
     '("\\" . my/meow-quit)
     ;; region
     '(":" . er/expand-region)

     ;; pair jump
     '("/" . xah-goto-matching-bracket) ;; "/"
     '("T" . set-mark-command)
     ;; scroll
     '("<" . scroll-down-command)
     '(">" . scroll-up-command)
     ;; insert space
     '("P" . xah-insert-space-after)
     ;; shrink whitespaces
     '("X" . xah-shrink-whitespaces)
     ;; region expand
     '(":" . er/expand-region)

     )
    ;; (global-unset-key (kbd "C-c b"))
    ;; (global-unset-key (kbd "C-c f"))
    ;; (global-unset-key (kbd "C-c j"))
    ;; (global-unset-key (kbd "C-c k"))
    ;; (global-unset-key (kbd "C-c w"))
    ;; (define-key doom-leader-code-map (kbd "e") #'+eval/line-or-region)
    ;; (define-key doom-leader-code-map (kbd "E") #'+eval/buffer-or-region)
    ;; (define-key doom-leader-file-map (kbd "f") #'consult-buffer)
    ;; (define-key doom-leader-file-map (kbd "F") #'find-file)
    ;; (define-key doom-leader-file-map (kbd "b") #'persp-switch-to-buffer)
    ;; (define-key doom-leader-file-map (kbd "k") #'kill-current-buffer)
    ;;
    ;; ;; Unbind the existing bindings
    ;; (map! :leader
    ;;       (:prefix "c"
    ;;                "e" nil
    ;;                "E" nil)
    ;;       (:prefix "f"
    ;;                "f" nil
    ;;                "F" nil
    ;;                "b" nil
    ;;                "k" nil))

    ;; Then bind to your preferred functions
    (map! :leader
          (:prefix "c"
                   "e" #'+eval/line-or-region
                   "E" #'+eval/buffer-or-region)
          (:prefix "f"
                   "f" #'consult-buffer
                   "F" #'project-find-file
                   "b" #'persp-switch-to-buffer
                   "k" #'kill-current-buffer
                   )
          )
    (map! :map (doom-leader-toggle-map)
          "E" #'toggle-debug-on-error
          )


    (define-key general-override-mode-map (kbd "C-c i e") #'find-file)
    (map! :leader "i e" #'find-file)
    (map! :map doom-leader-search-map
	  "s" #'consult-imenu)
    ;; (define-key doom-leader-search-map (kbd "b") #'consult-imenu)
    ;; (define-key doom-leader-map (kbd "e") #'treemacs)
    (map! :leader "e" #'treemacs)

    (map! :leader "j" nil
          "j ." #'apropos-value
          "j /" #'describe-coding-system
          "j ;" #'describe-syntax

          "j a" #'apropos-command
          "j b" #'describe-command
          "j c" #'man
          "j d" #'view-echo-area-messages
          "j e" #'embark-act
          "j f" #'elisp-index-search
          "j g" #'info
          "j h" #'apropos-documentation
          "j i" #'describe-char
          "j j" #'describe-function
          ;; "j k" #'universal-argument
          "j k" #'meow-universal-argument
          "j l" #'describe-variable
          "j m" #'describe-mode
          "j n" #'describe-bindings
          "j o" #'apropos-variable
          "j p" #'view-lossage
          "j s" #'describe-language-environment
          "j u" #'info-lookup-symbol
          "j v" #'describe-key
          "j y" #'describe-face)

    ;; (define-key meow-beacon-state-keymap (kbd "<f4>") #'meow-end-or-call-kmacro)
    ;; (define-key meow-insert-state-keymap (kbd "<f4>") #'meow-end-or-call-kmacro)
    ;; (define-key meow-normal-state-keymap (kbd "<f4>") #'meow-end-or-call-kmacro)
    ;; (define-key meow-keypad-state-keymap (kbd "<f4>") #'meow-end-or-call-kmacro)

    (meow-leader-define-key
     '("SPC" . execute-extended-command)
     '("r" . vr/query-replace)
     '("e" . treemacs)
     ;; buffer / file
     ;; '("H" . beginning-of-buffer)
     ;; '("N" . end-of-buffer)
     '(";" . save-buffer)

     ;; jupyter -- buffer
     '("," . beginning-of-buffer)
     '("." . end-of-buffer)

     ;; app`l'ications
     ;; '("l ," . eww)
     ;; '("l -" . async-shell-command)
     ;; '("l ." . visual-line-mode)
     ;; '("l /" . abort-recursive-edit)
     ;; '("l 0" . shell-command-on-region)
     ;; '("l 1" . set-input-method)
     ;; '("l 2" . global-hl-line-mode)
     ;; '("l 4" . global-display-line-numbers-mode)
     ;; '("l 6" . calendar)
     ;; '("l 7" . calc)
     ;; '("l 9" . shell-command)
     ;; '("l ;" . count-matches)
     ;; '("l a" . org-agenda)
     ;; '("l b" . save-some-buffers)
     ;; '("l c" . flyspell-buffer)
     ;; ;; '("l d" . eshell) ;; l d use for dictionary
     ;; '("l e" . toggle-frame-maximized)
     ;; '("l f" . shell)
     ;; '("l g" . make-frame-command)
     ;; '("l h" . narrow-to-page)
     ;; '("l i" . toggle-case-fold-search)
     ;; '("l j" . widen)
     ;; '("l k" . narrow-to-defun)
     ;; '("l l" . xah-narrow-to-region)
     ;; '("l m" . jump-to-register)
     ;; '("l n" . toggle-debug-on-error)
     ;; '("l o" . count-words)
     ;; '("l r" . read-only-mode)
     ;; '("l s" . variable-pitch-mode)
     ;; '("l t" . toggle-truncate-lines)
     ;; '("l u" . xah-toggle-read-novel-mode)
     ;; '("l v" . menu-bar-open)
     ;; '("l W" . whitespace-mode)
     ;; ;; '("l " . nil)                      ;; uesed as prefix for elfeed
     ;; '("l x" . xwidget-webkit-browse-url)

     ;; '("i /" . revert-buffer-with-coding-system)
     ;; '("i ;" . write-file)
     ;; '("i v" . my/xah-open-in-vscode)
     ;; '("i a a" . codegeex-request-completion)
     ;; '("i a b" . baidu-translate-zh-mark)
     ;; '("i a c c" . my/chatgpt-interface-prompt-region-action)
     ;; '("i a c d" . codegpt-doc)
     ;; '("i a c e" . codegpt-explain)
     ;; '("i a c f" . codegpt-fix)
     ;; '("i a c i" . codegpt-improve)
     ;; '("i a e" . chatgpt-explain-region)
     ;; '("i a f" . chatgpt-fix-region)
     ;; '("i a l" . chatgpt-login)
     ;; '("i a p" . my/chatgpt-interface-prompt-region)
     ;; '("i a q" . chatgpt-query)
     ;; '("i a r" . chatgpt-refactor-region)
     ;; '("i a t" . chatgpt-gen-tests-for-region)
     ;; '("i b" . set-buffer-file-coding-system)
     ;; '("i c" . xah-copy-file-path)
     ;; '("i d" . ibuffer)
     '("i e" . find-file)
     ;; '("i f" . xah-open-file-at-cursor)
     ;; '("i i" . dired-jump)
     ;; '("i j" . recentf-open-files)
     ;; '("i k" . bookmark-bmenu-list)
     '("i l" . xah-new-empty-buffer)
     '("i m" . explorer)
     ;; '("i o" . bookmark-jump)
     ;; '("i p" . bookmark-set)
     '("i r" . revert-buffer)
     ;; '("i u" . eaf-open-browser-with-history)
     ;; '("i s" . eaf-search-it)
     ;; '("i w" . xah-open-in-external-app)
     ;; '("d T" . my/xah-insert-time)
     '("d a" . xah-insert-double-angle-bracket)
     '("d b" . my/xah-insert-singe-bracket)
     '("d c" . insert-char)
     '("d d" . xah-insert-unicode)
     '("d e" . emojify-insert-emoji)
     '("d f" . xah-insert-date)
     '("d g" . xah-insert-curly-single-quote)
     '("d h" . xah-insert-double-curly-quote)
     '("d i" . xah-insert-ascii-single-quote)
     '("d j" . xah-insert-brace)
     '("d k" . xah-insert-paren)
     '("d l" . xah-insert-square-bracket)
     '("d m" . xah-insert-corner-bracket)
     '("d n" . xah-insert-black-lenticular-bracket)
     '("d o" . xah-insert-tortoise-shell-bracket)
     '("d p" . xah-insert-formfeed)
     '("d r" . xah-insert-single-angle-quote)
     '("d t" . xah-insert-double-angle-quote)
     '("d u" . xah-insert-ascii-double-quote)
     '("d v" . xah-insert-markdown-quote)
     '("d y" . xah-insert-emacs-quote)
     '("d z" . (lambda () (interactive) (insert "​")))
     ;; '("e '" . markmacro-mark-lines)
     ;; '("e /" . markmacro-mark-chars)
     ;; '("e ;" . markmacro-mark-words)
     ;; '("e <" . markmacro-apply-all)
     ;; '("e >" . markmacro-apply-all-except-first)
     ;; '("e C" . markmacro-rect-mark-columns)
     ;; '("e D" . markmacro-rect-delete)
     ;; '("e H" . markmacro-secondary-region-mark-cursors)
     ;; '("e I" . markmacro-rect-insert)
     ;; '("e L" . markmacro-mark-imenus)
     ;; '("e M" . markmacro-rect-set)
     ;; '("e R" . markmacro-rect-replace)
     ;; '("e S" . markmacro-rect-mark-symbols)
     ;; '("e a" . ialign)
     ;; '("e d" . isearch-forward-symbol-at-point)
     ;; '("e e" . highlight-symbol-at-point)
     ;; '("e f" . isearch-forward-symbol)
     ;; '("e h" . markmacro-secondary-region-set)
     ;; '("e i" . highlight-lines-matching-regexp)
     ;; '("e j" . highlight-regexp)
     ;; '("e k" . highlight-phrase)
     ;; '("e m" . vr/mc-mark)
     ;; '("e n" . bm-next)
     ;; '("e o" . resize-window)
     ;; '("e p" . bm-previous)
     ;; '("e q" . my/format-buffer-fn)
     ;; '("e r" . isearch-forward-word)
     ;; '("e t" . bm-toggle)
     ;; '("e u" . unhighlight-regexp)
     ;; '("e w" . xah-fill-or-unfill)


     ;; '("k ," . xah-next-window-or-frame)
     ;; '("k 1" . xah-append-to-register-1)
     ;; '("k 2" . xah-clear-register-1)
     ;; '("k 3" . xah-copy-to-register-1)
     ;; '("k 4" . xah-paste-from-register-1)
     ;; '("k 7" . xah-append-to-register-1)
     ;; '("k 8" . xah-clear-register-1)
     ;; '("k <down>" . xah-move-block-down)
     ;; '("k <up>" . xah-move-block-up)
     ;; '("k b" . xah-reformat-to-sentence-lines)
     ;; '("k c" . copy-to-register)
     ;; '("k d" . list-matching-lines)
     ;; '("k e" . xah-sort-lines)
     ;; '("k f" . delete-matching-lines)
     ;; '("k g" . delete-non-matching-lines)
     ;; '("k h" . mark-defun)
     ;; '("k i" . goto-char)
     ;; '("k j" . repeat-complex-command)
     ;; '("k k" . repeat)
     ;; '("k m" . xah-make-backup-and-save)
     ;; '("k o" . copy-rectangle-as-kill)
     ;; '("k p" . xah-escape-quotes)
     ;; '("k q" . reverse-region)
     ;; '("k r" . query-replace-regexp)
     ;; '("k s" . xah-clean-whitespace)
     ;; '("k t" . delete-duplicate-lines)
     ;; '("k u" . move-to-column)
     ;; '("k v" . insert-register)
     ;; '("k w" . sort-numeric-fields)
     ;; '("k y" . goto-line)


     ;; '("o SPC" .	rectangle-mark-mode)
     ;; '("o 3" .		number-to-register)
     ;; '("o 4" .		increment-register)
     ;; '("o b" .		xah-double-backslash-to-slash)
     ;; '("o c" .		xah-slash-to-backslash)
     ;; '("o d" .		call-last-kbd-macro)
     ;; '("o e" .		kmacro-start-macro)
     ;; '("o f" .		xah-quote-lines)
     ;; '("o g" .		xah-space-to-newline)
     ;; '("o h" .		delete-rectangle)
     ;; '("o i" .		replace-rectangle)
     ;; '("o j" .		xah-change-bracket-pairs)
     ;; '("o l" .		rectangle-number-lines)
     ;; '("o o" .		yank-rectangle)
     ;; '("o p" .		clear-rectangle)
     ;; '("o r" .		kmacro-end-macro)
     ;; '("o s" .		open-rectangle)
     ;; '("o t" .		delete-whitespace-rectangle)
     ;; '("o u" .		kill-rectangle)
     ;; '("o v" .		xah-slash-to-double-backslash)
     ;; '("o w" .		apply-macro-to-region-lines)

     ;; major mode hydra
     ;; '("b" . major-mode-hydra)
     ;; M-x
     ;; '("a" . execute-extended-command)
     )
    ))

(add-to-list 'after-init-hook #'my/meow-setup)
