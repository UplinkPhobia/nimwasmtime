import std/[os, macros, genasts, strformat, strutils, options]

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
const funcH = "wasmtime/func.h"
const valH = "wasmtime/val.h"

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
      err*: tuple[msg: string, status: int, trace: wasm_frame_vec_t]

# proc wasmtime_error_new*(msg: cstring): ptr Error {.importc: "wasmtime_error_new".}
proc new*(_: typedesc[WasmtimeError], msg: cstring): ptr WasmtimeError {.importc: "wasmtime_error_new", header: errorH.}
proc delete*(err: ptr WasmtimeError) {.importc: "wasmtime_error_delete", header: errorH.}
proc wasmtime_error_message*(err: ptr WasmtimeError, res: ptr wasm_name_t) {.importc, header: errorH.}
proc wasmtime_error_exit_status*(err: ptr WasmtimeError, res: ptr cint) {.importc, header: errorH.}
proc wasmtime_error_wasm_trace*(err: ptr WasmtimeError, res: ptr wasm_frame_vec_t) {.importc, header: errorH.}

proc msg*(err: ptr WasmtimeError): string =
  var name: wasm_name_t
  wasmtime_error_message(err, name.addr)
  result = name.strVal

proc exitStatus*(err: ptr WasmtimeError): int =
  var exitStatus: cint
  wasmtime_error_exit_status(err, exitStatus.addr)
  result = exitStatus.int

proc wasmTrace*(err: ptr WasmtimeError): wasm_frame_vec_t =
  wasmtime_error_wasm_trace(err, result.addr)

proc ok[T](val: sink T): WasmtimeResult[T] =
  WasmtimeResult[T](kind: Ok, val: val)

proc ok(): WasmtimeResult[void] =
  WasmtimeResult[void](kind: Ok)

proc isOk*[T](self: WasmtimeResult[T]): bool =
  self.kind == Ok

proc isErr*[T](self: WasmtimeResult[T]): bool =
  self.kind == Err

proc toResult*(err: ptr WasmtimeError, T: typedesc): WasmtimeResult[T] =
  if err == nil:
    WasmtimeResult[T](kind: Ok)
  else:
    let msg = err.msg()
    let exitStatus = err.exitStatus()
    let trace = err.wasmTrace()
    err.delete()
    WasmtimeResult[T](kind: Err, err: (msg, exitStatus, trace))

template okOr*[T](res: WasmtimeResult[T], body: untyped): T =
  let temp = res
  if temp.isOk:
    when T isnot void:
      temp.val
  else:
    body

template okOr*[T](res: WasmtimeResult[T], err: untyped, body: untyped): T =
  let temp = res
  if temp.isOk:
    when T isnot void:
      temp.val
  else:
    let err {.cursor.} = res.err
    body

# Config
type
  Strategy* {.importc: "wasmtime_strategy_t", header: configH, size: sizeof(uint8), pure.} = enum
    Auto
    Cranelift

  OptLevel* {.importc: "wasmtime_opt_level_t", header: configH, size: sizeof(uint8), pure.} = enum
    None
    Speed
    SpeedAndSize

  ProfilingStrategy* {.importc: "wasmtime_profiling_strategy_t", size: sizeof(uint8), pure.} = enum
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

macro wasmtimeDeclareOwn(name: untyped, headerName: untyped): untyped =
  let name = ident name.strVal
  return genAst(
      cTypeName = ident &"wasmtime_{name.repr}_t",
      ownedTypeName = ident &"Wasmtime{name.repr.capitalizeAscii}",
      deleteName = &"wasmtime_{name.repr}_delete",
      headerName):
    type cTypeName* {.importc, header: headerName.} = object
    type ownedTypeName* = object
      it*: ptr cTypeName
    proc delete*(self: ptr cTypeName) {.importc: deleteName, header: headerName.}
    proc `=destroy`(self: ownedTypeName) =
      if self.it != nil:
        self.it.delete()
    proc `=copy`(self: var ownedTypeName, b: ownedTypeName) {.error.}
    proc take(self: sink ownedTypeName): ptr cTypeName {.used.} =
      var self = self
      let it = self.it
      self.it = nil
      it

