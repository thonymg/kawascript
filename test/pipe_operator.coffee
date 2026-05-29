# Pipe Operator `|>`
# -------------------
#
# Tests for the `|>` pipe operator (Phase 1).
# Semantics: `a |> f b, c` compiles to `f(a, b, c)` — data-first, like Elixir/Gleam.
#
# Features tested:
#   - Pipe to identifier          : `a |> f`         → `f(a)`
#   - Pipe with extra args        : `a |> f b, c`     → `f(a, b, c)`
#   - Chained pipes               : `a |> f |> g`     → `g(f(a))`
#   - Left-associativity          : `a |> f |> g`     ≡ `(a |> f) |> g`
#   - Pipe to method reference    : `a |> obj.method` → `obj.method(a)`
#   - Pipe to inline lambda       : `a |> (x) -> ...` → `((x) -> ...)(a)`
#   - Multiline — leading `|>`    : continuation when `|>` starts a line
#   - Multiline — trailing `|>`   : continuation when `|>` ends a line
#   - Precedence vs arithmetic    : `a + b |> f`      ≡ `f(a + b)`
#   - Precedence vs `||`          : `a || b |> f`     ≡ `f(a || b)`
#   - Precedence vs `=`           : `x = a |> f`      ≡ `x = f(a)`
#   - Pipe as return value        : implicit return from function body
#   - Compiled JS structure       : via eqJS
#   - Integration with immutability (Object.freeze on literal objects)
#   - Integration with match expression

# ─────────────────────────────────────────────────────────────────────────────
# 1. PIPE TO IDENTIFIER
# ─────────────────────────────────────────────────────────────────────────────

test "pipe to simple identifier", ->
  double = (x) -> x * 2
  eq (5 |> double), 10

test "pipe to identifier — compiles to function call", ->
  eqJS """
    double = (x) -> x * 2
    result = 5 |> double
  """, """
    const double = function(x) {
      return x * 2;
    };
    const result = double(5);
  """

test "pipe with a zero-arg value — identity function", ->
  identity = (x) -> x
  eq (42 |> identity), 42

# ─────────────────────────────────────────────────────────────────────────────
# 2. PIPE WITH EXTRA ARGUMENTS
# ─────────────────────────────────────────────────────────────────────────────

test "pipe with one extra arg", ->
  add = (x, n) -> x + n
  eq (5 |> add 3), 8

test "pipe with two extra args", ->
  clamp = (x, lo, hi) -> Math.min Math.max(x, lo), hi
  eq (10 |> clamp 0, 7), 7
  eq (-3 |> clamp 0, 7), 0
  eq (4  |> clamp 0, 7), 4

test "pipe with extra args — compiles to call with piped value first", ->
  eqJS """
    add = (x, n) -> x + n
    result = 5 |> add 3
  """, """
    const add = function(x, n) {
      return x + n;
    };
    const result = add(5, 3);
  """

test "pipe with array and predicate", ->
  myFilter = (arr, fn) -> arr.filter fn
  result = [1, 2, 3, 4, 5] |> myFilter (x) -> x > 2
  arrayEq result, [3, 4, 5]

test "pipe with array, predicate and transform", ->
  myFilter = (arr, fn)  -> arr.filter fn
  myMap    = (arr, fn)  -> arr.map fn
  result = [1, 2, 3, 4, 5]
    |> myFilter (x) -> x > 2
    |> myMap    (x) -> x * 2
  arrayEq result, [6, 8, 10]

test "pipe with reduce", ->
  myFilter = (arr, fn)       -> arr.filter fn
  myMap    = (arr, fn)       -> arr.map fn
  myReduce = (arr, init, fn) -> arr.reduce fn, init
  result = [1, 2, 3, 4, 5]
    |> myFilter (x) -> x > 2
    |> myMap    (x) -> x * 2
    |> myReduce 0, (acc, x) -> acc + x
  eq result, 24

# ─────────────────────────────────────────────────────────────────────────────
# 3. CHAINED PIPES — left-associativity
# ─────────────────────────────────────────────────────────────────────────────

test "two chained pipes", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double |> inc), 11

test "three chained pipes", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  negate = (x) -> -x
  eq (5 |> double |> inc |> negate), -11

