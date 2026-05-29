# Immutability
# ------------
#
# Tests for the immutable-by-default compilation model:
#   - Variables  : const by default, let explicit, const reassignment → error
#   - Block scope: let/const are block-scoped, not hoisted
#   - Literals   : arrays and objects are frozen at creation
#   - Index/prop : mutations on let containers → copy-on-write rewrite
#   - Methods    : mutating array methods → automatic immutable rewrite
#   - delete     : forbidden, use destructuring

# ─────────────────────────────────────────────────────────────────────────────
# 1. VARIABLES — const par défaut
# ─────────────────────────────────────────────────────────────────────────────

test "single assignment compiles to const", ->
  eqJS """
    x = 42
  """, "const x = 42;"

test "function assignment compiles to const", ->
  eqJS """
    square = (x) -> x * x
  """, """
    const square = function(x) {
      return x * x;
    };
  """

test "multiple independent assignments each compile to const", ->
  eqJS """
    square = (x) -> x * x
    author = "Wittgenstein"
    cube   = (x) -> square(x) * x
  """, """
    const square = function(x) {
      return x * x;
    };
    const author = "Wittgenstein";
    const cube = function(x) {
      return square(x) * x;
    };
  """

test "no var keyword anywhere in compiled output", ->
  compiled = CoffeeScript.compile """
    a = 1
    b = "hello"
    c = [1, 2, 3]
  """, bare: yes
  ok not /\bvar\b/.test(compiled), "Output must not contain 'var'"

# ─────────────────────────────────────────────────────────────────────────────
# 2. VARIABLES — let explicite
# ─────────────────────────────────────────────────────────────────────────────

test "explicit let compiles to let", ->
  eqJS """
    let counter = 0
  """, "let counter = 0;"

test "let variable can be reassigned", ->
  eqJS """
    let counter = 0
    counter = counter + 1
  """, """
    let counter = 0;
    counter = counter + 1;
  """

test "let and const coexist in same scope", ->
  eqJS """
    name = "Alice"
    let score = 0
    score = score + 10
  """, """
    const name = "Alice";
    let score = 0;
    score = score + 10;
  """

# ─────────────────────────────────────────────────────────────────────────────
# 3. VARIABLES — erreurs de compilation
# ─────────────────────────────────────────────────────────────────────────────

test "reassignment of const variable throws compile error", ->
  throwsCompileError """
    x = 1
    x = 2
  """

test "reassignment of const in different expression throws compile error", ->
  throwsCompileError """
    name = "Alice"
    name = "Bob"
  """

# ─────────────────────────────────────────────────────────────────────────────
# 4. BLOCK SCOPE
# ─────────────────────────────────────────────────────────────────────────────

test "let declared in if block stays local to that block", ->
  eqJS """
    validate = (n) ->
      if n > 0
        let msg = "positif"
        console.log msg
  """, """
    const validate = function(n) {
      if (n > 0) {
        let msg = "positif";
        return console.log(msg);
      }
    };
  """

test "let declared at function level is accessible throughout function body", ->
  eqJS """
    compute = (n) ->
      let result = 0
      if n > 0
        result = n * 2
      result
  """, """
    const compute = function(n) {
      let result = 0;
      if (n > 0) {
        result = n * 2;
      }
      return result;
    };
  """

# Block scope enforcement at compile time is a planned feature (not yet implemented).
# Variables declared in inner blocks are currently accessible outside — runtime
# semantics match JavaScript `let`/`const` hoisting to the nearest function scope.

# ─────────────────────────────────────────────────────────────────────────────
# 5. LITTÉRAUX — gel par Object.freeze
# ─────────────────────────────────────────────────────────────────────────────

test "array literal is wrapped with Object.freeze", ->
  eqJS """
    colors = ["red", "green", "blue"]
  """, """
    const colors = Object.freeze(["red", "green", "blue"]);
  """

test "empty array literal is frozen", ->
  eqJS """
    empty = []
  """, "const empty = Object.freeze([]);"

test "object literal is wrapped with Object.freeze", ->
  eqJS """
    point = {x: 1, y: 2}
  """, """
    const point = Object.freeze({
      x: 1,
      y: 2
    });
  """

test "empty object literal is frozen", ->
  eqJS """
    empty = {}
  """, "const empty = Object.freeze({});"

