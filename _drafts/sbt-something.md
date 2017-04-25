* if something is set in `build.sbt` as a nested thing ala `baseDirectory in (Test,run) := file(".")` you can see it in sbt `show` via `> show Test:run::baseDirectory` or `> show subModule/Test:run::baseDirectory` etc.

* If running in forked JVM via `run` or `runMain` for submodules tests and want to set `baseDirectory` remember to set `baseDirectory in (Test,run) := baseDirectory` etc.
