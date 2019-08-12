;;; yicf-mode.el -- Emacs major mode for Yahoo YICF package file format.
;;; Note: Probably GPLed due to taint issues, plus Y! copyright...
;;; see below.
;;
;; based on http://two-wugs.net/emacs/mode-tutorial.html
;; version 1.4 cbueno@yahoo-inc.com 18 Aug 2005
;; version 1.5 dono@yahoo-inc.com 6 Sep 2005
;;     * updates for xemacs compatibility
;; version 1.6 dono@yahoo-inc.com 7 Sep 2005
;;     * fixed the YINST menu in xemacs
;; version 1.7 dono@yahoo-inc.com 7 Sep 2005
;;     * added the Templates submenu item
;; version 1.8 dono@yahoo-inc.com 8 Sep 2005
;;     * added Docs submenu
;;     * added more templates
;;     * added ability to more fully customize the browser command
;;       when opening URLs
;;
;; version 1.9 cbueno@yahoo-inc.com 31 Mar 2006
;;     * removed xterm hacks. using the Emacs Shell Mode instead.
;;     * added functions/keys for dist_install
;;     * added function/key for a production install
;;     * minor bugfixes
;;
;; version 1.10 timshow@yahoo-inc.com 1 May 2006
;; * yinst-doc, a minor-modelet that tells you about the yinst line
;;   you're looking at.  This makes the useful "synopsis"-type
;;   information readily available in the minibuffer, like eldoc does
;;   for Lisp.  Only with more bugs and more hacks.
;;   **
;;   ** TAINT WARNING:
;;   **
;;   ** This file is inspired by eldoc mode, but it is actually a
;;      complete ripoff of that code.  I looked at that file
;;      extensively while writing this for examples on how to abuse
;;      [X]Emacs.  We re-use some of the eldoc code (not just because
;;      it's easy, but because it means we interact with it better,
;;      and they already debugged some of the Emacs weirdness for us).
;;      So let's assert that this is GPL...but who cares since it only
;;      works at Y!  anyway.
;;   * This file rips off eldoc-mode.  It seemed stupid to clone that
;;     file's functions.  eldoc isn't really intended as a platform
;;     for this extension, but it works!
;;   * Unlike eldoc-mode, we don't support Emacsen without idle
;;     timers.
;; * When running under XEmacs, use shell-command instead of screwing
;;   around with shell-mode.  This works in XEmacs, even with the
;;   apparently old packages on Y!BSD.
;; * Removed yinst-open-url, replace with browse-url
;;   (and instructions on how to configure browse-url)
;; * Only match font-lock keywords at the beginning of the line.
;; * Some code re-arraned (configurable stuff towards the top).
;; * replace crontab MAILTO=root@localhost lines
;;   with lines to be ${USER}@yahoo-inc.com
;; * indent all over the place
;; * Make the regular expressions built (easier to read)
;; * Change "YINST =" to "YINST" in the couple places where it appeared.
;;   The documentation no longer recommends "YINST =".
;; * Changed all keys to be C-c C-<whatever>.  C-c p is reserved for
;;   user use (and I personally use it --timshow).
;; * Many (mostly user-invisible) functions renamed.  Things in this
;;   file should probably start with yicf-, not yinst-.
;;
;; HOW TO INSTALL
;; ---------------------------------------------------
;;
;; You got the emacs_yicf_mode yinst package installed?  Sure you do.
;;
;; Just add this to ~/.emacs, or ~/.xemacs/init.el:
;;
;;  (autoload 'yicf-mode "yicf-mode" "YICF mode" t)
;;  (setq auto-mode-alist `(("\\.yicf" . yicf-mode) . ,auto-mode-alist))
;;  (add-hook 'yicf-mode-hook 'font-lock-mode)
;;
;; Or you can do this the other way, so you can mess with it by hand:
;; 
;; 1. Traditionally you put this file in the system site-lisp or your
;; personal site-lisp directory.
;;
;;    /usr/local/share/emacs/site-lisp/yicf-mode.el
;;           - or - 
;;    ~/.emacs.d/site-lisp/yicf-mode.el
;;
;; 2. Then add this to your ~/.emacs file:
;;
;;      (require 'yicf-mode)
;;
;; For help on this mode, type
;;   f1 f yicf-mode
;;
;; TO DO LIST:
;; - Things in this file tend to start with "yinst-".  Shouldn't they
;;   start with "yicf-"?

;;
;; Configuration
;;

;; options for dist_install
(defvar yinst-platform "FreeBSD.4.x"
  "The default yinst platform when running dist_intall.")
(defvar yinst-branch "current"
  "The default yinst branch when running dist_install.")
(defvar yinst-subcat "latam"
  "The default yinst subcategory when running dist_install.")
(defvar yinst-group "latam"
  "The default yinst group when running dist_install.")
(defvar yinst-os "freebsd"
  "The default operating system when running dist_install.")
(defvar yinst-osver "4.1"
  "The default OS version when running dist_install.")
(defvar yicf-inhibit-doc-mode nil
  "If non-nil, don't start yicf-doc-mode when yicf-mode starts up.")

(defvar yicf-mode-map nil
  "Key configuration for yicf-mode.")

(defvar yicf-doc-idle-delay 0.50	;should be defcustom
  "How long do we delay before showing help when `yicf-doc-mode' is enabled?")

(defvar yicf-use-shell-for-commands
  ;; XEmacs' emacs-version contains the string "XEmacs".  and "Lucid",
  ;; in case you're living in 1994.
  (not (string-match "XEmacs" emacs-version))

  "This variable is automatically set depending on your `emacs-version',
but you can change it if you're very, very bored, or if you think you
can fix this gross hack.

If non-nil, use `shell' and some hackery for getting commands to the
shell.  This works well in GNU Emacs, but does not work at all in
XEmacs.  If nil, use `shell-command' after appending a & to get
asynchronous operation.  This works better in XEmacs, but tends to
echo passwords in the buffer in GNU Emacs.")


;; I just required easymenu rather than making it a feature check.
;; This was probably a mistake, but it cleaned up the code nicely, and
;; it seems to be common for both XEmacs and GNU Emacs.
(require 'easymenu)
;; eldoc required for yicf-doc-mode stuff.  Everyone has it, and it seems
;; to work fine.
(require 'eldoc)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; syntax setup

(if yicf-mode-map nil
  (setq yicf-mode-map (make-keymap))
  (define-key yicf-mode-map "\C-c\C-r" 'yinst-create-release)
  (define-key yicf-mode-map "\C-c\C-t" 'yinst-create-test)
  (define-key yicf-mode-map "\C-c\C-l" 'yinst-create-link)
  (define-key yicf-mode-map "\C-c\C-d" 'yinst-create-release-dist-install)
  (define-key yicf-mode-map "\C-c\C-i" 'yinst-create-test-and-install) 
  (define-key yicf-mode-map "\C-c\C-p" 'yinst-install-production))

;; register the .yicf extension with this mode
(add-to-list 'auto-mode-alist '("\\.yicf\\'" . yicf-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; face declarations
(defface yicf-space-warning-face
  ;; taken from make-mode.el
  '((((class color)) (:background  "hotpink"))
    (t (:reverse-video t)))
  "Face to use for highlighting leading spaces in Font-Lock mode."
  :group 'faces
  :group 'yicf)

(defface yicf-warning-face
  '((((class color)) (:foreground "red" :background "white"))
    (t (:reverse-video t)))
  "Face to use for highlighting leading spaces in Font-Lock mode."
  :group 'faces
  :group 'yicf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; font-lock keywords

;; This is a macro so that it evaluates at compile time.  I couldn't
;; get a recursive version to work.
(defmacro yicf-words-regexp (&rest words-to-match)
  "Return a regexp matching any word in `words-to-match' at the beginning
of the line."
  (let ((words words-to-match)
	(result "\\)\\>"))
    (while (cdr words)
      (setq result (concat "\\|" (car words) result))
      (setq words (cdr words)))
    (setq result (concat "^\\<\\(" (car words) result))))

;;regexps for keywords, variables, bultins, strings, etc.
;; Some of these seem overloaded and should be defined seperately?
(defconst yicf-font-lock-keywords
  (list
   ;; This doesn't work for me under GNU Emacs.
   '("^YINST[ \t]*=" . yicf-warning-face)
   
   ;; quotes & quotes
   ;; One quirk about yinst quoting is that the mechanism
   ;; isn't as general as the shell, for instance,
   ;; 1.0.`perl -e print time`
   ;; doesn't work.  This is, perhaps, a feature,
   ;; but something that could be highlighted with font locking?
   '("=[ \t]*`\\([^`]\\|\\\\\\`\\)*`" . font-lock-type-face)
   '("'\\([^']\\|\\\\\\'\\)*'" . font-lock-string-face)
   '("\"\\([^\"]\\|\\\\\\\"\\)*\"" . font-lock-string-face)

   ;; lines beginning with whitespace are probably bad
   '("^[ \t]+[^ \t#]" . yicf-space-warning-face)

   '("[ \t]*=[ \t]*" . font-lock-function-name-face)

   ;; required vars & commands
   `(,(yicf-words-regexp "CUSTODIAN" 
			 "GROUP"
			 "LONG_DESC"
			 "OWNER"
			 "PACKAGE_OS_SPECIFIC"
			 "PACKAGE_OS_VERSIONED"
			 "PERM"
			 "PRODUCT_NAME"
			 "REQUIRES"
			 "SHORT_DESC"
			 "VERSION"
			 "YINST"
			 "PLATFORMS"
			 ) . font-lock-builtin-face)
   
   ;;often-used env variables
   `(,(yicf-words-regexp "MAILTO"
			 "PROVIDER"
			 "LOCKFILE"
			 "RANDOMIZE") . font-lock-type-face)
   
   '("\\<[0-9.]+\\>" . font-lock-variable-name-face)
   
   ;; secondary keywords
   `(,(yicf-words-regexp "requires"
			 "pkg"
			 "nomerge"
			 "overwrite"
			 "norootchanged") . font-lock-function-name-face)
   
   ;; users & groups
   `(,(yicf-words-regexp "yahoo" "root" "wheel") . font-lock-constant-face)
   
   ;; actions
   `(,(yicf-words-regexp "file"
			 "configfile"
			 "patchfile"
			 "glob"
			 "dir"
			 "symlink"
			 "binfile"
			 "binlink"
			 "crontab"
			 "fifo"
			 "noop"
			 "find") . font-lock-function-name-face)
    
    ;; variables. I have to say that I do NOT understand elisp's quoting
    ;; rules for regexp strings.
    '("$(?\\w+)?" . font-lock-variable-name-face)
    
  )
  "syntax highlights for Yahoo yicf package files")


(defvar yicf-mode-syntax-table
  (let ((yicf-mode-syntax-table (make-syntax-table)))
    
    ;; underscores "_" are valid word-characters
    (modify-syntax-entry ?_ "w" yicf-mode-syntax-table)
    
    ;; pound/hashes "#" are comments, but stop at newlines
    (modify-syntax-entry ?\# "<"  yicf-mode-syntax-table)
    (modify-syntax-entry ?\n ">"  yicf-mode-syntax-table)
    
    yicf-mode-syntax-table)
  "Syntax table for yicf-mode.
Modify the  generic syntax rules a little to provide for comments.")

(easy-menu-define
 ;; this symbol becomes (interactive); make it hard to type.
 menu-for-yicf-mode
 yicf-mode-map
 "This is the yicf-mode menu to do many convenient yinst actions."
 '("Yinst"
   ["Create (release)    " yinst-create-release t]
   ["Create (test)   " yinst-create-test t]
   ["Create (link)   " yinst-create-link t]
   ["Install" yinst-install t]
   ["Create Test & Install" yinst-create-test-and-install t]
   ["Create Release & Install" yinst-create-release-and-install t]
   
   ("Dist" 
    ["Package information" yinst-go-package-info t]
    ["Active installs" yinst-go-package-active-installs t]
    ["dist_install This Package..." yinst-dist-install t])
   
   ("Templates"
    ["New YICF template" yinst-create-template-new-file t]
    "----"
    ["New \"file\" line" yinst-add-template-line-file t]
    ["New \"configfile\" line" yinst-add-template-line-configfile t]
    ["New \"symlink\" line" yinst-add-template-line-symlink t]
    ["New \"dir\" line" yinst-add-template-line-dir t]
    ["New \"requires\" line" yinst-add-template-line-requires t]
    ["New \"crontab\" line" yinst-add-template-line-crontab t]
    ["New \"YINST set\" line" yinst-add-template-line-set t]
    )
   
   ("Documentation"
    ["yinst Manual" yicf-docs-yinst-manual t]
    ["yinst_create Manual Section" yicf-docs-yinst_create t]
    ["yicf-mode Help" yicf-mode-help t]
    )))

;; The main show where we pull it all together. We set the syntax
;; table, keymap and font-lock, and then run any hook (plugin)
;; functions.
;;
;; See bottom of http://two-wugs.net/emacs/mode-tutorial.html to see
;; why this is a derived mode.
(define-derived-mode yicf-mode fundamental-mode "yicf"
  "Major mode for Yahoo! yicf package files.

WARNING: The YINST menu still lacks some error checking.  Use with
caution.  It assumes that we're running on a Unix-like OS with yinst,
dist_install, ls, head, and a working Emacs `browse-url' setup.  It
also assumes you use the 'US' dist, cvs and pkgdb servers.

If you want to customize the way the webbrowser is opened, see the
help on `browse-url' (type: \\[describe-function] browse-url RET).  This can be customized
using the Customize interface, or the menu bar if you're using XEmacs,
or by this handy scrap of Lisp:

  (setq browse-url-browser-function 'browse-url-netscape
	browse-url-mozilla-program \"firefox\")

To use the Customize interface to sort through this, look under
Hypermedia."

  (use-local-map yicf-mode-map)
  (set-syntax-table yicf-mode-syntax-table)
  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-end)   "")
  (set (make-local-variable 'font-lock-defaults) '(yicf-font-lock-keywords))

  (easy-menu-add menu-for-yicf-mode)

  (if (not yicf-inhibit-doc-mode)
      (yicf-doc-mode)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; YINST things. ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; returns the 'yinst create' command string for the current file
(defun yinst-create-string (buildtype)
  (concat "yinst create --platform " yinst-platform " --buildtype "
	  buildtype " -clean " (buffer-file-name)))

(defvar yinst-host-history '("localhost")) 

(defun yicf-run-command (command-string)
  "Run a command in a subshell. (a thin wrapper around `shell-command').
See also `yicf-use-shell-for-commands'.
According to the shell-command documentation, a command that ends in & will
be executed asynchronously; otherwise, it's synchronous.  We always use &."
  (if yicf-use-shell-for-commands
      (progn (switch-to-buffer "*YINST*")
	     (shell "*YINST*")
	     (insert command-string)
	     (comint-send-input))
    (shell-command (concat command-string "&"))))

;; instructs shell-mode (and all command interactive modes) to not
;; echo passwords.
;; (Hm.  This screams out for making our shell-mode a derived mode of
;; shell-mode so that these hooks don't interfere with other modes.)
(add-hook 'comint-output-filter-functions
          'comint-watch-for-password-prompt)

(defun yinst-create (buildtype) (yicf-run-command (yinst-create-string buildtype)))
(defun yinst-create-test ()    (interactive) (yinst-create "test"))
(defun yinst-create-release () (interactive) (yinst-create "release"))
(defun yinst-create-link ()    (interactive) (yinst-create "link"))

(defun yicf-get-variable-value (field)
  "Get the value for a variablle FIELD in the current buffer, which is
assumed to be a yicf file.  If nothing is found that looks like FIELD,
return nil."
  (save-excursion
    (goto-char (point-min))
    (if (and (re-search-forward (concat "^[ \t]*" field "[ \t]*=[ \t]*") nil t)
	     (looking-at "\\(.*\\)[ \t]*$"))
	(buffer-substring-no-properties (match-beginning 1)
					(match-end 1))
      nil)))

;; hack: xxx: todo: a BIG kludge here is how we discover, given only the path of the 
;; .yicf file, the name of the most-recently-created package for that file. We run
;; 'ls' sorted by date and pop the first entry, like this:
;;
;;    ls -t /yahoo/foo/bar/my_package-*.tgz | head -1
;;
;; We assume you are the only one making changes to this directory/package.
;; The danger comes when you have multiple packages in the same dir, perhaps with similar
;; names and ESPECIALLY if they contain dashes. You might end up installing the wrong one.
;; e.g.:
;;   my-project.yicf
;    my-project-misc.yicf
;;
(defun yinst-install-string ()
  (let ((yinst-host (read-from-minibuffer "Y Install on which host?: "
					  nil nil nil 'yinst-host-history)))
    (concat "yinst install -quiet -h " yinst-host " `ls -t "
	    (yicf-get-variable-value "PRODUCT_NAME") "-*.tgz | head -1`")))

;; I think there's a bug here.  We're logging things of the form -h
;; <host> or -M <group> to `yinst-host-history', and that's not really
;; cool, since those could show up on the history later.  This
;; interface doesn't seem right.
(defun yinst-install-production ()
  (interactive)
  (let ((yinst-host (read-from-minibuffer "Y Install to -h <host> or -M <group>: "
					 nil nil nil 'yinst-host-history)))
    (yicf-run-command (concat "yinst install -branch current -quiet "
			      yinst-host " " (yicf-get-variable-value "PRODUCT_NAME")))))

(defun yinst-install ()
  (interactive)
  (yicf-run-command (yinst-install-string)))

(defun yinst-create-test-and-install ()
  (interactive) 
  (yicf-run-command (concat (yinst-create-string "test") " && " (yinst-install-string))))

(defun yinst-create-release-and-install ()
  (interactive) 
  (yicf-run-command (concat (yinst-create-string "release") " && " (yinst-install-string))))


(defun yinst-dist-string ()
  (concat "/home/y/bin/dist_install -nomail -branch '" yinst-branch
	  "' -subcategory '" yinst-subcat "' -group '" yinst-group
	  "' -os '" yinst-os "' -osver '" yinst-osver
	  "' -batch `ls -t " (yicf-get-variable-value "PRODUCT_NAME") "-*.tgz | head -1`"))

(defun yinst-dist-install ()
  (interactive)
  (yicf-run-command (yinst-dist-string)))

(defun yinst-create-release-dist-install ()
  (interactive)
  (yicf-run-command (concat (yinst-create-string "release") " && " (yinst-dist-string))))

(defun yinst-go-package-info ()
  (interactive)
  (browse-url (concat "http://dist.corp.yahoo.com/by-package/" (yicf-get-variable-value "PRODUCT_NAME"))))

(defun yinst-go-package-active-installs ()
  (interactive)
  (browse-url (concat "http://pkgdb.corp.yahoo.com/yinst/acti.php?pn=" (yicf-get-variable-value "PRODUCT_NAME"))))

(defun yinst-create-template-new-file ()
  (interactive)
  (insert "\
PRODUCT_NAME = " (file-name-sans-extension (file-name-nondirectory (buffer-file-name))) "
VERSION = `egrep '^[0-9]+\.[0-9]+\.[0-9]+$' README | head -1`
SHORT_DESC = 
LONG_DESC = `cat README`
CUSTODIAN = 

PERM = 0444
OWNER = root
GROUP = wheel

# YINST requires pkg <pkg_name> <min_version> <max_version>

# file <perm> <owner> <group> <destination> <source>
# configfile <perm> <owner> <group> <destination> <source>
# symlink - - - <destination> <source>
# dir <perm> <owner> <group> <destination>

# crontab MAILTO=" (getenv "USER") "@yahoo-inc.com
# crontab min hour mday month wday who command

# YINST set <variable> <value>
"))

(defun yinst-add-template-line-file ()
  (interactive)
  (beginning-of-line)
  (insert "file 0444 - - <destination> <source>\n")
  )

(defun yinst-add-template-line-configfile ()
  (interactive)
  (beginning-of-line)
  (insert "configfile 0444 - - <destination> <source>\n")
  )

(defun yinst-add-template-line-symlink ()
  (interactive)
  (beginning-of-line)
  (insert "symlink - - - <destination> <source>\n")
  )

(defun yinst-add-template-line-dir ()
  (interactive)
  (beginning-of-line)
  (insert "dir 0755 - - <destination>\n")
  )

(defun yinst-add-template-line-requires ()
  (interactive)
  (beginning-of-line)
  (insert "YINST requires pkg <pkg_name> <min_version> <max_version>\n")
  )

(defun yinst-add-template-line-crontab ()
  (interactive)
  (beginning-of-line)
  ;; Better than root@localhost: spam yourself if you forget to edit the line!
  (insert "crontab MAILTO=\"" (getenv "USER") "@yahoo-inc.com\"\n")
  (insert "crontab min hour mday month wday who command\n"))

(defun yinst-add-template-line-set ()
  (interactive)
  (beginning-of-line)
  (insert "YINST set <variable> <value>\n")
  )

(defun yicf-docs-yinst-manual ()
  "Bring up the yinst manual."
  (interactive)
  (browse-url "http://devel.yahoo.com/yinst/"))

(defun yicf-docs-yinst_create ()
  "Bring up the yinst_create manual."
  (interactive)
  ;; I suspect that "?178.htm" is not really a permanent URL for this
  ;; but, hey, we'll go with it.
  (browse-url "http://devel.yahoo.com/yinst/guide/?178.htm")
  )

(defun yicf-mode-help ()
  "Bring up help on yicf-mode."
  (interactive)
  (describe-function #'yicf-mode))

(defconst yicf-doc-alist
  ;; This is kinda sloppy--we need some editorial control here to make
  ;; all the right-hand sides the same (and ideally consistent with
  ;; the yinst documentation).
  '( ;; list alphabetized with sort-lines
    ("CUSTODIAN"             . "<email-address> <web-page-for-docs>")
    ("GROUP"                 . "<group for package on dist>")
    ("LONG_DESC"             . "long description; usually just `cat README`")
    ("OWNER"                 . "<file owner for package on dist>")
    ("PERM"                  . "<default permissions for files>; usually 0600")
    ("PLATFORMS"             . "supported platforms for multi-mode (fat) package")
    ("PRODUCT_NAME"          . "package name")
    ("SHORT_DESC"            . "one-line description of package")
    ("SRCDIRS"               . "list of directories scanned for cvszip when generating release package")
    ("VERSION"               . "...x.y.z; x is major (incompat), y is minor, z is bugfix")
    ("YINST ="               . "This is deprecated.  In general, just remove the =.")
    ("YINST conflicts"       . "pkg {pkgname} [{min-version} [{max-version}]]")
    ("YINST logfile"         . "<log-file-name>")
    ("YINST patches"         . "patches pkg pkgname [min-version [max-version]]")
    ("YINST post-activate"   . "<command to run after activation>")
    ("YINST post-deactivate" . "<command to run after deactivation>")
    ("YINST post-deinstall"  . "<command to run after deinstall>")
    ("YINST post-install"    . "<command to run after install>")
    ("YINST pre-activate"    . "<command to run before activate>")
    ("YINST pre-deactivate"  . "<command to run before deactivate>")
    ("YINST pre-deinstall"   . "<command to run before deinstall>")
    ("YINST pre-install"     . "<command to run before install>")
    ("YINST prefix"          . "prefix (like /usr/local) for third-party software")
    ("YINST reload"          . "<sequence-number> <command>")
    ("YINST replaces"        . "pkgname [min-version [max-version]]")
    ("YINST requires"        . "YINST requires pkg <pkg_name> <min_version> <max_version>")
    ("YINST restart"         . "<command to be run at restart time>")
    ("YINST set"             . "YINST set <variable> <value>")
    ("YINST start"           . "<command to be run at start time>")
    ("YINST stop"            . "<command to be run at stop time>")
    ("b"                     . "binfile 0444 - - <destination> <source>")
    ("binfile"               . "binfile 0444 - - <destination> <source>")
    ("binlink"               . "binlink - - - <destination> <source>")
    ("c"                     . "configfile 0444 - - <destination> <source>")
    ("configfile"            . "configfile 0444 - - <destination> <source>")
    ("crontab"               . "crontab min hour mday month wday who command")
    ("dir"                   . "dir 0755 - - <destination> -- (needed for empty dirs only)")
    ("f"                     . "file 0444 - - <destination> <source>")
    ("fifo"                  . "fifo perm owner group destination")
    ("file"                  . "f 0444 - - <destination> <source>")
    ("find"                  . "find perm owner group dest source [args to find...]")
    ("glob"                  . "glob perm owner group dest/ source (dest must be dir and end in /)")
    ("noop"                  . "specificly do nothing")
    ("patchfile"             . "patch(1) file when pkg is activated and remove when deactivated")
    ("s"                     . "symlink - - - <destination> <source>")
    ("symlink"               . "symlink - - - <destination> <source>")
    )

  "These are the available lines in a yicf file.  Descriptions are
short and will pop up in the minibuffer in context.

The key in the assoc-list here is something that `yicf-doc-get-doc' is
capable of returning if it's `equal'.")

(defcustom yicf-doc-mode-enabled nil
  "*If non-nil, show some help in the minibuffer for the yicf action
on the current line, if available.  No help is shown for comments.  Help is
found by looking at the assoc-list `yicf-doc-alist'.  The actual lookup is
in `yicf-doc-get-doc', which uses a regexp heuristic and can get fooled.

This variable is buffer local."
  :type 'boolean
  :group 'yicf-doc)
(make-variable-buffer-local 'yicf-doc-mode-enabled)

;;
;; initialization for yicf-doc-mode
;;
(defvar yicf-doc-current-idle-delay yicf-doc-idle-delay)

(add-minor-mode 'yicf-doc-mode-enabled " YicfDoc")

(defun yicf-get-action-on-current-line ()
  "Get the yicf action at the beginning of this line.  This does a decent
job at canonicalizing to one of a few different forms, which we then can look
up in `yicf-doc-alist' with `yicf-doc-get-doc'."
  (let ((p (point)))
    (beginning-of-line)
    (prog1 (or
	    ;; special case: return YINST= for all such occurrances
	    ;; (remove if we ever obsolete this)
	    (and (looking-at "YINST[ \t]*=")
		 "YINST =")
	    ;; return "YINST keyword" for any line no matter how much space
	    ;; between YINST and keyword
	    (and (looking-at "YINST[ \t]+\\([=a-zA-Z_-]+\\)")
		 (concat "YINST "
			 (buffer-substring-no-properties
			  (match-beginning 1) (match-end 1))))
	    ;; return just the first word on the line
	    (and (looking-at "\\([a-zA-Z_-]+\\)[ \t]*")
		 (buffer-substring-no-properties (match-beginning 1)
						 (match-end 1))))
      ;; put point back
      (goto-char p))))

;; This calls eldoc-message whch is kinda bogus.
(defun yicf-doc-get-doc ()
  "Get the documentation for the current line in a yicf file.
This looks at `yicf-doc-alist."
  (let* ((kw (yicf-get-action-on-current-line))
	 (docs (and kw (cdr (assoc kw yicf-doc-alist)))))
    (and docs
	 (concat kw ": " docs))))

(defvar yicf-doc-timer nil)

(defun yicf-doc-display-message-no-interference-p ()
  (and yicf-doc-mode-enabled
       (not executing-kbd-macro)
       ;; Having this mode operate in an active minibuffer/echo area causes
       ;; interference with what's going on there.
       (not cursor-in-echo-area)
       (not (eq (selected-window) (minibuffer-window)))))

(defun yicf-doc-display-message-p ()
  "Is this a good time to display a mesasge?

Shamefully stolen from `eldoc-display-message-p'."
  (and (yicf-doc-display-message-no-interference-p)
       ;; If this-command is non-nil while running via an idle
       ;; timer, we're still in the middle of executing a command,
       ;; e.g. a query-replace where it would be annoying to
       ;; overwrite the echo area.
       (and (not this-command)
	    (symbolp last-command)
	    (intern-soft (symbol-name last-command)
			 eldoc-message-commands))))

(defun yicf-doc-maybe-display ()
  "Possibly display yicf documenation for the current line, if
`eldoc-display-message-p' thinks that this is a good time, and if
`yicf-doc-get-doc' can find something to say."
  (and (yicf-doc-display-message-p)
       (let ((doc (yicf-doc-get-doc)))
	 (and doc
	      (eldoc-message doc)))))

(defun yicf-doc-schedule-timer ()
  "Schedule the timer for yicf-doc display."
  (or (and yicf-doc-timer
           (memq yicf-doc-timer timer-idle-list))
      (setq yicf-doc-timer
            (run-with-idle-timer yicf-doc-idle-delay t
                                 'yicf-doc-maybe-display)))

  ;; If user has changed the idle delay, update the timer.
  (cond ((not (= yicf-doc-idle-delay yicf-doc-current-idle-delay))
         (setq yicf-doc-current-idle-delay yicf-doc-idle-delay)
         (timer-set-idle-time yicf-doc-timer yicf-doc-idle-delay t))))

;; cribbed from eldoc.el
(defun yicf-doc-mode (&optional prefix)
  "*Enable or disable yicf-doc mode.
This may be enabled by default if you're in `yicf-mode'.  (Set
`yicf-inhibit-doc-mode' to non-nil to turn this off when using
`yicf-mode'.)

See documentation for the variable `yicf-doc-mode-enabled'.

If called interactively with no prefix argument, toggle current condition
of the mode.
If called with a positive or negative prefix argument, enable or disable
the mode, respectively."
  (interactive "P")
  ;; These are intentionally calls to eldoc's code, which is hopefully
  ;; reasonably Emacs-independent.  Let's re-use someone else's hard work!
  (setq eldoc-last-message nil)
  (add-hook 'pre-command-hook 'eldoc-pre-command-refresh-echo-area)
  (add-hook 'post-command-hook 'yicf-doc-schedule-timer)
  (setq yicf-doc-mode-enabled (if prefix
				  (>= (prefix-numeric-value prefix) 0)
				(not yicf-doc-mode-enabled)))
  yicf-doc-mode-enabled)

(provide 'yicf-mode)
