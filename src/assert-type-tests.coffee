expect = require 'expect.js'
ty = require './assert-type'
_ = require 'underscore'
util = require 'util'

describe 'simple types', () ->
  simpleTest = (tc, pos, neg) ->
    pos.forEach (x) ->
      try expect(tc(x)).to.be(true)
      catch err
        err.message = "#{x} failed but should have passed"
        throw err
    neg.forEach (x) ->
      try expect(tc(x)).to.be(false)
      catch err
        err.message = "#{x} passed but should have failed"
        throw err

  it '- bool', () ->
    simpleTest ty.bool, [true, false], [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)]
  it '- num', () ->
    simpleTest ty.num, [NaN, 0, 12345, 3.14, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY], [undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.not.nan', () ->
    simpleTest ty.num.not.nan, [0, 12345, 3.14, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY], [NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.pos', () ->
    simpleTest ty.num.pos, [1, 1.1, Number.POSITIVE_INFINITY], [0, -1, Number.NEGATIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.neg', () ->
    simpleTest ty.num.neg, [-1, -1.1, Number.NEGATIVE_INFINITY], [0, 1, Number.POSITIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.nonneg', () ->
    simpleTest ty.num.nonneg, [0, 1, 0.1, Number.POSITIVE_INFINITY], [-1, Number.NEGATIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.finite', () ->
    simpleTest ty.num.finite, [-1, 0, 12345, 3.14], [NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.finite.pos', () ->
    simpleTest ty.num.finite.pos, [1, 1.1], [0, -1, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.finite.neg', () ->
    simpleTest ty.num.finite.neg, [-1, -1.1], [0, 1, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- num.finite.nonneg', () ->
    simpleTest ty.num.finite.nonneg, [0, 1, 0.1], [-1, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, NaN, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- int.pos', () ->
    simpleTest ty.int.pos, [1, 12345], [0, -1, -2.71, 3.14, NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- int.neg', () ->
    simpleTest ty.int.neg, [-1, -12345], [0, 1, -2.71, 3.14, NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- int.nonneg', () ->
    simpleTest ty.int.nonneg, [0, 1, 12345], [-1, -2.71, 3.14, NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, undefined, null, {}, [], true, false, '', 'foo', (() -> 0)]
  it '- str', () ->
    simpleTest ty.str, ['', 'foo'], [undefined, null, {}, [], true, false, NaN, 0, 12345, 3.14, (() -> 0)]
  it '- str.ne', () ->
    simpleTest ty.str.ne, ['foo'], ['', false, undefined, null, {}, [], true, false, NaN, 0, 12345, 3.14, (() -> 0)]
  it '- arr', () ->
    simpleTest ty.arr, [[], [0], [0,1]], [undefined, null, {}, true, false, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- arr.ne', () ->
    simpleTest ty.arr.ne, [[0], [0,1]], [[], undefined, null, {}, true, false, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- obj', () ->
    simpleTest ty.obj, [null, {}, []], [false, undefined, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- obj.not.null', () ->
    simpleTest ty.obj.not.null, [{}, []], [null, false, undefined, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- null', () ->
    simpleTest ty.null, [null], [{}, [], false, undefined, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- undefined', () ->
    simpleTest ty.undefined, [undefined], [{}, [], false, null, NaN, 0, -1, 3.14, '', 'foo', (() -> 0)]
  it '- fun', () ->
    simpleTest ty.fun, [() -> 0], [{}, [], false, undefined, null, NaN, 0, -1, 3.14, '', 'foo']
  it '- any', () ->
    simpleTest ty.any, [undefined, null, {}, [], true, false, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)], []

describe 'Assert', () ->
  describe 'single', () ->
    it 'positive', () ->
      expect(ty.Assert(ty.bool)(true)).to.be(true)
      expect(ty.Assert(ty.bool)(false)).to.be(false)
      expect(ty.Assert(ty.any)(undefined)).to.be(undefined)
      expect(ty.Assert(ty.any)(null)).to.be(null)
    it 'negative', () ->
      [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
        expect(() -> ty.Assert(ty.bool(x))).to.throwError()
    it 'wrong', () ->
      [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
        expect(() -> ty.Assert(x)).to.throwError()
  describe 'multi', () ->
    it 'positive', () ->
      expect(ty.Assert(ty.bool, ty.int)(true, 0)).to.eql([true, 0])
    it 'negative', () ->
      expect(() -> ty.Assert(ty.bool, ty.int)(true, false)).to.throwError()
    it 'wrong', () ->
      expect(() -> ty.Assert()).to.throwError()
      [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
        expect(() -> ty.Assert(ty.bool, x)).to.throwError()
        expect(() -> ty.Assert(x, ty.bool)).to.throwError()
  it 'error type & message', () ->
    try
      ty.Assert(ty.bool)(0)
      expect().fail()
    catch err
      expect(err instanceof ty.TypeAssertionError).to.be(true)
      expect(err.toString()).to.be("TypeAssertionError: expected boolean")
      expect(err.message).to.be("expected boolean")
      expect(err.expected).to.be("boolean")
      expect(err.actual).to.be(0)

describe "'or'", () ->
  it 'positive', () ->
    expect(ty.or(ty.bool, ty.num)(true)).to.be(true)
    expect(ty.or(ty.bool, ty.num)(0)).to.be(true)
  it 'negative', () ->
    [undefined, null, {}, '', 'foo', (() -> 0)].forEach (x) ->
      expect(ty.or(ty.bool, ty.num)(x)).to.be(false)
  it 'wrong', () ->
    expect(() -> ty.or()).to.throwError()
    [undefined, null, {}, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(() -> ty.or(x)).to.throwError()
      expect(() -> ty.or(ty.int, x)).to.throwError()

describe 'funN', () ->
  it 'positive', () ->
    expect(ty.funN(0)(() -> 0)).to.be(true)
    expect(ty.funN(2)((x, y) -> x)).to.be(true)
  it 'negative', () ->
    expect(ty.funN(0)((x) -> x)).to.be(false)
    expect(ty.funN(1)(() -> 0)).to.be(false)
    expect(ty.funN(2)((x) -> x)).to.be(false)
    [undefined, null, {}, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(ty.funN(1)(x)).to.be(false)
  it 'wrong', () ->
    expect(() -> ty.funN()).to.throwError()
    [undefined, null, {}, NaN, -1, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(() -> ty.funN(x)).to.throwError()

describe 'arr.of', () ->
  describe 'one type', () ->
    it 'positive', () ->
      expect(ty.arr.of(ty.bool)([])).to.be(true)
      expect(ty.arr.of(ty.bool)([true])).to.be(true)
      expect(ty.arr.of(ty.bool)([true, false])).to.be(true)
    it 'negative', () ->
      expect(ty.arr.of(ty.bool)([0])).to.be(false)
      expect(ty.arr.of(ty.bool)([0, true])).to.be(false)
      expect(ty.arr.of(ty.bool)([true, false, 0])).to.be(false)
    it 'wrong', () ->
      [undefined, null, {}, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
        expect(() -> ty.arr.of(x)).to.throwError()
  describe 'array of types', () ->
    it 'positive', () ->
      expect(ty.arr.of([])([])).to.be(true)
      expect(ty.arr.of([ty.bool])([true])).to.be(true)
      expect(ty.arr.of([ty.bool, ty.int])([true, 0])).to.be(true)
    it 'negative', () ->
      expect(ty.arr.of([])([true])).to.be(false)
      expect(ty.arr.of([ty.bool])([])).to.be(false)
      expect(ty.arr.of([ty.bool])([0])).to.be(false)
      expect(ty.arr.of([ty.bool])([0, 0])).to.be(false)
      expect(ty.arr.of([ty.bool, ty.int])([0])).to.be(false)
      expect(ty.arr.of([ty.bool, ty.int])([0, 0])).to.be(false)
      expect(ty.arr.of([ty.bool, ty.int])([0, 0])).to.be(false)
      [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
        expect(ty.arr.of([ty.bool, ty.int])(x)).to.be(false)

describe 'arr.ne.of', () ->
  it 'positive', () ->
    expect(ty.arr.ne.of(ty.bool)([true])).to.be(true)
    expect(ty.arr.ne.of(ty.bool)([true, false])).to.be(true)
  it 'negative', () ->
    expect(ty.arr.ne.of(ty.bool)([])).to.be(false)
    expect(ty.arr.ne.of(ty.bool)([0])).to.be(false)
    expect(ty.arr.ne.of(ty.bool)([0, true])).to.be(false)
    expect(ty.arr.ne.of(ty.bool)([true, false, 0])).to.be(false)
  it 'wrong', () ->
    [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(() -> ty.arr.ne.of(x)).to.throwError()

describe 'obj.of', () ->
  it 'positive', () ->
    expect(ty.obj.of({})({})).to.be(true)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: true, y: 0})).to.be(true)
  it 'negative', () ->
    expect(ty.obj.of({})({x: true})).to.be(false)
    expect(ty.obj.of({x: ty.bool})({})).to.be(false)
    expect(ty.obj.of({x: ty.bool})({x: 0})).to.be(false)
    expect(ty.obj.of({x: ty.bool})({x: true, y: 0})).to.be(false)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: true})).to.be(false)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: 0, y: 0})).to.be(false)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: true, y: false})).to.be(false)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: 0, y: false})).to.be(false)
    expect(ty.obj.of({x: ty.bool, y: ty.int})({x: true, z: 0})).to.be(false)
  it 'wrong', () ->
    [undefined, null, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(() -> ty.obj.of(x)).to.throwError()

describe 'obj.with', () ->
  it 'positive', () ->
    expect(ty.obj.with({})({})).to.be(true)
    expect(ty.obj.with({})({x: true})).to.be(true)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: true, y: 0})).to.be(true)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: true, y: 0, z: null})).to.be(true)
  it 'negative', () ->
    expect(ty.obj.with({x: ty.bool})({})).to.be(false)
    expect(ty.obj.with({x: ty.bool})({x: 0})).to.be(false)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: true})).to.be(false)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: 0, y: 0})).to.be(false)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: true, y: false})).to.be(false)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: 0, y: false})).to.be(false)
    expect(ty.obj.with({x: ty.bool, y: ty.int})({x: true, z: 0})).to.be(false)
  it 'wrong', () ->
    [undefined, null, NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      expect(() -> ty.obj.with(x)).to.throwError()

describe 'WrapFun', () ->
  F = ty.WrapFun
  it 'positive', () ->
    expect(F([], ty.int, (() -> 0))()).to.be(0)
    expect(F([ty.bool], ty.int, ((x) -> 0))(true)).to.be(0)
    expect(F([ty.bool], ty.int, ((x) -> 0))(false)).to.be(0)
    expect(F([ty.bool, ty.num], ty.arr, ((x, y) -> [x,y]))(true, 0)).to.eql([true, 0])

    expect(F(ty.fun.of([], ty.int), (() -> 0))()).to.be(0)
    expect(F(ty.fun.of([ty.bool], ty.int), ((x) -> 0))(true)).to.be(0)
    expect(F(ty.fun.of([ty.bool], ty.int), ((x) -> 0))(false)).to.be(0)
    expect(F(ty.fun.of([ty.bool, ty.num], ty.arr), ((x, y) -> [x,y]))(true, 0)).to.eql([true, 0])
  it 'negative', () ->
    expect(() -> F([], ty.int, (() -> true)())).to.throwError()
    expect(() -> F([], ty.int, (() -> true)(null))).to.throwError()
    expect(() -> F([ty.bool], ty.int, ((x) -> 0))()).to.throwError()
    expect(() -> F([ty.bool], ty.int, ((x) -> 0))(true, null)).to.throwError()
    expect(() -> F([ty.bool], ty.int, ((x) -> 0))(null)).to.throwError()
    expect(() -> F([ty.bool], ty.int, ((x) -> null))(true)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x) -> 0))).to.throwError()

    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(true)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(0)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(true, null)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(null, 0)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(null, null)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> null))(true, 0)).to.throwError()
    expect(() -> F([ty.bool, ty.num], ty.int, ((x, y) -> 0))(true, 0, 1)).to.throwError()

    expect(() -> F(ty.fun.of([ty.bool], ty.int), ((x) -> 0))()).to.throwError()
    expect(() -> F(ty.fun.of([ty.bool], ty.int), ((x) -> 0))(null)).to.throwError()
  it 'wrong', () ->
    [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      if not _.isArray(x) then expect(() -> F(x, ty.int, ((x) -> 0))).to.throwError()
      expect(() -> F([], x, ((x) -> 0))).to.throwError()
      expect(() -> F([ty.defined], ty.int, x)()).to.throwError()
    expect(() -> F(ty.int, ((x) -> 0))).to.throwError()

describe 'fun.of', () ->
  F = ty.WrapFun
  it 'positive', () ->
    expect(ty.fun.of([], ty.int)(F([], ty.int, (() -> 0)))).to.be(true)
    expect(ty.fun.of([ty.bool], ty.int)(F([ty.bool], ty.int, ((x) -> 0)))).to.be(true)
  it 'negative', () ->
    expect(ty.fun.of([], ty.int)(F([ty.bool], ty.int, ((b) -> 0)))).to.be(false)
    expect(ty.fun.of([ty.bool], ty.int)(F([], ty.int, (() -> 0)))).to.be(false)
    expect(ty.fun.of([], ty.int)(F([], ty.bool, (() -> false)))).to.be(false)
  it 'wrong', () ->
    [undefined, null, {}, [], NaN, 0, 12345, 3.14, '', 'foo', (() -> 0)].forEach (x) ->
      if not _.isArray(x) then expect(() -> ty.fun.of(x, ty.int)).to.throwError()
      expect(() -> ty.fun.of([], x)).to.throwError()
    expect(() -> ty.fun.of(ty.int, ty.bool)).to.throwError()
  describe 'fixed-point combinator', () ->
    it '(weakly typed)', () ->
      hZ = ((y) -> ((f) -> ((x) -> f(y(y)(f), x))))
      Z = F([ty.fun], ty.fun, hZ(hZ))
      Z((rec, x) -> if x < 10 then return rec(x+1) else return x)(0)
    it '(strongly typed)', () ->
      ftO = ty.fun.of([ty.any], ty.any)
      ftI = ty.fun.of([ftO, ty.any], ty.any)
      ft1 = ty.fun.of([ftI], ftO)
      ft2 = ty.fun.of([ty.fun], ft1)
      hZ = F(ft2, ((y) -> F(ft1, ((f) -> F(ftO, ((x) -> f(y(y)(f), x)))))))
      Z = hZ(hZ)
      Z(F([ftO, ty.any], ty.any, ((rec, x) -> if x < 10 then return rec(x+1) else return x)))(0)

describe 'WrapFun_', (masterkont) ->
  F_ = ty.WrapFun_

  it 'positive 1', (kont) ->
    (F_([ty.fun], ty.int, ((k) -> k(null, 0)))) (err, ans) ->
      expect(err?).to.be(false)
      expect(ans).to.be(0)
      kont()
  it 'positive 2', (kont) ->
    x = 314159
    (F_([ty.int, ty.fun], ty.int, ((x, k) -> k(null, x)))) x, (err, ans) ->
      expect(err?).to.be(false)
      expect(ans).to.be(x)
      kont()
  it 'exception', (kont) ->
    (F_([ty.fun], ty.int, ((k) -> k(new Error('foo'))))) (err, ans) ->
      expect(err?).to.be.ok()
      expect(err.message).to.be('foo')
      kont()
  it 'negative', (kont) ->
    expect(() -> F_([ty.fun], ty.int, ((k) -> k(null, 0)))(0)).to.throwError()
    expect( () -> F_([ty.bool, ty.fun], ty.int, ((k) -> k(null, 0)))(0, ((err, ans) -> 0))).to.throwError()
    (F_([ty.fun], ty.int, ((k) -> k(null, true)))) (err, ans) ->
      expect(err?).to.be(true)
      kont()

describe '_WrapFun', (masterkont) ->
  _F = ty._WrapFun

  it 'positive 1', (kont) ->
    (_F([ty.fun], ty.int, ((k) -> k(null, 0)))) (err, ans) ->
      expect(err?).to.be(false)
      expect(ans).to.be(0)
      kont()
  it 'positive 2', (kont) ->
    x = 314159
    kont2 = (err, ans) ->
      expect(err?).to.be(false)
      expect(ans).to.be(x)
      kont()
    (_F([ty.fun, ty.int], ty.int, ((k, x) -> k(null, x))))(kont2, x)
  it 'exception', (kont) ->
    (_F([ty.fun], ty.int, ((k) -> k(new Error('foo'))))) (err, ans) ->
      expect(err?).to.be.ok()
      expect(err.message).to.be('foo')
      kont()
  it 'negative', (kont) ->
    expect(() -> _F([ty.fun], ty.int, ((k) -> k(null, 0)))(0)).to.throwError()
    expect(() -> _F([ty.fun, ty.bool], ty.int, ((k) -> k(null, 0)))(((err, ans) -> 0), 0)).to.throwError()
    (_F([ty.fun], ty.int, ((k) -> k(null, true)))) (err, ans) ->
      expect(err?).to.be(true)
      kont()
