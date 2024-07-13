import std/[os, macros, genasts, strformat]

# const wasmDir* = "/mnt/c/Users/nimao/Downloads/wasmtime-v22.0.0-x86_64-linux-c-api/wasmtime-v22.0.0-x86_64-linux-c-api"
const wasmDir* = "src/wasmtime/crates/c-api"
const wasmH = "wasm.h"

{.passC: "-DLIBWASM_STATIC".}
{.passC: "-I" & wasmDir / "include".}
{.passL: "-L" & wasmDir / "lib".}
{.passL: "-L" & "src/wasmtime/target/debug".}
{.passL: "-l:libwasmtime.a -lm".}

macro wasiDeclareOwn(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasiDeclareOwn ", name.repr
    echo result.repr
    echo "-----------"
  let funcName = ident &"wasi_{name.repr}_delete"
  let typeName = ident &"wasi_{name.repr}_t"
  return genAst(funcName, typeName):
    type typeName* = object
    proc funcName*(self: ptr typeName) {.importc, header: wasmH.}

macro wasmDeclareOwn(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareOwn ", name.repr
    echo result.repr
    echo "-----------"
  let funcName = ident &"wasm_{name.repr}_delete"
  let typeName = ident &"wasm_{name.repr}_t"
  return genAst(funcName, typeName):
    type typeName* = object
    proc funcName*(self: ptr typeName) {.importc, header: wasmH.}

macro wasmDeclareVec(name: untyped, isPtr: static bool = false): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareVec ", name.repr, ", ptr = ", isPtr
    echo result.repr
  let vecName = ident &"wasm_{name.repr}_vec_t"
  let dataName = ident &"wasm_{name.repr}_t"
  let typeNameString = vecName.repr
  let dataType = if isPtr:
    genAst(dataName):
      ptr dataName
  else:
    dataName

  return genAst(vecName, typeNameString, dataName, dataType,
      newEmpty = ident &"wasm_{name.repr}_vec_new_empty",
      newUninitialized = ident &"wasm_{name.repr}_vec_new_uninitialized",
      new = ident &"wasm_{name.repr}_vec_new",
      copy = ident &"wasm_{name.repr}_vec_copy",
      deleteName = &"wasm_{name.repr}_vec_delete"):
    type vecName* {.importc: typeNameString, header: wasmH, bycopy.} = object
      size*: csize_t
      data*: ptr UncheckedArray[dataType]
    proc newEmpty*(res: ptr vecName) {.importc, header: wasmH.}
    proc newUninitialized*(res: ptr vecName, len: csize_t) {.importc, header: wasmH.}
    proc new*(res: ptr vecName, len: csize_t, data: ptr dataType) {.importc, header: wasmH.}
    proc copy*(res: ptr vecName, other: ptr vecName) {.importc, header: wasmH.}
    proc delete*(res: ptr vecName) {.importc: deleteName, header: wasmH.}
    proc delete*(res: sink vecName) =
      var res = res
      if res.data != nil:
        res.addr.delete
    proc low*(self: vecName): int = 0
    proc high*(self: vecName): int = self.size.int - 1
    proc len*(self: vecName): int = self.size.int
    proc `[]`*(self: var vecName, index: int): var dataType =
      assert index in 0..<self.len
      self.data[index]
    proc `[]`*(self: vecName, index: int): lent dataType =
      assert index in 0..<self.len
      self.data[index]
    proc `[]=`*(self: vecName, index: int, value: sink dataType) =
      assert index in 0..<self.len
      self.data[index] = value
    proc `$`*(self: vecName): string =
      var res = "["
      for i in 0..<self.len:
        if i > 0:
          res.add ", "
        when compiles($self.data[i]):
          res.add $self.data[i]
        else:
          res.add $cast[uint64](self.data[i])
      res.add "]"

    iterator items*(self: vecName): lent dataType =
      for i in 0..<self.len:
        yield self.data[i]

    iterator pairs*(self: vecName): (int, lent dataType) =
      for i in 0..<self.len:
        yield (i, self.data[i])

macro wasmDeclareType(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareType ", name.repr
    echo result.repr
  return genAst(name,
      typeName = ident &"wasm_{name.repr}_t",
      copy = ident &"wasm_{name.repr}_copy"):

    wasmDeclareOwn(name)
    wasmDeclareVec(name, isPtr = true)

    proc copy*(res: ptr typeName): ptr typeName {.importc, header: wasmH.}

macro wasmDeclareRefBase(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareRefBase ", name.repr
    echo result.repr
  return genAst(name,
      typeName = ident &"wasm_{name.repr}_t",
      copy = ident &"wasm_{name.repr}_copy",
      same = ident &"wasm_{name.repr}_copy",
      getHostInfo = ident &"wasm_{name.repr}_get_host_info",
      setHostInfo = ident &"wasm_{name.repr}_set_host_info",
      ):

    wasmDeclareOwn(name)

    proc copy*(res: ptr typeName): ptr typeName {.importc, header: wasmH.}
    proc same*(a: ptr typeName, b: ptr typeName): bool {.importc, header: wasmH.}
    proc getHostInfo*(self: ptr typeName): pointer {.importc, header: wasmH.}
    proc setHostInfo*(self: ptr typeName, data: pointer) {.importc, header: wasmH.}
    # proc setHostInfoWithFinalizer*(self: ptr typeName, data: pointer) {.importc, header: wasmH.}

macro wasmDeclareRef(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareRef ", name.repr
    echo result.repr
  return genAst(name,
      sharedName = ident &"shared_{name.repr}",
      typeName = ident &"wasm_{name.repr}_t",
      asRef = ident &"wasm_{name.repr}_as_ref",
      refAs = ident &"wasm_ref_as_{name.repr}",
      ):

    wasmDeclareRefBase(name)

    proc asRef*(res: ptr typeName): wasm_ref_t {.importc, header: wasmH.}
    proc refAs*(r: ptr wasm_ref_t): ptr typeName {.importc, header: wasmH.}

macro wasmDeclareSharableRef(name: untyped): untyped =
  let name = ident name.strVal
  defer:
    echo "wasmDeclareSharableRef ", name.repr
    echo result.repr
  return genAst(name,
      sharedName = ident &"shared_{name.repr}",
      sharedTypeName = ident &"wasm_shared_{name.repr}_t",
      typeName = ident &"wasm_{name.repr}_t",
      share = ident &"wasm_{name.repr}_share",
      same = ident &"wasm_{name.repr}_obtain",
      ):

    wasmDeclareRef(name)
    wasmDeclareOwn(sharedName)

    proc share*(self: ptr typeName): ptr sharedTypeName {.importc, header: wasmH.}
    proc obtain*(store: ptr wasm_store_t, shared: ptr sharedTypeName): ptr typeName {.importc, header: wasmH.}

type
  # wasm_name_t* = wasm_byte_vec_t

  # wasm_ref_t* = object

  wasm_mutability_enum* {.importc: "wasm_mutability_enum", header: wasmH.} = enum
    Const
    Var

  wasm_limits_t* {.importc: "wasm_limits_t", header: wasmH, bycopy.} = object
    min: uint32
    max: uint32

# Byte vectors
type wasm_byte_t* = uint8
wasmDeclareVec(byte)
type wasm_name_t* = wasm_byte_vec_t

# Config
wasmDeclareOwn(config)
proc wasm_config_new*(): ptr wasm_config_t {.importc, header: wasmH.}

# Engine
wasmDeclareOwn(engine)
proc wasm_engine_new*(): ptr wasm_engine_t {.importc, header: wasmH.}
proc wasm_engine_new_with_config*(config: ptr wasm_config_t): ptr wasm_engine_t {.importc, header: wasmH.}

# Store
wasmDeclareOwn(store)
proc wasm_store_new*(engine: ptr wasm_engine_t): ptr wasm_store_t {.importc, header: wasmH.}

# Value Types
wasmDeclareType(valtype)

type wasm_valkind_t* {.size: sizeof(uint8).} = enum
  I32, I64, F32, F64, ExternRef = 128, FuncRef

proc wasm_valtype_new*(kind: wasm_valkind_t): ptr wasm_valtype_t {.importc, header: wasmH.}
proc wasm_valtype_kind*(self: ptr wasm_valtype_t): wasm_valkind_t {.importc, header: wasmH.}

# Function types
wasmDeclareType(functype)
proc wasm_functype_new*(params: ptr wasm_valtype_vec_t, results: ptr wasm_valtype_vec_t): ptr wasm_functype_t {.importc, header: wasmH.}
proc wasm_functype_params*(self: ptr wasm_functype_t): ptr wasm_valtype_vec_t {.importc, header: wasmH.}
proc wasm_functype_results*(self: ptr wasm_functype_t): ptr wasm_valtype_vec_t {.importc, header: wasmH.}

# Global Types
wasmDeclareType(globaltype)
# todo

# Table Types
wasmDeclareType(tabletype)
# todo

# Memory Types
wasmDeclareType(memorytype)
# todo

# Extern Types
wasmDeclareType(externtype)

type wasm_externkind_t* {.size: sizeof(uint8).} = enum
  Func
  Global
  Table
  Memory

proc wasm_externtype_kind*(self: ptr wasm_externtype_t): wasm_externkind_t {.importc, header: wasmH.}

proc wasm_functype_as_externtype*(self: ptr wasm_functype_t): ptr wasm_externtype_t {.importc, header: wasmH.}
proc wasm_globaltype_as_externtype*(self: ptr wasm_globaltype_t): ptr wasm_externtype_t {.importc, header: wasmH.}
proc wasm_tabletype_as_externtype*(self: ptr wasm_tabletype_t): ptr wasm_externtype_t {.importc, header: wasmH.}
proc wasm_memorytype_as_externtype*(self: ptr wasm_memorytype_t): ptr wasm_externtype_t {.importc, header: wasmH.}
proc wasm_externtype_as_functype*(self: ptr wasm_externtype_t): ptr wasm_functype_t {.importc, header: wasmH.}
proc wasm_externtype_as_globaltype*(self: ptr wasm_externtype_t): ptr wasm_globaltype_t {.importc, header: wasmH.}
proc wasm_externtype_as_tabletype*(self: ptr wasm_externtype_t): ptr wasm_tabletype_t {.importc, header: wasmH.}
proc wasm_externtype_as_memorytype*(self: ptr wasm_externtype_t): ptr wasm_memorytype_t {.importc, header: wasmH.}
# todo

# Import Types
wasmDeclareType(importtype)

proc wasm_importtype_new*(module: ptr wasm_name_t, name: ptr wasm_name_t, typ: ptr wasm_externtype_t): ptr wasm_importtype_t {.importc, header: wasmH.}
proc wasm_importtype_module*(self: ptr wasm_importtype_t): ptr wasm_name_t {.importc, header: wasmH.}
proc wasm_importtype_name*(self: ptr wasm_importtype_t): ptr wasm_name_t {.importc, header: wasmH.}
proc wasm_importtype_type*(self: ptr wasm_importtype_t): ptr wasm_externtype_t {.importc, header: wasmH.}

# Export Types
wasmDeclareType(exporttype)

proc wasm_exporttype_new*(name: ptr wasm_name_t, typ: ptr wasm_externtype_t): ptr wasm_exporttype_t {.importc, header: wasmH.}
proc wasm_exporttype_name*(self: ptr wasm_exporttype_t): ptr wasm_name_t {.importc, header: wasmH.}
proc wasm_exporttype_type*(self: ptr wasm_exporttype_t): ptr wasm_externtype_t {.importc, header: wasmH.}

################################################
# Runtime objects

# References

wasmDeclareRefBase("ref")

# Values

type
  wasm_valdata_t* {.union.} = object
    i32: int32
    i64: int64
    f32: float32
    f64: float64
    re: ptr wasm_ref_t

  wasm_val_t* = object
    kind: wasm_valkind_t
    data: wasm_valdata_t

wasmDeclareVec(val)

proc wasm_val_delete*(self: ptr wasm_val_t) {.importc, header: wasmH.}
proc wasm_val_copy*(res: ptr wasm_val_t, b: ptr wasm_val_t) {.importc, header: wasmH.}

# Frames
wasmDeclareOwn(frame)
wasmDeclareVec(frame, isPtr = true)

proc wasm_frame_copy*(self: wasm_frame_t): ptr wasm_frame_t {.importc, header: wasmH.}
proc wasm_frame_func_index*(self: wasm_frame_t): uint32 {.importc, header: wasmH.}
proc wasm_frame_func_offset*(self: wasm_frame_t): csize_t {.importc, header: wasmH.}
proc wasm_frame_module_offset*(self: wasm_frame_t): csize_t {.importc, header: wasmH.}

# Traps
wasmDeclareRef(trap)
# todo

# Foreign Objects
# todo

# Modules
wasmDeclareSharableRef(module)

proc wasm_module_new*(store: ptr wasm_store_t, binary: ptr wasm_byte_vec_t): ptr wasm_module_t {.importc, header: wasmH.}
proc wasm_module_validate*(store: ptr wasm_store_t, binary: ptr wasm_byte_vec_t): bool {.importc, header: wasmH.}

proc wasm_module_imports*(self: ptr wasm_module_t, res: ptr wasm_importtype_vec_t) {.importc, header: wasmH.}
proc wasm_module_exports*(self: ptr wasm_module_t, res: ptr wasm_exporttype_vec_t) {.importc, header: wasmH.}

proc wasm_module_serialize*(self: ptr wasm_module_t, res: ptr wasm_byte_vec_t) {.importc, header: wasmH.}
proc wasm_module_deserialize*(store: ptr wasm_store_t, binary: ptr wasm_byte_vec_t): ptr wasm_module_t {.importc, header: wasmH.}

# Function Instances
wasmDeclareRef("func")
# todo

# Global Instances
wasmDeclareRef(global)
# todo

# Table Instances
wasmDeclareRef(table)
# todo

# Memory Instances
wasmDeclareRef(memory)
# todo

# Externals Instances
wasmDeclareRef(extern)
wasmDeclareVec(extern, isPtr = true)

proc wasm_extern_kind*(self: ptr wasm_extern_t): wasm_externkind_t {.importc, header: wasmH.}
proc wasm_extern_type*(self: ptr wasm_extern_t): ptr wasm_externtype_t {.importc, header: wasmH.}

proc wasm_func_as_extern*(self: ptr wasm_func_t): ptr wasm_extern_t {.importc, header: wasmH.}
proc wasm_global_as_extern*(self: ptr wasm_global_t): ptr wasm_extern_t {.importc, header: wasmH.}
proc wasm_table_as_extern*(self: ptr wasm_table_t): ptr wasm_extern_t {.importc, header: wasmH.}
proc wasm_memory_as_extern*(self: ptr wasm_memory_t): ptr wasm_extern_t {.importc, header: wasmH.}
proc wasm_extern_as_func*(self: ptr wasm_extern_t): ptr wasm_func_t {.importc, header: wasmH.}
proc wasm_extern_as_global*(self: ptr wasm_extern_t): ptr wasm_global_t {.importc, header: wasmH.}
proc wasm_extern_as_table*(self: ptr wasm_extern_t): ptr wasm_table_t {.importc, header: wasmH.}
proc wasm_extern_as_memory*(self: ptr wasm_extern_t): ptr wasm_memory_t {.importc, header: wasmH.}
# todo

# Module Instances
wasmDeclareRef(instance)

# todo
proc wasm_instance_new*(store: ptr wasm_store_t, module: ptr wasm_module_t, imports: ptr wasm_extern_vec_t, trap: ptr ptr wasm_trap_t): ptr wasm_instance_t {.importc, header: wasmH.}
proc wasm_instance_exports*(self: ptr wasm_instance_t, res: ptr wasm_extern_vec_t) {.importc, header: wasmH.}

proc wasm_frame_instance*(self: wasm_frame_t): ptr wasm_instance_t {.importc, header: wasmH.}

when defined(nimWasmtimeWasi):
  {.passC: "-DWASMTIME_FEATURE_WASI".}

  wasiDeclareOwn(config)
  proc wasi_config_new*(): ptr wasi_config_t {.importc, header: wasmH.}


proc isNum*(kind: wasm_valkind_t): bool = kind in {I32, I64, F32, F64}
proc isRef*(kind: wasm_valkind_t): bool = kind in {ExternRef, FuncRef}
proc isNum*(self: ptr wasm_valtype_t): bool = self.wasm_valtype_kind.isNum
proc isRef*(self: ptr wasm_valtype_t): bool = self.wasm_valtype_kind.isRef

proc toWasmName*(s: string): wasm_name_t =
  wasm_byte_vec_new(result.addr, s.len.csize_t, cast[ptr wasm_byte_t](s[0].addr))

proc strVal*(name: wasm_name_t): string =
  result = newStringOfCap(name.size.int)
  for i in 0..<name.size.int:
    result.add cast[char](name.data[i])

proc `$`*(self: ptr wasm_externtype_t): string =
  if self == nil:
    return "nil"

  result = ""
  case self.wasm_externtype_kind
  of Func:
    let f = self.wasm_externtype_as_functype
    let params = f.wasm_functype_params
    let results = f.wasm_functype_results

    result.add "("

    for i in 0..<params.size.int:
      if i > 0:
        result.add ", "
      let kind = params.data[i].wasm_valtype_kind
      result.add $kind

    result.add ") -> ("

    for i in 0..<results.size.int:
      if i > 0:
        result.add ", "
      let kind = results.data[i].wasm_valtype_kind
      result.add $kind

    result.add ")"

  else:
    discard

proc `$`*(self: ptr wasm_exporttype_t): string =
  if self == nil:
    return "nil"

  let name = self.wasm_exporttype_name()
  if name == nil:
    result.add "nil"
  else:
    result.add name[].strVal
  result.add ": "
  result.add $self.wasm_exporttype_type()

proc `$`*(self: ptr wasm_importtype_t): string =
  if self == nil:
    return "nil"

  let name = self.wasm_importtype_name()
  if name == nil:
    result.add "nil"
  else:
    result.add name[].strVal
  result.add ": "
  result.add $self.wasm_importtype_type()