test "pipe is left-associative — `a |> f |> g` equals `g(f(a))`", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double |> inc), inc(double(5))

test "chained pipes — compiles to nested calls", ->
  eqJS """
    inc    = (x) -> x + 1
    double = (x) -> x * 2
    result = 5 |> inc |> double
  """, """
    const inc = function(x) {
      return x + 1;
    };
    const double = function(x) {
      return x * 2;
    };
    const result = double(inc(5));
  """

# ─────────────────────────────────────────────────────────────────────────────
# 4. PIPE TO METHOD REFERENCE
# ─────────────────────────────────────────────────────────────────────────────

test "pipe to method reference", ->
  eq ([1, 2, 3] |> JSON.stringify), '[1,2,3]'

test "pipe to chained method reference", ->
  result = "hello world" |> String.prototype.toUpperCase.call
  # The call goes through properly as toUpperCase.call("hello world")
  eq result, "HELLO WORLD"

test "pipe to method reference — compiles correctly", ->
  eqJS """
    result = input |> JSON.stringify
  """, """
    const result = JSON.stringify(input);
  """

# ─────────────────────────────────────────────────────────────────────────────
# 5. PIPE TO INLINE LAMBDA
# ─────────────────────────────────────────────────────────────────────────────

test "pipe to inline lambda", ->
  eq (5 |> (x) -> x * x), 25

test "chained pipes to inline lambdas", ->
  result = 5
    |> (x) -> x * 2
    |> (x) -> x + 1
  eq result, 11

test "pipe to inline lambda — compiles to IIFE", ->
  eqJS """
    result = 5 |> (x) -> x * x
  """, """
    const result = (function(x) {
      return x * x;
    })(5);
  """

# ─────────────────────────────────────────────────────────────────────────────
# 6. MULTILINE PIPES
# ─────────────────────────────────────────────────────────────────────────────

test "multiline pipe — leading |> (continuation)", ->
  inc    = (x) -> x + 1
  double = (x) -> x * 2
  result =
    5
    |> inc
    |> double
  eq result, 12

test "multiline pipe — trailing |> (continuation)", ->
  inc    = (x) -> x + 1
  double = (x) -> x * 2
  result = 5 |>
    inc |>
    double
  eq result, 12

test "multiline pipe with indented leading |>", ->
  inc    = (x) -> x + 1
  double = (x) -> x * 2
  triple = (x) -> x * 3
  result = 5
    |> inc
    |> double
    |> triple
  eq result, 36  # inc(5)=6, double(6)=12, triple(12)=36

test "multiline pipe with args on each step", ->
  add  = (x, n) -> x + n
  mult = (x, n) -> x * n
  result = 1
    |> add  4
    |> mult 3
  eq result, 15

# ─────────────────────────────────────────────────────────────────────────────
# 7. PRECEDENCE
# ─────────────────────────────────────────────────────────────────────────────

test "pipe has lower precedence than + — `a + b |> f` equals `f(a + b)`", ->
  inc = (x) -> x + 1
  eq (2 + 3 |> inc), 6

test "pipe has lower precedence than * — `a * b |> f` equals `f(a * b)`", ->
  half = (x) -> x / 2
  eq (3 * 4 |> half), 6

test "pipe has lower precedence than || — `a || b |> f` equals `f(a || b)`", ->
  stringify = (x) -> String x
  eq (null || 42 |> stringify), "42"

test "pipe has lower precedence than && — `a && b |> f` equals `f(a && b)`", ->
  double = (x) -> x * 2
  eq (true && 5 |> double), 10

test "assignment has lower precedence than pipe — `x = a |> f` equals `x = f(a)`", ->
  double = (x) -> x * 2
  x = 5 |> double
  eq x, 10

test "pipe as expression inside assignment — compiles correctly", ->
  eqJS """
    double = (x) -> x * 2
    x = 5 |> double
  """, """
    const double = function(x) {
      return x * 2;
    };
    const x = double(5);
  """

test "precedence vs arithmetic — compiles `a + b |> f` as `f(a + b)`", ->
  eqJS """
    inc = (x) -> x + 1
    result = a + b |> inc
  """, """
    const inc = function(x) {
      return x + 1;
    };
    const result = inc(a + b);
  """

# ─────────────────────────────────────────────────────────────────────────────
# 8. PIPE AS RETURN VALUE
# ─────────────────────────────────────────────────────────────────────────────

