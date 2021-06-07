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
  (unix.write write-end (or input ""))
  (unix.close read-end)
  (unix.close write-end)
  (match (sys-wait.wait child-pid sys-wait.WNOHANG)
    (_ :running) :running
    (_ :exited exit-status) exit-status
    (_ killed-or-stopped) (error (.. "subprocess was " killed-or-stopped))))

;; Handlers
(local image-viewer #(run {} "imv" $))
(local pdf-viewer   #(run {} "zathura" $))
(local video-viewer #(run {} "mpv" $))
(local web          #(run {} "qutebrowser" $))
(local doc-editor   #(run {} "libreoffice" $))
(local editor       #(run {} "emacsclient" "-n" $))
(local web-image    #(run {:stdin (assert (request $))} "imv" "-"))
(local web-pdf      #(run {:stdin (assert (request $))} "zathura" "-"))

(local name-handlers
       [["^https?://(www\\.)?youtube\\.com/watch\\?v=" video-viewer]
        ["^https?://(www\\.)?youtu\\.be/"              video-viewer]
        ["^https?://(www\\.)?twitch\\.tv/"             video-viewer]
        ["\\.(mkv|mp4|ogv|ogg|wav|mov)$"               video-viewer]
        ["^https?://.*\\.pdf$"                         web-pdf]
        ["^https?://.*\\.(png|jpg|jpeg|bmp|gif)$"      web-image]
        ["^https?://"                                  web]
        ["\\.(od.|docx?|xslx?|pptx?)$"                 doc-editor]])

(local mime-handlers
       [["djvu"              pdf-viewer]
        ["^image/"           image-viewer]
        ["^video/"           video-viewer]
        ["^application/pdf"  pdf-viewer]
        ["^application/epub" pdf-viewer]
        ["^text/xml"         web]
        ["^text/plain"       editor]])

(fn find-handler [handlers match-str input]
  (fn go [n]
    (match (. handlers n)
      [pattern handler]
      (if (regex.match match-str pattern "i")
          (do (run {} "notify-send" "-t" "1000" "plumb" (.. "opening " input))
              (handler input))
          (go (+ n 1)))))
  (go 1))

(fn plumb [input]
  (local status (or (find-handler name-handlers input input)
                    (and (sys-stat.stat input)       ; check if valid file path
                         (find-handler mime-handlers (mgc:file input) input))))
  (when (not status)
    (run {} "notify-send" "plumb" (.. "no handler found for " input)))
  (or status 1))

(fn trim [str] (str:gsub "\n?$" ""))

(fn dispatch-args [args]
  (match args
    ["-p"] (-> (io.popen "wl-paste -p")
               (: :read :a)
               trim
               plumb)
    [nil] (-> (io.read :a)
              trim
              plumb)
    [thing] (plumb thing)))

(local proc-status (dispatch-args arg))
(os.exit (match proc-status
           (where (or :running 0)) 0
           _ proc-status))
