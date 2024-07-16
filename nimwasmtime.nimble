# Package

version       = "0.1.2"
author        = "Nimaoth"
description   = "Nim wrapper for wasmtime"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.8"
requires "https://github.com/Nimaoth/nimgen >= 0.5.4"

var
  cmd = when defined(Windows): "cmd /c " else: ""

task nimgen, "Nimgen":
  if gorgeEx(cmd & "nimgen").exitCode != 0:
    withDir(".."):
      exec "nimble install nimgen -y"

  exec cmd & "nimgen nimwasmtime.cfg"

task wasmtime, "Build wasmtime":
  withDir "src/wasmtime":
    withDir "crates/c-api":
      try:
        exec "cmake -S . -B build"
        cpFile "build/include/wasmtime/conf.h", "include/wasmtime/conf.h"
      except:
        echo "CMake failed: ", getCurrentExceptionMsg()

    exec "cargo build --release -p wasmtime-c-api"

before install:
  nimgenTask()
  wasmtimeTask()
