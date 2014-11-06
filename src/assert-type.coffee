_  = require 'underscore'
util = require 'util'
nativeAssert = require 'assert'

TypeAssertionError = (expected, actual) ->
  this.message = 'expected ' + expected
  this.expected = expected
  this.actual = actual
  Error.captureStackTrace(this, this.constructor)
util.inherits(TypeAssertionError, nativeAssert.AssertionError)
TypeAssertionError.prototype.name = 'TypeAssertionError'

module.exports.TypeAssertionError = TypeAssertionError

# dummy constructor to support "x instanceof Type"
Type = () ->
util.inherits(Type, Function)

makeType = (name, desc, test) ->
  cons = () ->
  util.inherits(cons, Type)

  ans = ((x) -> return test(x))

  # here be dragons...
  ans.__proto__ = cons.prototype
  ans.constructor = cons
  ans.typeName = name
  ans.typeDesc = desc
  nativeAssert(_.isFunction(ans) and ans instanceof Function and ans instanceof Type and ans instanceof cons)
  return ans

###
SIMPLE TYPES
###

# helper
isInt = (x) -> _.isNumber(x) and not _.isNaN(x) and x>Number.NEGATIVE_INFINITY and x<Number.POSITIVE_INFINITY and Math.floor(x) == x

# dummy constructor to support "f instanceof TypedFun"
TypedFun = () ->
util.inherits(TypedFun, Function)

# Simple type specifications
simpleTypes =
  bool:                ['boolean',                    _.isBoolean]
  num:                 ['number',                     _.isNumber]
  'num.not.nan':       ['non-NaN number',             ((x) -> _.isNumber(x) and not _.isNaN(x))]
  'num.pos':           ['positive number',            ((x) -> _.isNumber(x) and not _.isNaN(x) and x>0)]
  'num.neg':           ['negative number',            ((x) -> _.isNumber(x) and not _.isNaN(x) and x<0)]
  'num.nonneg':        ['nonnegative number',         ((x) -> _.isNumber(x) and not _.isNaN(x) and x>=0)]
  'num.finite':        ['finite number',              ((x) -> _.isNumber(x) and not _.isNaN(x) and x>Number.NEGATIVE_INFINITY and x<Number.POSITIVE_INFINITY)]
  'num.finite.pos':    ['positive finite number',     ((x) -> _.isNumber(x) and not _.isNaN(x) and x>0 and x<Number.POSITIVE_INFINITY)]
  'num.finite.neg':    ['negative finite number',     ((x) -> _.isNumber(x) and not _.isNaN(x) and x<0 and x>Number.NEGATIVE_INFINITY)]
  'num.finite.nonneg': ['nonnegative finite number',  ((x) -> _.isNumber(x) and not _.isNaN(x) and x>=0 and x<Number.POSITIVE_INFINITY)]
  int:                 ['integer',                    isInt]
  'int.pos':           ['positive integer',           ((x) -> isInt(x) and x>0)]
  'int.neg':           ['negative integer',           ((x) -> isInt(x) and x<0)]
  'int.nonneg':        ['nonnegative integer',        ((x) -> isInt(x) and x>=0)]
  str:                 ['string',                     _.isString]
  'str.ne':            ['nonempty string',            ((x) -> _.isString(x) and x.length>0)]
  arr:                 ['array',                      _.isArray]
  'arr.ne':            ['nonempty array',             ((x) -> _.isArray(x) and x.length>0)]
  obj:                 ['object',                     ((x) -> typeof x == 'object')]
  'obj.not.null':      ['non-null object',            ((x) -> typeof x == 'object' and x != null)]
  null:                ['null',                       ((x) -> x == null)]
  undefined:           ['undefined',                  ((x) -> x == undefined)]
  defined:             ['defined',                    ((x) -> x != undefined)]
  fun:                 ['function',                   _.isFunction]
  'fun.typed':         ['typed function',             ((x) -> x instanceof TypedFun)]
  any:                 ['anything',                   ((x) -> true)]
  type:                ['type',                       ((x) -> x instanceof Type)]

# helper to instantiate the nested namespace -- that is, turn a string like
# 'num.finite' into an object hierarchy
fillPath = (target, path, x) ->
  if path.length == 1
    target[path] = x
  else
    key = path.shift()
    if not (key of target) then target[key] = {}
    fillPath(target[key], path, x)

# Compile the simple type specifications (above) into the exported types
compileSimpleTypes = () ->
  ans = {}
  for key in _.keys(simpleTypes)
    desc = simpleTypes[key][0]
    test = simpleTypes[key][1]
    fillPath(ans, key.split('.'), makeType(key, desc, test))
  return ans
s = compileSimpleTypes() # so that we can use them below

###
Assert: given a type, return a function of one argument that throws
TypeAssertionError if its argument is not of that type.
###

assert1 = (ty) ->
  if not s.type(ty) then throw new TypeAssertionError('type', ty)
  (x) ->
    if ty(x) then return x
    throw new TypeAssertionError(ty.typeDesc, x)
