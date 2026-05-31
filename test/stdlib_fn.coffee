# ─────────────────────────────────────────────────────────────────────────────
# STDLIB FONCTIONNELLE — kawa/fn
# ─────────────────────────────────────────────────────────────────────────────

{compose, pipe, identity, always, flip, curry, partial, memoize,
 tap, complement, once, juxt, converge} = require '../src/stdlib/fn'

test "identity — returns its argument unchanged", ->
  eq identity(42), 42
  eq identity("hello"), "hello"
  obj = {a: 1}
  eq identity(obj), obj

test "always — returns a function that always returns the given value", ->
  alwaysFive = always(5)
  eq alwaysFive(), 5
  eq alwaysFive(1, 2, 3), 5

test "compose — right-to-left function composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = compose inc, double
  eq transform(5), 11

test "compose — multiple functions", ->
  a = (x) -> x + 1
  b = (x) -> x * 2
  c = (x) -> x - 3
  eq compose(c, b, a)(4), 7

test "pipe — left-to-right function composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = pipe double, inc
  eq transform(5), 11

test "flip — swaps first two arguments", ->
  sub = (a, b) -> a - b
  flippedSub = flip sub
  eq flippedSub(3, 10), 7

test "curry — transforms function into curried form", ->
  add = curry (a, b) -> a + b
  add5 = add 5
  eq add5(3), 8
  eq add(2)(3), 5

test "curry — arity 3", ->
  clamp = curry (lo, hi, x) -> Math.min hi, Math.max lo, x
  clamp0to10 = clamp 0, 10
  eq clamp0to10(5),   5
  eq clamp0to10(-1),  0
  eq clamp0to10(15), 10

test "partial — partially applies arguments", ->
  add = (a, b, c) -> a + b + c
  add1and2 = partial add, 1, 2
  eq add1and2(3), 6

test "memoize — caches by composite key (multiple args)", ->
  callCount = 0
  add = memoize (a, b) ->
    callCount += 1
    a + b
  eq add(2, 3), 5
  eq add(2, 3), 5
  eq callCount, 1
  eq add(2, 4), 6
  eq callCount, 2

test "memoize — custom keyFn", ->
  callCount = 0
  fn = memoize ((x) -> callCount += 1; x * 2), ([x]) -> x
  eq fn(5), 10
  eq fn(5), 10
  eq callCount, 1

test "tap — returns value unchanged, runs side effect", ->
  seen = null
  result = tap((x) -> seen = x)(42)
  eq result, 42
  eq seen, 42

test "complement — inverts a predicate", ->
  isEven = (n) -> n % 2 is 0
  isOdd  = complement isEven
  eq isOdd(3), yes
  eq isOdd(4), no

test "once — executes function only once", ->
  callCount = 0
  fn = once -> callCount += 1; 'done'
  eq fn(), 'done'
  eq fn(), 'done'
  eq callCount, 1

test "juxt — applies multiple functions to same input", ->
  result = juxt(Math.min, Math.max)(3, 1, 4, 1, 5)
  arrayEq result, [1, 5]

test "converge — combines results of multiple functions", ->
  avg = converge(
    ((a, b) -> (a + b) / 2),
    Math.min,
    Math.max
  )
  eq avg(4, 2, 10), 6