# Store

type
  # WasmtimeStore* {.importc: "wasmtime_store_t", header: storeH.} = object
  WasmtimeContext* {.importc: "wasmtime_context_t", header: storeH.} = object

wasmtimeDeclareOwn(store, storeH)

# Module

# type
#   WasmtimeModule* {.importc: "wasmtime_module_t", header: moduleH.} = object
wasmtimeDeclareOwn(module, moduleH)

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
    `func`*: WasmtimeFunc
    global*: WasmtimeGlobal
    table*: WasmtimeTable
    memory*: WasmtimeMemory
    sharedMemory*: ptr WasmtimeSharedMemory

  WasmtimeExtern* {.importc: "wasmtime_extern_t", header: externH.} = object
    kind*: WasmtimeExternKind
    `of`*: WasmtimeExternData

# Instance
type
  WasmtimeInstance* {.importc: "wasmtime_instance_t", header: instanceH.} = object
    store_id: uint64
    index: csize_t

# Linker
# type
#   WasmtimeLinker* {.importc: "wasmtime_linker_t", header: linkerH.} = object
wasmtimeDeclareOwn(linker, linkerH)

# Val

type

  WasmtimeAnyRef* {.importc: "wasmtime_anyref_t", header: valH, union.} = array[16, uint8]
  WasmtimeExternRef* {.importc: "wasmtime_externref_t", header: valH, union.} = object
  WasmtimeFuncRef* {.importc: "wasmtime_funcref_t", header: valH, union.} = object
  WasmtimeV128* {.importc: "wasmtime_valunion_t", header: valH, union.} = object

  WasmtimeValKind* {.importc: "wasmtime_valkind_t", header: valH.} = enum
    I32
    I64
    F32
    F64
    V128
    FuncRef
    ExternRef
    AnyRef

  WasmtimeValData* {.importc: "wasmtime_valunion_t", header: valH, union.} = object
    i32: int32
    i64: int64
    f32: float32
    f64: float64
    anyref: WasmtimeAnyRef
    externref: WasmtimeExternRef
    funcref: WasmtimeFuncRef
    v128: WasmtimeV128

  WasmtimeVal* {.importc: "wasmtime_val_t", header: funcH.} = object
    kind*: WasmtimeValKind
    `of`*: WasmtimeValData

# Func

type
  WasmtimeCaller* {.importc: "wasmtime_caller_t", header: funcH.} = object

  WasmtimeFuncCallback* {.importc: "wasmtime_func_callback_t", header: funcH.} =
    proc(env: pointer, caller: ptr WasmtimeCaller, args: ptr UncheckedArray[WasmtimeVal],
      nargs: csize_t, results: ptr UncheckedArray[WasmtimeVal], nresults: csize_t):
        ptr wasm_trap_t {.cdecl.}

# Config

proc wasmtime_config_host_memory_creator_set*(self: ptr wasm_config_t, creator: ptr MemoryCreator) {.importc, header: configH.}

proc `hostMemoryCreator=`*(self: ptr wasm_config_t, creator: ptr MemoryCreator) =
  wasmtime_config_host_memory_creator_set(self, creator)

proc incrementEpoch*(self: ptr wasm_engine_t) {.importc: "wasmtime_engine_increment_epoch", header: engineH.}

# Store

# proc wasmtime_error_new*(msg: cstring): ptr Error {.importc: "wasmtime_error_new".}
proc wasmtime_store_new*(engine: ptr wasm_engine_t, data: pointer, finalizer: WasmtimeFinalizer): ptr wasmtime_store_t {.importc, header: storeH.}
proc new*(_: typedesc[WasmtimeStore], engine: WasmEngine, data: pointer, finalizer: WasmtimeFinalizer): WasmtimeStore =
  let store = wasmtime_store_new(engine.it, data, finalizer)
  WasmtimeStore(it: store)