test "pipe result is implicitly returned from a function", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = (n) ->
    n
    |> double
    |> inc
  eq transform(5), 11

test "pipe as implicit return — compiles correctly", ->
  eqJS """
    transform = (n) ->
      n
      |> double
      |> inc
  """, """
    const transform = function(n) {
      return inc(double(n));
    };
  """

test "pipe inside a function body with extra args", ->
  process = (data) ->
    add  = (x, n) -> x + n
    mult = (x, n) -> x * n
    data
      |> add  10
      |> mult 2
  eq process(5), 30

# ─────────────────────────────────────────────────────────────────────────────
# 9. COMPILED JS STRUCTURE — full pipeline examples
# ─────────────────────────────────────────────────────────────────────────────

test "full filter/map/reduce pipeline — JS output", ->
  eqJS """
    myFilter = (arr, fn)       -> arr.filter fn
    myMap    = (arr, fn)       -> arr.map fn
    myReduce = (arr, init, fn) -> arr.reduce fn, init
    result = [1, 2, 3, 4, 5]
      |> myFilter (x) -> x > 2
      |> myMap    (x) -> x * 2
      |> myReduce 0, (acc, x) -> acc + x
  """, """
    const myFilter = function(arr, fn) {
      return arr.filter(fn);
    };
    const myMap = function(arr, fn) {
      return arr.map(fn);
    };
    const myReduce = function(arr, init, fn) {
      return arr.reduce(fn, init);
    };
    const result = myReduce(myMap(myFilter(Object.freeze([1, 2, 3, 4, 5]), function(x) {
      return x > 2;
    }), function(x) {
      return x * 2;
    }), 0, function(acc, x) {
      return acc + x;
    });
  """

test "simple identifier chain — JS output", ->
  eqJS """
    result = input |> normalize |> validate |> serialize
  """, """
    const result = serialize(validate(normalize(input)));
  """

# ─────────────────────────────────────────────────────────────────────────────
# 10. INTEGRATION — IMMUTABILITY
# ─────────────────────────────────────────────────────────────────────────────

test "array literal at pipe origin is frozen by immutability system", ->
  compiled = CoffeeScript.compile """
    result = [1, 2, 3] |> myFilter fn
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Array literal passed to pipe should be frozen"
  ok not /\bvar\b/.test(compiled), "Output must not contain 'var'"

test "pipe binds to const — no var in output", ->
  compiled = CoffeeScript.compile """
    double = (x) -> x * 2
    result = 5 |> double
  """, bare: yes
  ok not /\bvar\b/.test(compiled), "Output must not contain 'var'"
  ok /const result/.test(compiled), "result should be const"

test "object literal in pipe step lambda is frozen", ->
  compiled = CoffeeScript.compile """
    result = users
      |> myMap (u) -> {name: u.name}
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Object literal in pipe step should be frozen"

test "array literal in pipe step lambda is frozen", ->
  compiled = CoffeeScript.compile """
    result = data
      |> myMap (x) -> [x, x * 2]
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Array literal in pipe step should be frozen"

# ─────────────────────────────────────────────────────────────────────────────
# 11. INTEGRATION — PATTERN MATCHING
# ─────────────────────────────────────────────────────────────────────────────

test "pipe to a function that uses match — negative number", ->
  classify = (n) ->
    match n
      | 0           -> "zero"
      | n if n > 0  -> "positive"
      | _           -> "negative"
  result = -3 |> classify
  eq result, "negative"

test "pipe to a function that uses match — positive number", ->
  classify = (n) ->
    match n
      | 0           -> "zero"
      | n if n > 0  -> "positive"
      | _           -> "negative"
  result = 7 |> classify
  eq result, "positive"

test "pipe through match inside inline lambda", ->
  result = 0
    |> (n) ->
        match n
          | 0 -> "zero"
          | _ -> "nonzero"
  eq result, "zero"

test "chained pipe where one step uses match", ->
  sign = (n) ->
    match n
      | 0          -> 0
      | n if n > 0 -> 1
      | _          -> -1
  double = (x) -> x * 2
  eq (-5 |> sign |> double), -2
  eq ( 3 |> sign |> double),  2
  eq ( 0 |> sign |> double),  0