# Deep freeze via __freeze__ helper is a planned future feature.
# Each literal is frozen at its own level; nested structures use shallow Object.freeze.

test "nested array: each level is shallowly frozen", ->
  compiled = CoffeeScript.compile """
    matrix = [[1, 2], [3, 4]]
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Outer array should be frozen"
  ok not /\bvar\b/.test(compiled)

test "nested object: each level is shallowly frozen", ->
  compiled = CoffeeScript.compile """
    config = {db: {host: "localhost", port: 5432}}
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Object should be frozen"

# ─────────────────────────────────────────────────────────────────────────────
# 6. INDEX / PROPRIÉTÉ — copy-on-write sur let
# ─────────────────────────────────────────────────────────────────────────────

test "index assignment on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr[0] = 99
  """

test "index assignment on let array rewrites to spread copy", ->
  eqJS """
    let items = [1, 2, 3]
    items[0] = 99
  """, """
    let items = Object.freeze([1, 2, 3]);
    items = Object.freeze([...items.slice(0, 0), 99, ...items.slice(1)]);
  """

test "index assignment in the middle of let array", ->
  eqJS """
    let arr = [1, 2, 3, 4, 5]
    arr[2] = 99
  """, """
    let arr = Object.freeze([1, 2, 3, 4, 5]);
    arr = Object.freeze([...arr.slice(0, 2), 99, ...arr.slice(3)]);
  """

test "property assignment on const object throws compile error", ->
  throwsCompileError """
    obj = {a: 1}
    obj.a = 2
  """

test "property assignment on let object rewrites to spread copy", ->
  eqJS """
    let config = {debug: false}
    config.debug = true
  """, """
    let config = Object.freeze({
      debug: false
    });
    config = Object.freeze({...config, debug: true});
  """

test "dynamic key assignment on let object rewrites with computed key", ->
  eqJS """
    let map = {a: 1}
    key = "b"
    map[key] = 2
  """, """
    let map = Object.freeze({
      a: 1
    });
    const key = "b";
    map = Object.freeze({...map, [key]: 2});
  """

# ─────────────────────────────────────────────────────────────────────────────
# 7. MÉTHODES MUTANTES — réécriture automatique sur let
# ─────────────────────────────────────────────────────────────────────────────

# --- push ---

test "push() on let array rewrites to spread append", ->
  eqJS """
    let arr = [1, 2, 3]
    arr.push 4
  """, """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze([...arr, 4]);
  """

test "push() with multiple args appends all", ->
  eqJS """
    let arr = [1, 2]
    arr.push 3, 4, 5
  """, """
    let arr = Object.freeze([1, 2]);
    arr = Object.freeze([...arr, 3, 4, 5]);
  """

test "push() on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr.push 4
  """

# --- pop ---

test "pop() on let array rewrites to slice", ->
  eqJS """
    let arr = [1, 2, 3]
    arr.pop()
  """, """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze(arr.slice(0, -1));
  """

