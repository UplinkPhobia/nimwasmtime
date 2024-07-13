import std/[os, macros, genasts, strformat, strutils]

import wasmh
export wasmh

const errorH = "wasmtime/error.h"
const configH = "wasmtime/config.h"
const engineH = "wasmtime/engine.h"
const storeH = "wasmtime/store.h"
const moduleH = "wasmtime/module.h"
const instanceH = "wasmtime/instance.h"
const externH = "wasmtime/extern.h"
const linkerH = "wasmtime/linker.h"

{.passC: "-DLIBWASM_STATIC".}
{.passC: "-I" & wasmDir / "include".}
{.passL: "-L" & wasmDir / "lib".}
{.passL: "-l:libwasmtime.a -lm".}

proc data*[T](arr: openArray[T]): ptr T =
  if arr.len == 0:
    nil
  else:
    arr[0].addr

# Error
type
  WasmtimeError* {.importc: "wasmtime_error_t", header: errorH.} = object

  WasmtimeResultKind* = enum Ok, Err
  WasmtimeResult*[T] = object
    case kind*: WasmtimeResultKind
    of Ok:
      when T isnot void:
        val*: T
    of Err:
      err*: ptr WasmtimeError

# proc wasmtime_error_new*(msg: cstring): ptr Error {.importc: "wasmtime_error_new".}
proc new*(_: typedesc[WasmtimeError], msg: cstring): ptr WasmtimeError {.importc: "wasmtime_error_new", header: errorH.}
proc wasmtime_error_message*(err: ptr WasmtimeError, res: ptr wasm_name_t) {.importc, header: errorH.}
proc wasmtime_error_exit_status*(err: ptr WasmtimeError, res: ptr cint) {.importc, header: errorH.}
proc wasmtime_error_wasm_trace*(err: ptr WasmtimeError, res: ptr wasm_frame_vec_t) {.importc, header: errorH.}

proc msg*(err: ptr WasmtimeError): string =
  var name: wasm_name_t
  wasmtime_error_message(err, name.addr)
  result = name.strVal
  name.delete

proc ok[T](val: T): WasmtimeResult[T] =
  WasmtimeResult[T](kind: Ok, val: val)

proc ok(): WasmtimeResult[void] =
  WasmtimeResult[void](kind: Ok)

proc isOk*[T](self: WasmtimeResult[T]): bool =
  self.kind == Ok

proc isErr*[T](self: WasmtimeResult[T]): bool =
  self.kind == Err

proc toResult(err: ptr WasmtimeError, T: typedesc): WasmtimeResult[T] =
  WasmtimeResult[T](kind: Err, err: err)

template okOr*[T](res: WasmtimeResult[T], body: untyped): T =
  let temp = res
  if temp.isOk:
    temp.val
  else:
    body

template okOr*[T](res: WasmtimeResult[T], err: untyped, body: untyped): T =
  let temp = res
  if temp.isOk:
    temp.val
  else:
    let err = res.err
    body

# Config
type
  Strategy {.importc: "wasmtime_strategy_t", header: configH, size: sizeof(uint8), pure.} = enum
    Auto
    Cranelift

  OptLevel {.importc: "wasmtime_opt_level_t", header: configH, size: sizeof(uint8), pure.} = enum
    None
    Speed
    SpeedAndSize

  ProfilingStrategy {.importc: "wasmtime_profiling_strategy_t", size: sizeof(uint8), pure.} = enum
    None
    JitDump
    VTune
    PerfMap

# proc `debugInfo=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_debug_infog_set".}
# proc `consumeFuel=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_consume_fuel_set".}
# proc `epochInterruption=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_epoch_interruption_set".}
# proc `maxWasmStack=`(self: ptr wasm_config_t, val: csize_t) {.importc: "wasmtime_config_max_wasm_stack_set".}
# when defined(nimWasmtimeThreads):
#   proc `wasmThreads=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_threads_set".}
# proc `wasmTailCall=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_tail_call_set".}
# proc `wasmReferenceTypes=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_reference_types_set".}
# proc `wasmFunctionReferences=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_function_references_set".}
# proc `wasmGC=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_gc_set".}
# proc `wasmSimd=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_simd_set".}
# proc `wasmRelaxedSimd=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_relaxed_simd_set".}
# proc `wasmRelaxedSimdDeterministic=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_wasm_relaxed_simd_deterministic_set".}
# proc `=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_".}
# proc `=`(self: ptr wasm_config_t, val: bool) {.importc: "wasmtime_config_".}