proc wasmtime_store_context*(self: ptr wasmtime_store_t): ptr WasmtimeContext {.importc, header: storeH.}
proc context*(self: WasmtimeStore): ptr WasmtimeContext =
  wasmtime_store_context(self.it)

when nimWasmtimeWasi:
  proc wasmtime_context_set_wasi*(context: ptr WasmtimeContext, wasi: ptr wasi_config_t) {.importc, header: storeH.}

# Module

proc wasmtime_module_new*(engine: ptr wasm_engine_t, wasm: ptr uint8, len: csize_t, res: ptr ptr wasmtime_module_t): ptr WasmtimeError {.importc: "wasmtime_module_new", header: moduleH.}

proc new*(_: typedesc[WasmtimeModule], engine: ptr wasm_engine_t, wasm: openArray[char]): WasmtimeResult[WasmtimeModule] =
  var res: ptr wasmtime_module_t = nil
  let err = wasmtime_module_new(engine, cast[ptr uint8](wasm[0].addr), wasm.len.csize_t, res.addr)
  if err != nil:
    return err.toResult(WasmtimeModule)
  return WasmtimeModule(it: res).ok

proc wasmtime_module_clone*(self: ptr wasmtime_module_t): ptr wasmtime_module_t {.importc, header: moduleH.}
proc wasmtime_module_imports*(self: ptr wasmtime_module_t, res: ptr wasm_importtype_vec_t) {.importc, header: moduleH.}

proc imports*(self: WasmtimeModule): wasm_importtype_vec_t =
  wasmtime_module_imports(self.it, result.addr)

proc wasmtime_module_exports*(self: ptr wasmtime_module_t, res: ptr wasm_exporttype_vec_t) {.importc, header: moduleH.}

proc exports*(self: WasmtimeModule): wasm_exporttype_vec_t =
  wasmtime_module_exports(self.it, result.addr)

# Instance

proc wasmtime_instance_new*(store: ptr wasmtime_store_t, module: ptr wasmtime_module_t,
  imports: ptr WasmtimeExtern, importsLen: csize_t, instance: ptr WasmtimeInstance,
  trap: ptr ptr wasm_trap_t): ptr WasmtimeError {.importc, header: instanceH.}

proc new*(_: typedesc[WasmtimeInstance], store: ptr wasmtime_store_t, module: WasmtimeModule,
    imports: openArray[WasmtimeExtern], trap: ptr ptr wasm_trap_t): WasmtimeResult[WasmtimeInstance] =
  var res: WasmtimeInstance
  let err = wasmtime_instance_new(store, module.it, imports.data, imports.len.csize_t, res.addr, trap)
  if err != nil:
    return err.toResult(WasmtimeInstance)
  return res.ok

proc wasmtime_instance_export_get*(store: ptr WasmtimeContext, instance: ptr WasmtimeInstance,
  name: cstring, nameLen: csize_t, res: ptr WasmtimeExtern): bool {.importc, header: instanceH.}
proc wasmtime_instance_export_nth*(store: ptr WasmtimeContext, instance: ptr WasmtimeInstance,
  index: csize_t, name: ptr cstring, nameLen: ptr csize_t, res: ptr WasmtimeExtern):
    bool {.importc, header: instanceH.}

proc getExport*(instance: WasmtimeInstance, store: ptr WasmtimeContext, name: string):
    Option[WasmtimeExtern] =
  var instance = instance
  var res: WasmtimeExtern
  if not wasmtime_instance_export_get(store, instance.addr, name.cstring, name.len.csize_t, res.addr):
    return
  res.some

proc getExport*(instance: WasmtimeInstance, store: ptr WasmtimeContext, index: int):
    Option[tuple[name: string, extern: WasmtimeExtern]] =
  var instance = instance
  var name: cstring = ""
  var nameLen: csize_t = 0
  var res: WasmtimeExtern
  if not wasmtime_instance_export_nth(store, instance.addr, index.csize_t, name.addr, nameLen.addr, res.addr):
    return
  (name.toOpenArray(0, nameLen.int - 1).join(), res).some