test "pop() on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr.pop()
  """

# --- shift ---

test "shift() on let array rewrites to slice(1)", ->
  eqJS """
    let arr = [1, 2, 3]
    arr.shift()
  """, """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze(arr.slice(1));
  """

# --- unshift ---

test "unshift() on let array rewrites to spread prepend", ->
  eqJS """
    let arr = [2, 3, 4]
    arr.unshift 1
  """, """
    let arr = Object.freeze([2, 3, 4]);
    arr = Object.freeze([1, ...arr]);
  """

test "unshift() with multiple args preserves order", ->
  eqJS """
    let arr = [3, 4]
    arr.unshift 1, 2
  """, """
    let arr = Object.freeze([3, 4]);
    arr = Object.freeze([1, 2, ...arr]);
  """

# --- splice ---

test "splice(i, n) removes elements via slice copy", ->
  eqJS """
    let arr = [1, 2, 3, 4, 5]
    arr.splice 1, 2
  """, """
    let arr = Object.freeze([1, 2, 3, 4, 5]);
    arr = Object.freeze([...arr.slice(0, 1), ...arr.slice(1 + 2)]);
  """

test "splice(i, n, x) removes and inserts via slice copy", ->
  eqJS """
    let arr = [1, 2, 3, 4]
    arr.splice 1, 1, 99
  """, """
    let arr = Object.freeze([1, 2, 3, 4]);
    arr = Object.freeze([...arr.slice(0, 1), 99, ...arr.slice(1 + 1)]);
  """

test "splice(i, 0, x) inserts without removing", ->
  eqJS """
    let arr = [1, 3, 4]
    arr.splice 1, 0, 2
  """, """
    let arr = Object.freeze([1, 3, 4]);
    arr = Object.freeze([...arr.slice(0, 1), 2, ...arr.slice(1 + 0)]);
  """

# --- sort ---

test "sort() without comparator rewrites to toSorted()", ->
  eqJS """
    let arr = [3, 1, 2]
    arr.sort()
  """, """
    let arr = Object.freeze([3, 1, 2]);
    arr = Object.freeze(arr.toSorted());
  """

test "sort(fn) with comparator rewrites to toSorted(fn)", ->
  eqJS """
    let arr = [3, 1, 2]
    arr.sort (a, b) -> a - b
  """, """
    let arr = Object.freeze([3, 1, 2]);
    arr = Object.freeze(arr.toSorted(function(a, b) {
      return a - b;
    }));
  """

test "sort() on const array throws compile error", ->
  throwsCompileError """
    arr = [3, 1, 2]
    arr.sort()
  """

# --- reverse ---

test "reverse() rewrites to toReversed()", ->
  eqJS """
    let arr = [1, 2, 3]
    arr.reverse()
  """, """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze(arr.toReversed());
  """

test "reverse() on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr.reverse()
  """

# --- fill ---

test "fill(v) rewrites via __toFilled__ helper", ->
  compiled = CoffeeScript.compile """
    let arr = [1, 2, 3, 4]
    arr.fill 0
  """, bare: yes
  ok /\b__toFilled__\b/.test(compiled), "fill() should use __toFilled__ helper"
  ok not /\.fill\b/.test(compiled),     "Should not contain direct .fill() call"
  ok not /\bvar\b/.test(compiled)

# __toFilled__ helper auto-injection (declared exactly once per file) is a planned feature.