# WASMTIME_CONFIG_PROP(void, wasm_bulk_memory, bool)
# WASMTIME_CONFIG_PROP(void, wasm_multi_value, bool)
# WASMTIME_CONFIG_PROP(void, wasm_multi_memory, bool)
# WASMTIME_CONFIG_PROP(void, wasm_memory64, bool)
# WASMTIME_CONFIG_PROP(void, strategy, wasmtime_strategy_t) # ifdef
# WASMTIME_CONFIG_PROP(void, parallel_compilation, bool) # ifdef
# WASMTIME_CONFIG_PROP(void, cranelift_debug_verifier, bool) # ifdef
# WASMTIME_CONFIG_PROP(void, cranelift_nan_canonicalization, bool) # ifdef
# WASMTIME_CONFIG_PROP(void, cranelift_opt_level, wasmtime_opt_level_t) # ifdef
# WASMTIME_CONFIG_PROP(void, profiler, wasmtime_profiling_strategy_t)
# WASMTIME_CONFIG_PROP(void, static_memory_forced, bool)
# WASMTIME_CONFIG_PROP(void, static_memory_maximum_size, uint64_t)
# WASMTIME_CONFIG_PROP(void, static_memory_guard_size, uint64_t)
# WASMTIME_CONFIG_PROP(void, dynamic_memory_guard_size, uint64_t)
# WASMTIME_CONFIG_PROP(void, dynamic_memory_reserved_for_growth, uint64_t)
# WASMTIME_CONFIG_PROP(void, native_unwind_info, bool)

type
  WasmtimeMemoryGetCallback* = proc(env: pointer, byteSize: ptr csize_t, maxByteSize: ptr csize_t): ptr UncheckedArray[uint8] {.cdecl.}
  WasmtimeMemoryGrowCallback* = proc(env: pointer, newSize: csize_t): ptr WasmtimeError {.cdecl.}
  WasmtimeNewMemoryCallback* = proc(env: pointer, typ: ptr wasm_memorytype_t, min: csize_t, max: csize_t, reservedBytes: csize_t, guardBytes: csize_t, res: ptr LinearMemory): ptr WasmtimeError {.cdecl.}
  WasmtimeFinalizer* = proc(data: pointer) {.cdecl.}

  LinearMemory* {.importc: "wasmtime_linear_memory", header: configH.} = object
    env*: pointer
    getMemory: WasmtimeMemoryGetCallback
    growMemory: WasmtimeMemoryGrowCallback
    finalizer: WasmtimeFinalizer

  MemoryCreator* {.importc: "wasmtime_memory_creator", header: configH.} = object
    env*: pointer
    newMemory: WasmtimeNewMemoryCallback
    finalizer: WasmtimeFinalizer

proc wasmtime_config_host_memory_creator_set*(self: ptr wasm_config_t, creator: ptr MemoryCreator) {.importc, header: configH.}

proc `hostMemoryCreator=`*(self: ptr wasm_config_t, creator: ptr MemoryCreator) =
  wasmtime_config_host_memory_creator_set(self, creator)

proc incrementEpoch*(self: ptr wasm_engine_t) {.importc: "wasmtime_engine_increment_epoch", header: engineH.}

# Store
type
  WasmtimeStore* {.importc: "wasmtime_store_t", header: storeH.} = object
  WasmtimeContext* {.importc: "wasmtime_context_t", header: storeH.} = object

# proc wasmtime_error_new*(msg: cstring): ptr Error {.importc: "wasmtime_error_new".}
proc new*(_: typedesc[WasmtimeStore], engine: ptr wasm_engine_t, data: pointer, finalizer: WasmtimeFinalizer): ptr WasmtimeStore {.importc: "wasmtime_store_new", header: storeH.}
proc context*(self: ptr WasmtimeStore): ptr WasmtimeContext {.importc: "wasmtime_store_context", header: storeH.}
proc delete*(self: ptr WasmtimeStore) {.importc: "wasmtime_store_delete", header: storeH.}

when defined(nimWasmtimeWasi):
  proc wasmtime_context_set_wasi*(context: ptr WasmtimeContext, wasi: ptr wasi_config_t) {.importc, header: storeH.}

# Module
type
  WasmtimeModule* {.importc: "wasmtime_module_t", header: moduleH.} = object

proc wasmtime_module_new*(engine: ptr wasm_engine_t, wasm: ptr uint8, len: csize_t, res: ptr ptr WasmtimeModule): ptr WasmtimeError {.importc: "wasmtime_module_new", header: moduleH.}

