#!/usr/bin/env fennel
;; -*- mode: fennel -*-

(local magic (require :magic))
(local regex (require :regex))
(local unix (require :posix.unistd))
(local sys-stat (require :posix.sys.stat))
(local sys-wait (require :posix.sys.wait))
(local {: request} (require :ssl.https))

;; set up magic
(local mgc (magic.open magic.MIME_TYPE magic.NO_CHECK_COMPRESS))
(assert (= (mgc:load) 0) (mgc:error))

(fn fork-and-exec [[read-end write-end] program argv]
  (local pid (unix.fork))
  (when (= pid 0) ; child proc
    (unix.close write-end)
    (unix.dup2 read-end unix.STDIN_FILENO)
    (unix.execp program argv)) ; *never returns*
  pid)

(fn run [{:stdin input} program ...]
  (local [read-end write-end &as pipes] [(unix.pipe)])
  (local child-pid (fork-and-exec pipes program [...]))
  (when input
    (unix.write write-end input))
  (unix.close read-end)
  (unix.close write-end)
  (match (sys-wait.wait child-pid sys-wait.WNOHANG)
    (_ :running) :running
    (_ :exited exit-status) exit-status
    (_ killed-or-stopped) (error (.. "subprocess was " killed-or-stopped))))

(fn mk-handler [program] #(run {} program $...))

(local term         (mk-handler "alacritty"))
(local editor       (mk-handler "emacs"))
(local image-viewer (mk-handler "imv"))
(local pdf-viewer   (mk-handler "zathura"))
(local video-viewer (mk-handler "mpv"))
(local web          (mk-handler "qutebrowser"))
(local doc-editor   (mk-handler "libreoffice"))

(fn web-image-handler [url]
  (local image (assert (request url)))
  (run {:stdin image} "imv" "-"))

(local name-handlers
       [["^https?://(www\\.)?youtube\\.com/watch\\?v=" video-viewer]
        ["^https?://(www\\.)?youtu\\.be/"              video-viewer]
        ["\\.(mkv|mp4|ogv|ogg|wav|mov)$"               video-viewer]
        ["^https?://.*\\.pdf$"                         pdf-viewer]
        ["^https?://.*\\.(png|jpg|jpeg|bmp|gif)$"      web-image-handler]
        ["^https?://"                                  web]
        ["\\.(od.|docx?|xslx?|pptx?)$"                 doc-editor]])

(local mime-handlers
       [["djvu"              pdf-viewer]
        ["^image/"           image-viewer]
        ["^video/"           video-viewer]
        ["^application/pdf"  pdf-viewer]
        ["^application/epub" pdf-viewer]
        ["^text/xml"]        web])

(fn find-handler [handlers match-str input]
  (fn go [n]
    (match (. handlers n)
      [pattern handler] (if (regex.match match-str pattern "i")
                            (handler input)
                            (go (+ n 1)))))
  (go 1))

(fn plumb [input]
  (or (find-handler name-handlers input input)
      (and (sys-stat.stat input) ; check if valid file path
           (find-handler mime-handlers (mgc:file input) input))
      (editor input)))

(fn trim [str] (str:gsub "\n?$" ""))

(local proc-status (match arg
                     [thing] (plumb thing)
                     _ (-> (io.read :a) trim plumb)))

(os.exit (match proc-status
           (where (or :running 0)) 0
           _ proc-status))