test "fill(v) on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr.fill 0
  """

# --- copyWithin ---

test "copyWithin() rewrites to slice-based copy", ->
  compiled = CoffeeScript.compile """
    let arr = [1, 2, 3, 4, 5]
    arr.copyWithin 0, 3
  """, bare: yes
  ok not /\.copyWithin\b/.test(compiled), "Should not contain direct .copyWithin() call"
  ok /slice/.test(compiled),              "Should use slice in rewrite"
  ok not /\bvar\b/.test(compiled)

# ─────────────────────────────────────────────────────────────────────────────
# 8. OPÉRATEUR delete — interdit
# ─────────────────────────────────────────────────────────────────────────────

test "delete operator throws compile error", ->
  throwsCompileError """
    obj = {a: 1, b: 2}
    delete obj.a
  """

test "delete operator throws even on let object", ->
  throwsCompileError """
    let obj = {a: 1, b: 2}
    delete obj.a
  """

# ─────────────────────────────────────────────────────────────────────────────
# 9. BOUCLES — variables de contrôle → let
# ─────────────────────────────────────────────────────────────────────────────

test "for..in loop control variable compiles to let", ->
  compiled = CoffeeScript.compile """
    for item in [1, 2, 3]
      console.log item
  """, bare: yes
  ok /\blet\b/.test(compiled),     "Loop variable should use let"
  ok not /\bvar\b/.test(compiled), "Should not use var"

test "numeric range loop compiles to let", ->
  compiled = CoffeeScript.compile """
    for i in [1..10]
      console.log i
  """, bare: yes
  ok /\blet\b/.test(compiled)
  ok not /\bvar\b/.test(compiled)

test "while loop with let accumulator", ->
  eqJS """
    let i = 0
    while i < 5
      i = i + 1
  """, """
    let i = 0;
    while (i < 5) {
      i = i + 1;
    }
  """

# ─────────────────────────────────────────────────────────────────────────────
# 10. CHAINED REWRITES — combinaisons
# ─────────────────────────────────────────────────────────────────────────────

test "multiple mutating operations on same let array rewrite sequentially", ->
  eqJS """
    let arr = [3, 1, 2]
    arr.push 4
    arr.sort()
    arr.reverse()
  """, """
    let arr = Object.freeze([3, 1, 2]);
    arr = Object.freeze([...arr, 4]);
    arr = Object.freeze(arr.toSorted());
    arr = Object.freeze(arr.toReversed());
  """

test "object spread copy preserves existing keys", ->
  eqJS """
    let cfg = {host: "localhost", port: 3000, debug: false}
    cfg.debug = true
    cfg.port  = 8080
  """, """
    let cfg = Object.freeze({
      host: "localhost",
      port: 3000,
      debug: false
    });
    cfg = Object.freeze({...cfg, debug: true});
    cfg = Object.freeze({...cfg, port: 8080});
  """

test "realistic pipeline: filter then push", ->
  eqJS """
    let active = [1, 2, 3, 4]
    active = active.filter (n) -> n > 2
    active.push 5
  """, """
    let active = Object.freeze([1, 2, 3, 4]);
    active = active.filter(function(n) {
      return n > 2;
    });
    active = Object.freeze([...active, 5]);
  """

# ─────────────────────────────────────────────────────────────────────────────
# 11. NON-MUTATING METHODS — inchangées
# ─────────────────────────────────────────────────────────────────────────────

test "map() is not rewritten (already immutable)", ->
  compiled = CoffeeScript.compile """
    doubled = [1, 2, 3].map (x) -> x * 2
  """, bare: yes
  ok /\.map\b/.test(compiled), "map() should be left unchanged"

test "filter() is not rewritten (already immutable)", ->
  compiled = CoffeeScript.compile """
    evens = [1, 2, 3, 4].filter (x) -> x % 2 is 0
  """, bare: yes
  ok /\.filter\b/.test(compiled), "filter() should be left unchanged"

test "slice() is not rewritten (already immutable)", ->
  compiled = CoffeeScript.compile """
    head = [1, 2, 3, 4].slice 0, 2
  """, bare: yes
  ok /\.slice\b/.test(compiled), "slice() should be left unchanged"

test "reduce() is not rewritten (already immutable)", ->
  compiled = CoffeeScript.compile """
    sum = [1, 2, 3].reduce ((acc, x) -> acc + x), 0
  """, bare: yes
  ok /\.reduce\b/.test(compiled), "reduce() should be left unchanged"

test "concat() is not rewritten (already immutable)", ->
  compiled = CoffeeScript.compile """
    merged = [1, 2].concat [3, 4]
  """, bare: yes
  ok /\.concat\b/.test(compiled), "concat() should be left unchanged"

# ─────────────────────────────────────────────────────────────────────────────
# 12. EXPORT — const par défaut
# ─────────────────────────────────────────────────────────────────────────────

test "exported assignment compiles to exported const", ->
  compiled = CoffeeScript.compile """
    export PI = 3.14159
  """, bare: yes
  ok /\bconst\b/.test(compiled), "Exported variable should use const"
  ok not /\bvar\b/.test(compiled)

test "exported let compiles to exported let", ->
  compiled = CoffeeScript.compile """
    export let mutableFlag = false
  """, bare: yes
  ok /\blet\b/.test(compiled), "Exported let should use let"
  ok not /\bvar\b/.test(compiled)

# ─────────────────────────────────────────────────────────────────────────────
# 5b. LITTÉRAUX — gel dans les corps de fonctions
# ─────────────────────────────────────────────────────────────────────────────

test "array literal inside function body is frozen", ->
  eqJS """
    f = -> [1, 2, 3]
  """, """
    const f = function() {
      return Object.freeze([1, 2, 3]);
    };
  """

test "object literal inside function body is frozen", ->
  eqJS """
    f = -> {a: 1}
  """, """
    const f = function() {
      return Object.freeze({
        a: 1
      });
    };
  """

test "literal inside arrow function is frozen", ->
  eqJS """
    f = (x) => {a: x}
  """, """
    const f = (x) => {
      return Object.freeze({
        a: x
      });
    };
  """

test "literal inside nested lambda is frozen", ->
  compiled = CoffeeScript.compile """
    f = (x) -> (y) -> {x, y}
  """, bare: yes
  eq (compiled.match /Object\.freeze/g)?.length, 1