proc new*(_: typedesc[WasmtimeModule], engine: ptr wasm_engine_t, wasm: openArray[char]): WasmtimeResult[ptr WasmtimeModule] =
  var res: ptr WasmtimeModule = nil
  let err = wasmtime_module_new(engine, cast[ptr uint8](wasm[0].addr), wasm.len.csize_t, res.addr)
  if err != nil:
    return err.toResult(ptr WasmtimeModule)
  return res.ok

proc delete*(self: ptr WasmtimeModule) {.importc: "wasmtime_module_delete", header: moduleH.}
proc clone*(self: ptr WasmtimeModule): ptr WasmtimeModule {.importc: "wasmtime_module_clone", header: moduleH.}
proc wasmtime_module_imports*(self: ptr WasmtimeModule, res: ptr wasm_importtype_vec_t) {.importc, header: moduleH.}
proc imports*(self: ptr WasmtimeModule): wasm_importtype_vec_t =
  wasmtime_module_imports(self, result.addr)
proc wasmtime_module_exports*(self: ptr WasmtimeModule, res: ptr wasm_exporttype_vec_t) {.importc, header: moduleH.}
proc exports*(self: ptr WasmtimeModule): wasm_exporttype_vec_t =
  wasmtime_module_exports(self, result.addr)

# Extern
type
  WasmtimeFunc* {.importc: "wasmtime_func_t", header: externH.} = object

  WasmtimeGlobal* {.importc: "wasmtime_global_t", header: externH.} = object

  WasmtimeTable* {.importc: "wasmtime_table_t", header: externH.} = object

  WasmtimeMemory* {.importc: "wasmtime_memory_t", header: externH.} = object

  WasmtimeSharedMemory* = object

  WasmtimeExternKind* {.importc: "wasmtime_extern_kind_t", header: externH.} = enum
    Func
    Global
    Table
    Memory
    SharedMemory

  WasmtimeExternData* {.importc: "wasmtime_extern_union_t", header: externH, union.} = object
    function: WasmtimeFunc
    global: WasmtimeGlobal
    table: WasmtimeTable
    memory: WasmtimeMemory
    sharedMemory: ptr WasmtimeSharedMemory

  WasmtimeExtern* {.importc: "wasmtime_extern_t", header: externH.} = object
    kind: WasmtimeExternKind
    data: WasmtimeExternData

# Instance
type
  WasmtimeInstance* {.importc: "wasmtime_instance_t", header: instanceH.} = object
    store_id: uint64
    index: csize_t

proc wasmtime_instance_new*(store: ptr WasmtimeStore, module: ptr WasmtimeModule, imports: ptr WasmtimeExtern, importsLen: csize_t, instance: ptr WasmtimeInstance, trap: ptr ptr wasm_trap_t): ptr WasmtimeError {.importc, header: instanceH.}

proc new*(_: typedesc[WasmtimeInstance], store: ptr WasmtimeStore, module: ptr WasmtimeModule, imports: openArray[WasmtimeExtern], trap: ptr ptr wasm_trap_t): WasmtimeResult[WasmtimeInstance] =
  var res: WasmtimeInstance
  let err = wasmtime_instance_new(store, module, imports.data, imports.len.csize_t, res.addr, trap)
  if err != nil:
    return err.toResult(WasmtimeInstance)
  return res.ok

# Linker
type
  WasmtimeLinker* {.importc: "wasmtime_linker_t", header: linkerH.} = object

proc new*(_: typedesc[WasmtimeLinker], engine: ptr wasm_engine_t): ptr WasmtimeLinker {.importc: "wasmtime_linker_new", header: linkerH.}

proc defineWasi*(self: ptr WasmtimeLinker): ptr WasmtimeError {.importc: "wasmtime_linker_define_wasi", header: linkerH.}


proc wasmtime_linker_instantiate*(self: ptr WasmtimeLinker, context: ptr WasmtimeContext, module: ptr WasmtimeModule, instance: ptr WasmtimeInstance, trap: ptr ptr wasm_trap_t): ptr WasmtimeError {.importc, header: instanceH.}

proc instantiate*(self: ptr WasmtimeLinker, context: ptr WasmtimeContext, module: ptr WasmtimeModule, trap: ptr ptr wasm_trap_t): WasmtimeResult[WasmtimeInstance] =
  var res: WasmtimeInstance
  let err = wasmtime_linker_instantiate(self, context, module, res.addr, trap)
  if err != nil:
    return err.toResult(WasmtimeInstance)
  return res.ok