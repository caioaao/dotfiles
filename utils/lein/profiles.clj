{:user
 {:dependencies [[cljdev "0.3.0-SNAPSHOT"]]
  :plugins [[s3-wagon-private "1.2.0"]
            [lein-exec "0.3.6"]
            [lein-ancient "0.6.10"]
            [jonase/eastwood "0.2.3"]
            [lein-instant-cheatsheet "2.2.1"]]}
 :repl {:plugins [[cider/cider-nrepl "0.14.0-SNAPSHOT"]
                  [refactor-nrepl "2.3.0-SNAPSHOT"]]
        :dependencies [[org.clojure/tools.nrepl "0.2.12"]]
        :repl-options {:timeout 120000}}}
