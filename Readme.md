# node-assert-type

```
npm install assert-type
```

One occasionally needs to design some JavaScript code conservatively, favoring
correctness and safety over the language's natural strengths of flexibility
and agility. Given JavaScript's dynamic typing, extensive runtime type
assertions are a common product of such a [conservative
mindset](https://plus.google.com/110981030061712822816/posts/KaSKeg4vQtz).
This node.js library makes it easier to write such assertions concisely. In
addition to simple *identifier*-is-a-*type* assertions, it provides ways to
algebraically compose those into more complex assertions about objects,
arrays, and function signatures. A few examples may help illustrate:

```
var ty = require("assert-type");
var T = ty.Assert;

function deorbitBurn(power,seconds) {
  T(ty.num.finite)(power);   // assert power is a finite number (not NaN)
  T(ty.int.nonneg)(seconds); // assert seconds is a nonnegative integer

  // a more concise way to make the same two assertions:
  T(ty.num.finite, ty.int.nonneg)(power, seconds);

  ...
}

function chooseTargetToBomb(targets) {
  // assert targets is a nonempty array of nonempty strings
  T(ty.arr.ne.of(ty.str.ne))(targets);

  ...

  return T(ty.str.ne)(result); // assert we're returning a nonempty string
}

function getTRexFenceVoltage(fence) {
  // assert that fence is an object with exactly two keys: sector, a nonempty
  // string, and subsector, a non-negative integer.
  T(ty.obj.of({sector: ty.str.ne, subsector: ty.int.nonneg}))(fence);

  ...

  return T(ty.num.finite)(voltage); // assert we're returning a finite number
}

// Declare a function that takes a finite number and a boolean as arguments,
// and returns a finite number (finite*bool -> finite). Runtime assertions
// will fail if any of those types do not match, or if the wrong number of
// arguments is passed.
var F = ty.WrapFun;
var moveNuclearControlRods = F([ty.num.finite, ty.bool], ty.num.finite,
  function(position, scram) {
    ...

    return coreTemperature;
  });
```

# Manual

The examples all assume the preamble

```
var ty = require("assert-type");
```

## Simple type predicates

At the foundation, the library provides simple functions that take a value and
return a boolean indicating whether the value satisfies a specific type,
essentially similar to those found in [many](http://underscorejs.org/)
[other](https://github.com/visionmedia/should.js/)
[libraries](https://github.com/mcavage/node-assert-plus). Don't worry, things
get a bit more interesting down below.

- `bool` boolean
- `num` number (includes `NaN`)
- `num.not.nan` any number but `NaN`
- `num.pos` positive real number (excludes `NaN`)
- `num.neg`
- `num.nonneg`
- `num.finite` real number `x` and `Number.NEGATIVE_INFINITY < x < Number.POSITIVE_INFINITY`
- `num.finite.pos`
- `num.finite.neg`
- `num.finite.nonneg`
- `int` integer (excludes `NaN` and infinite)
- `int.pos`
- `int.neg`
- `int.nonneg`
- `str` string
- `str.ne` nonempty string
- `arr` array
- `arr.ne` nonempty array
- `obj` object (includes null and arrays)
- `obj.not.null` non-null object (includes arrays)
- `inst.of(Cons)` test `instanceof Cons` (e.g. `Array`, `Date`, or your class)
- `fun` function
- `funN(n)` function of `n` arguments
- `null` exactly `null` (mainly for use with `or`)
- `undefined` exactly `undefined` (ditto)
- `any` always true

Clearly, the types are not mutually exclusive.

## Assert

The `Assert` function takes a type predicate and returns a function that takes
a value and asserts the value satisfies the predicate. If the assertion
succeeds, the value is also returned. This is easier to show by example:

```
var T = ty.Assert;           // since we use it often

T(ty.bool)(true);            // OK
T(ty.bool)(0);               // throws ty.TypeAssertionError

var x = T(ty.num.finite)(0); // now x === 0
T(ty.num.finite)(NaN);       // throws ty.TypeAssertionError

// OK:
T(ty.funN(1))(function (x) { return x; });
// throws ty.TypeAssertionError:
T(ty.funN(1))(function () { return 0; });
```

`Assert` also understands multiple types followed by matching values:

```
T(ty.bool, ty.int)(true, 1);   // OK
T(ty.bool, ty.int)(true, 1.1); // throws ty.TypeAssertionError
```

## Composite types

The libary provides powerful operators for composing simple types into more
complex ones.

### or

`or(ty1, ty2, ...)` returns a type predicate satisfied if any of the provided
predicates are satisfied:

```
T(ty.or(ty.int, ty.bool))(3);    // OK
T(ty.or(ty.int, ty.bool))(true); // OK
T(ty.or(ty.int, ty.bool))("");   // throws ty.TypeAssertionError
```

### arr.of and arr.ne.of

`arr.of(somety)` returns a type predicate satisfied for arrays of the given
type.

```
T(ty.arr.of(ty.int))([1, 2, 3]); // OK
T(ty.arr.of(ty.int))([]);        // vacuously OK
T(ty.arr.of(ty.int))([true]);    // throws ty.TypeAssertionError
T(ty.arr.of(ty.int))(null);      // throws ty.TypeAssertionError
```

`arr.ne.of(somety)` rejects the empty array.

An alternative usage of `arr.of` tests for an array with a specific number of
elements of specific types.

```
T(ty.arr.of([ty.int, ty.bool]))([1, true]); // OK
T(ty.arr.of([ty.int, ty.bool]))([1]);       // throws ty.TypeAssertionError
T(ty.arr.of([ty.int, ty.bool]))([1, 2]);    // throws ty.TypeAssertionError
```

### obj.of and obj.with

`obj.of(proto)`, where `proto` is an object with keys mapping to types,
returns a type predicate testing whether an object has exactly those keys
and values satisfying the respective types.

```
T(ty.obj.of({x: ty.int, y: ty.int}))({x: 1, y: 2});       // OK
T(ty.obj.of({x: ty.int, y: ty.int}))({x: 1, y: true});    // throws ty.TypeAssertionError
T(ty.obj.of({x: ty.int, y: ty.int}))({x: 1});             // throws ty.TypeAssertionError
T(ty.obj.of({x: ty.int, y: ty.int}))({x: 1, y: 2, z: 3}); // throws ty.TypeAssertionError
```

`obj.with(proto)` is similar, but permits and ignores keys in addition to
those specified in `proto`.

### Sum types

The composite types formed by the above operators can themselves be composed.
For example, here's a simple sum type (tagged union) for 2D points in either
Cartesian or polar coordinates:

```
var tCartesian = ty.obj.of({x: ty.num.finite, y: ty.num.finite});
var tPolar = ty.obj.of({r: ty.num.finite.nonneg, theta: ty.num.finite.nonneg});
var tPoint = ty.or(tCartesian, tPolar);

function distanceToOrigin(pt) {
  T(tPoint)(pt);
  if (tCartesian(pt)) {
    return Math.sqrt(pt.x*pt.x, pt.y*pt.y);
  } else if (tPolar(pt)) {
    return pt.r;
  } else {
    // should never happen
    assert(false);
  }
}
```

As this example hints, types are values that can be assigned and passed around
at runtime. But it is not currently possible to declare recursive types,
limiting the scope of supported algebraic data types. I'm thinking about this.

## Typed functions

`fun.of([ty1, ty2, ...], tyRet)` is the type of a function whose arguments
have types `ty1, ty2, ...` and which returns a value of `tyRet`.

Functions with `fun.of(...)` types can only be generated by `WrapFun`, which
wraps a given function so that type assertions about its arguments and return
value are performed automatically before and after calling it.

```
var F = ty.WrapFun;

var t = ty.fun.of([ty.int, ty.bool], ty.int);
var intFn = F(t, function(x, b) {
                if (b) return 0-x; else return x;
            });
intFn(3, false); // returns 3
intFn(3, true);  // returns -3
intFn(3, "");    // throws ty.TypeAssertionError
intFn(3);        // throws ty.TypeAssertionError

// throws ty.TypeAssertionError due to wrong return value type:
F(t, function(x, b) { return true; })(3, false);

// OK:
T(t)(intFn);
// throws TypeAssertionError, since intFn has a different return type:
T(ty.fun.of([ty.int, ty.bool], ty.bool))(intFn);
```

`intFn` could have been declared with the following shorter syntax, in which
the use of `ty.fun.of` is implicit:

```
var intFn = F([ty.int, ty.bool], ty.int, function(x, b) {
              if (b) return 0-x; else return x;
            });
```

There's also a simple predicate `fun.typed` to check whether a given function
was generated by `WrapFun`. Any JavaScript function will satisfy `fun`, any
function generated by `WrapFun` will satisfy `fun.typed`, and only functions
generated by `WrapFun` with the _exact_ same signature will satisfy
`fun.of(...)`.

## Typed functions with callbacks

There are a few ways to use `WrapFun` with functions that return values
through callbacks (continuation passing style). First, if you're writing the
callback, you can guard the callback itself:

```
var F = ty.WrapFun;
var fs = require("fs");

fs.readFile("file.txt", "utf-8",
  F([ty.any, ty.str], ty.any, function(err, txt) {
    ...
  }));
```

One could further refine the signature of the callback to something like
`ty.fun.of([ty.or(ty.undefined, ty.null, ty.inst.of(Error)), ty.str],
ty.undefined)`. In either case, a type mismatch of the return value would
result in a thrown `ty.TypeAssertionError`.

Second, for writing a CPS function, there's a `WrapFun_` variant for the
node.js asynchronous calling convention, where the callback is of the form
`function (error, result) { ... }`.

```
var F_ = ty.WrapFun_;

var intFn_ = F_([ty.int, ty.bool, ty.fun], ty.int, function (x, b, cb) {
                if (b) return cb(0-x); else return cb(x);
              });

intFn_(3, false, function(error, result) {
  // result === 3
});
intFn_(3, true, function(error, result) {
  // result === -3
});
intFn_(3, "", function(error, result) {}); // throws ty.TypeAssertionError

F_([ty.fun], ty.int, function(cb) { return cb(true); })(function (error, result) {
  // error is a ty.TypeAssertionError
});
```

`WrapFun_` uses the return type to constrain the second argument to the
callback, and ignores the actual JavaScript return value of the function. Note
that the callback must still be represented explicitly as the last argument to
the function. As above, the type of the callback could be specified more
precisely, but this would require the callback to also be generated by
`WrapFun`.

If a type assertion fails on the arguments, a regular JavaScript exception is
thrown, since one can't be sure the callback is even present in this case. If
the type assertion fails on the return value, the resulting error is passed to
the callback.

There's also `_WrapFun` for functions that take the callback as the first
argument rather than the last (useful for
[streamline.js](https://github.com/Sage/streamlinejs) code).

Third and lastly, to write CPS functions not following the typical calling
convention, one can simply use the pass-through property of `Assert` to guard
the return value. For example, a function whose callback only accepts the
return value:

```
var d = F([ty.num.finite, ty.num.finite, ty.fun], ty.any, function(x, y, cb) {
  return cb(T(ty.num.finite)(Math.sqrt(x*x + y*y)));
});
```

## Type introspection

The TypeOf, Name, and Describe functions make it possible to identify types at
runtime. (I'm still thinking through these features, so they may evolve
significantly.)

```
ty.Name(ty.TypeOf(0)));              // => 'num'
ty.Name(ty.TypeOf(ty.Name));         // => 'fun.of([type], str.ne)'
ty.Describe(ty.TypeOf(ty.Describe)); // => '(type) -> nonempty string'

var myty = ty.fun.of([ty.arr.of(ty.int), ty.str.ne], ty.bool);

ty.Name(myty);                       // => 'fun.of([arr.of(int), str.ne], bool)'
ty.Describe(myty);                   // => '(integer array, nonempty string) -> boolean'
```

# Wish list

- Optional function arguments and object fields
- Variadic functions and arrays
- Recursive types --> ADTs
- Polymorphic functions and type variables
- Flesh out obj.with as a module signature