# Linker

proc wasmtime_linker_new*(engine: ptr wasm_engine_t): ptr wasmtime_linker_t {.importc, header: linkerH.}
proc new*(_: typedesc[WasmtimeLinker], engine: WasmEngine): WasmtimeLinker =
  let linker = wasmtime_linker_new(engine.it)
  WasmtimeLinker(it: linker)

proc wasmtime_linker_define_wasi*(self: ptr wasmtime_linker_t):
  ptr WasmtimeError {.importc, header: linkerH.}

proc defineWasi*(self: WasmtimeLinker): WasmtimeResult[void] =
  wasmtime_linker_define_wasi(self.it).toResult(void)

proc wasmtime_linker_define*(self: ptr wasmtime_linker_t, context: ptr WasmtimeContext,
  module: cstring, moduleLen: csize_t, name: cstring, nameLen: csize_t, item: ptr WasmtimeExtern):
    ptr WasmtimeError {.importc, header: instanceH.}

proc wasmtime_linker_define_func*(self: ptr wasmtime_linker_t,
  module: cstring, moduleLen: csize_t, name: cstring, nameLen: csize_t, typ: ptr wasm_functype_t,
  cb: WasmtimeFuncCallback, data: pointer, finalizer: WasmtimeFinalizer):
    ptr WasmtimeError {.importc, header: instanceH.}

proc wasmtime_linker_instantiate*(self: ptr wasmtime_linker_t, context: ptr WasmtimeContext,
  module: ptr wasmtime_module_t, instance: ptr WasmtimeInstance, trap: ptr ptr wasm_trap_t):
    ptr WasmtimeError {.importc, header: instanceH.}

proc instantiate*(self: WasmtimeLinker, context: ptr WasmtimeContext, module: WasmtimeModule,
    trap: ptr ptr wasm_trap_t): WasmtimeResult[WasmtimeInstance] =
  var res: WasmtimeInstance
  let err = wasmtime_linker_instantiate(self.it, context, module.it, res.addr, trap)
  if err != nil:
    return err.toResult(WasmtimeInstance)
  return res.ok

proc defineFunc*(self: WasmtimeLinker, module: string, name: string, typ: ptr wasm_functype_t,
  cb: WasmtimeFuncCallback, data: pointer = nil, finalizer: WasmtimeFinalizer = nil):
    WasmtimeResult[void] =

  let err = wasmtime_linker_define_func(self.it, module.cstring, module.len.csize_t, name.cstring,
    name.len.csize_t, typ, cb, data, finalizer)

  return err.toResult(void)

# Val

func toWasmtimeVal*(x: int32): WasmtimeVal =
  WasmtimeVal(kind: WasmtimeValKind.I32, `of`: WasmtimeValData(i32: x))

func toWasmtimeVal*(x: int64): WasmtimeVal =
  WasmtimeVal(kind: WasmtimeValKind.I64, `of`: WasmtimeValData(i64: x))

func `$`*(val: WasmtimeVal): string =
  case val.kind
  of I32: $val.`of`.i32
  of I64: $val.`of`.i64
  of F32: $val.`of`.f32
  of F64: $val.`of`.f64
  of V128: "v128"
  of FuncRef: "funcref"
  of ExternRef: "externref"
  of AnyRef: "anyref"

# Func

proc wasmtime_func_call*(store: ptr WasmtimeContext, f: ptr WasmtimeFunc,
  args: ptr WasmtimeVal, nargs: csize_t, results: ptr WasmtimeVal, nresults: csize_t,
  trap: ptr ptr wasm_trap_t): ptr WasmtimeError {.importc, header: funcH.}

proc call*(f: ptr WasmtimeFunc, store: ptr WasmtimeContext, args: openArray[WasmtimeVal],
    results: openArray[WasmtimeVal], trap: ptr ptr wasm_trap_t): ptr WasmtimeError =
  wasmtime_func_call(store, f, args.data, args.len.csize_t, results.data, results.len.csize_t, trap)