# support assert(ty_x, ty_y, ...)(x, y, ...)
assert = () ->
  tys = Array.prototype.slice.call(arguments)
  if tys.length <= 1 then return assert1(tys[0])
  for ty in tys
    if not s.type(ty) then throw new TypeAssertionError('type array', tys)
  () ->
    xs = Array.prototype.slice.call(arguments)
    if xs.length != tys.length then throw new TypeAssertionError('#{tys.length} value(s) to typecheck', xs)
    i = 0
    while i < tys.length
      assert1(tys[i])(xs[i])
      i++
    return xs
T = assert # so that we can use this below

###
COMPOSITE TYPES
###

# or: union of several types
$or = () ->
  tys = Array.prototype.slice.call(arguments)
  T(s.arr.ne)(tys)
  tys.forEach(T(s.type))
  tynames = tys.map((ty) -> ty.typeName)
  name = "or(#{tynames.join(', ')})"
  tydescs = tys.map((ty) -> ty.typeDesc)
  desc = "one of (#{tydescs.join(', ')})"
  makeType name, desc, (x) ->
    for ty in tys
      if ty(x) then return true
    return false

# array of a single type (arbitrary length)
arrOfOne = (ne, ty) ->
  makeType "arr.of(#{ty.typeName})", "#{ty.typeDesc} array", (x) ->
    if ne then if not s.arr.ne(x) then return false
    else if not s.arr(x) then return false
    for item in x
      if not ty(item) then return false
    return true
# array with types specified for each element
arrOfMulti = (tys) ->
  tys.forEach(T(s.type))
  names = tys.map((ty) -> ty.typeName)
  descs = tys.map((ty) -> ty.typeDesc)
  makeType "arr.of([#{names.join(', ')}])", "[#{descs.join(', ')}] array", (x) ->
    if not _.isArray(x) or x.length != tys.length then return false
    i = 0
    while i < tys.length
      if not tys[i](x[i]) then return false
      i++
    return true 

# object matching prototype (keys to types)
# only: if true, do not permit the object to have any other keys
objOf = (only, proto) ->
  T(s.bool, s.obj)(only, proto)
  protoKeys = _.keys(proto)
  nameItems = []
  descItems = []
  for key in protoKeys
    T(s.type)(proto[key])
    nameItems.push("#{key}: #{proto[key].typeName}")
    descItems.push("#{key}: #{proto[key].typeDesc}")
  fn = if only then 'obj.of' else 'obj.with'
  fd = if only then 'object' else '>=object'
  makeType "#{fn}({#{nameItems.join(', ')}})", "{#{descItems.join(', ')}} #{fd}", (x) ->
    if not _.isObject(x) then return false
    xKeys = _.keys(x)
    if only and _.keys(x).length != protoKeys.length then return false
    for key in protoKeys
      if not proto[key](x[key]) then return false
    return true

# function of given argument types and return type (goes with TypedFun, below)
funOf = (args, ret) ->
  T(arrOfOne(false, s.type), s.type)(args, ret) # TODO: improve error message from this assertion
  tyname = "fun.of([#{args.map((ty) -> ty.typeName).join(', ')}], #{ret.typeName})"
  tydesc = "(#{args.map((ty) -> ty.typeDesc).join(', ')}) -> #{ret.typeDesc}"
  ty = makeType tyname, tydesc, (x) ->
    if not s.fun.typed(x) then return false
    # Judge equivalence of the function types by comparing the name strings.
    # TODO: improve this
    return (tyname == x.__funType__.typeName)
  ty.sig = { args: args, ret: ret }
  return ty

compositeTypes =
  'or': $or

  # function of N arguments (not really composite, but needs special name/description)
  funN: (N) ->
          T(s.int.nonneg)(N)
          makeType "funN(#{N})", "#{N}-ary function", (x) ->
            s.fun(x) and x.length == N

  # instance of given constructor (ditto)
  'inst.of': (Cons) ->
                T(s.fun)(Cons)
                # TODO: improve name & description
                makeType "inst.of(...)", "instance of a specific constructor", (x) ->
                  s.obj(x) and (x instanceof Cons)

  'arr.of': (ty) ->
              T($or(s.type, s.arr))(ty)
              if s.type(ty)
                return arrOfOne(false, ty)
              else
                return arrOfMulti(ty)

  'arr.ne.of': (ty) ->
                  T(s.type)(ty)
                  return arrOfOne(true, ty)

  'obj.of': ((proto) -> objOf(true, proto))

  'obj.with': ((proto) -> objOf(false, proto))

  'fun.of': funOf
              
addCompositeTypes = (ans) ->
  for key in _.keys(compositeTypes)
    fillPath(ans, key.split('.'), compositeTypes[key])
  return ans

