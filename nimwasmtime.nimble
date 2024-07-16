# Package

version       = "0.1.0"
author        = "Nimaoth"
description   = "Nim wrapper for wasmtime"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.8"

task wasmtime, "Build wasmtime":
  withDir "src/wasmtime":
    withDir "crates/c-api":
      exec "cmake -S . -B build"
      cpFile "build/include/wasmtime/conf.h", "include/wasmtime/conf.h"
    exec "cargo build --release -p wasmtime-c-api"


before install:
  wasmtimeTask()