# TypedFun: wrap a function to assert its runtime arguments and return value
# satisfy  a fun.of signature:
#   TypedFun(fun.of([ty_arg1, ty_arg2, ...], ret_ty), fn)
# the following helper also permits the following sugar:
#   TypedFun([ty_arg1, ty_arg2, ...], ret_ty, fn)
TypedFunArgs = () ->
  args = Array.prototype.slice.call(arguments)
  # TODO: improve error message from the following assertion
  T($or(arrOfMulti([s.type, s.fun]), arrOfMulti([arrOfOne(false, s.type), s.type, s.fun])))(args)
  if args.length is 2
    fnty = args[0]
    if not objOf(false, {sig: objOf(false, {args: arrOfOne(false, s.type), ret: s.type})})({sig: fnty.sig})
      throw new TypeAssertionError("function type (fun or fun.of(...))", fnty)
    ans = 
      args_ty: fnty.sig.args
      ret_ty: fnty.sig.ret
      fn: args[1]
  else
    ans = 
      args_ty: args[0]
      ret_ty: args[1]
      fn: args[2]
  if ans.fn.length != ans.args_ty.length
    throw new TypeAssertionError("function of #{ans.args_ty.length} arguments for TypedFun", ans.fn.length)
  return ans

F = () ->
  {args_ty, ret_ty, fn} = TypedFunArgs.apply(this, arguments)
  wrapper = () ->
    # TODO: improve error message from the following assertion
    T(arrOfMulti(args_ty))(Array.prototype.slice.call(arguments))
    return T(ret_ty)(fn.apply(this, arguments))
  wrapper.__proto__ = TypedFun.prototype
  wrapper.constructor = TypedFun
  wrapper.__funType__ = funOf(args_ty, ret_ty)
  nativeAssert(_.isFunction(wrapper) and wrapper instanceof Function and wrapper instanceof TypedFun)
  return wrapper
# CPS versions of TypedFun
cpsWrapperCallback = (ret_ty, kont) ->
  (err, ans) ->
    if err? then return kont(err)
    try T(ret_ty)(ans)
    catch tyErr
      return kont(tyErr)
    return kont(err, ans)
F_ = (args_ty, ret_ty, fn) -> # continuation is last argument
  {args_ty, ret_ty, fn} = TypedFunArgs.apply(this, arguments)
  if args_ty.length < 1 or not /fun.*/.test(args_ty[args_ty.length-1].typeName)
    throw new TypeAssertionError("function type (fun.of(...)) as last argument in signature provided to TypedFun_", args_ty)
  wrapper = () ->
    wrapper_args = Array.prototype.slice.call(arguments)
    # TODO: improve error message from the following assertion
    T(arrOfMulti(args_ty))(wrapper_args)
    wrapper_args.push(cpsWrapperCallback(ret_ty, wrapper_args.pop()))
    return fn.apply(this, wrapper_args)
  wrapper.__proto__ = TypedFun.prototype
  wrapper.constructor = TypedFun
  wrapper.__funType__ = funOf(args_ty, ret_ty)
  nativeAssert(_.isFunction(wrapper) and wrapper instanceof Function and wrapper instanceof TypedFun)
  return wrapper
_F = (args_ty, ret_ty, fn) -> # continuation is first argument
  {args_ty, ret_ty, fn} = TypedFunArgs.apply(this, arguments)
  if args_ty.length < 1 or not /fun.*/.test(args_ty[0].typeName)
    throw new TypeAssertionError("function type (fun.of(...)) as first argument in signature provided to TypedFun_", args_ty)
  wrapper = () ->
    wrapper_args = Array.prototype.slice.call(arguments)
    # TODO: improve error message from the following assertion
    T(arrOfMulti(args_ty))(wrapper_args)
    wrapper_args.unshift(cpsWrapperCallback(ret_ty, wrapper_args.shift()))
    return fn.apply(this, wrapper_args)
  wrapper.__proto__ = TypedFun.prototype
  wrapper.constructor = TypedFun
  wrapper.__funType__ = funOf(args_ty, ret_ty)
  nativeAssert(_.isFunction(wrapper) and wrapper instanceof Function and wrapper instanceof TypedFun)
  return wrapper

nameType = F [s.type], s.str.ne, (ty) -> ty.typeName

describeType = F [s.type], s.str.ne, (ty) -> ty.typeDesc

TypeOf = F [s.any], s.type, (x) ->
    switch typeof x
      when "function"
        if s.fun.typed x then return x.__funType__
        return s.fun
      when "object" then return s.obj
      when "boolean" then return s.bool
      when "undefined" then return s.undefined
      when "string" then return s.str
      when "number" then return s.num
      else throw Error('unrecognized result of typeof: ' + (typeof x))

###
EXPORTS
###

exportAll = () ->
  module.exports.Type = Type

  _.extend(module.exports, s)
  addCompositeTypes(module.exports, s)

  module.exports.Assert = assert
  module.exports.TypeAssertionError = TypeAssertionError
  
  module.exports.WrapFun = F
  module.exports.WrapFun_ = F_
  module.exports._WrapFun = _F

  module.exports.TypeOf = TypeOf  
  module.exports.Name = nameType
  module.exports.Describe = describeType

exportAll()

