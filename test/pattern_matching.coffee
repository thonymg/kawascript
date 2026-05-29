# Pattern Matching
# ----------------
#
# Tests for the `match` expression (Phase 1).
# Arms are indented relative to the `match` keyword, consistent with
# CoffeeScript's indentation model (same as `switch/when`).
#
# Features tested:
#   - Literal patterns  : integers, floats, strings, booleans, null, undefined
#   - Wildcard          : `_` always matches, no binding
#   - Variable binding  : `| n ->` binds `n` as const
#   - Guards            : `| n if n < 0 ->`
#   - Or-patterns       : `| 0, 1 ->`
#   - match as expr     : `label = match x | ...`
#   - Immutability      : subject and bindings compiled as const
#   - JS structure      : if/else if chain

# ─────────────────────────────────────────────────────────────────────────────
# 1. LITERAL PATTERNS — integers
# ─────────────────────────────────────────────────────────────────────────────

test "integer literal pattern — exact match", ->
  f = (n) ->
    match n
      | 0 -> "zero"
      | 1 -> "one"
      | _ -> "other"

  eq f(0), "zero"
  eq f(1), "one"
  eq f(2), "other"

test "integer literal pattern — compiles to strict equality", ->
  eqJS """
    f = (n) ->
      match n
        | 0 -> "zero"
        | _ -> "other"
  """, """
    const f = function(n) {
      const m = n;
      if (m === 0) {
        return "zero";
      } else if (true) {
        return "other";
      }
    };
  """

test "multiple integer literals in sequence", ->
  f = (n) ->
    match n
      | 0  -> "zero"
      | 1  -> "one"
      | 2  -> "two"
      | 99 -> "ninety-nine"
      | _  -> "other"

  eq f(0),  "zero"
  eq f(1),  "one"
  eq f(2),  "two"
  eq f(99), "ninety-nine"
  eq f(42), "other"

# ─────────────────────────────────────────────────────────────────────────────
# 2. LITERAL PATTERNS — floats
# ─────────────────────────────────────────────────────────────────────────────

test "float literal pattern — exact match", ->
  f = (n) ->
    match n
      | 3.14 -> "pi"
      | 2.71 -> "e"
      | _    -> "other"

  eq f(3.14), "pi"
  eq f(2.71), "e"
  eq f(1.0),  "other"

test "float literal pattern — compiles to strict equality", ->
  eqJS """
    f = (x) ->
      match x
        | 0.5 -> "half"
        | _   -> "other"
  """, """
    const f = function(x) {
      const m = x;
      if (m === 0.5) {
        return "half";
      } else if (true) {
        return "other";
      }
    };
  """

# ─────────────────────────────────────────────────────────────────────────────
# 3. LITERAL PATTERNS — strings
# ─────────────────────────────────────────────────────────────────────────────

test "string literal pattern — exact match", ->
  greet = (lang) ->
    match lang
      | "fr" -> "Bonjour"
      | "en" -> "Hello"
      | "es" -> "Hola"
      | _    -> "..."

  eq greet("fr"), "Bonjour"
  eq greet("en"), "Hello"
  eq greet("es"), "Hola"
  eq greet("de"), "..."

test "string literal pattern — compiles to strict equality", ->
  eqJS """
    greet = (lang) ->
      match lang
        | "fr" -> "Bonjour"
        | _    -> "..."
  """, """
    const greet = function(lang) {
      const m = lang;
      if (m === "fr") {
        return "Bonjour";
      } else if (true) {
        return "...";
      }
    };
  """

test "string literal — empty string matches", ->
  f = (s) ->
    match s
      | "" -> "empty"
      | _  -> "non-empty"

  eq f(""),   "empty"
  eq f("hi"), "non-empty"

# ─────────────────────────────────────────────────────────────────────────────
# 4. LITERAL PATTERNS — booleans
# ─────────────────────────────────────────────────────────────────────────────

test "boolean literal patterns — true and false", ->
  describe = (b) ->
    match b
      | true  -> "yes"
      | false -> "no"

  eq describe(true),  "yes"
  eq describe(false), "no"

test "boolean literal pattern — compiles to strict equality", ->
  eqJS """
    f = (b) ->
      match b
        | true  -> "yes"
        | false -> "no"
  """, """
    const f = function(b) {
      const m = b;
      if (m === true) {
        return "yes";
      } else if (m === false) {
        return "no";
      }
    };
  """

# ─────────────────────────────────────────────────────────────────────────────
# 5. LITERAL PATTERNS — null / undefined
# ─────────────────────────────────────────────────────────────────────────────

test "null literal pattern — matches null", ->
  f = (v) ->
    match v
      | null -> "null"
      | _    -> "other"

  eq f(null),      "null"
  eq f(undefined), "other"
  eq f(0),         "other"

test "undefined literal pattern — matches undefined", ->
  f = (v) ->
    match v
      | undefined -> "undefined"
      | _         -> "other"

  eq f(undefined), "undefined"
  eq f(null),      "other"
  eq f(0),         "other"

test "null and undefined as separate branches", ->
  f = (v) ->
    match v
      | null      -> "null"
      | undefined -> "undefined"
      | _         -> "other"

  eq f(null),      "null"
  eq f(undefined), "undefined"
  eq f(42),        "other"

# ─────────────────────────────────────────────────────────────────────────────
# 6. WILDCARD `_`
# ─────────────────────────────────────────────────────────────────────────────

test "wildcard _ always matches", ->
  f = (x) ->
    match x
      | _ -> "anything"

  eq f(0),         "anything"
  eq f("hello"),   "anything"
  eq f(null),      "anything"
  eq f(undefined), "anything"

test "wildcard _ compiles to else if (true)", ->
  eqJS """
    f = (x) ->
      match x
        | 0 -> "zero"
        | _ -> "other"
  """, """
    const f = function(x) {
      const m = x;
      if (m === 0) {
        return "zero";
      } else if (true) {
        return "other";
      }
    };
  """

test "wildcard _ does not bind a variable", ->
  compiled = CoffeeScript.compile """
    f = (x) ->
      match x
        | _ -> "ok"
  """, bare: yes
  ok not /const _/.test(compiled), "wildcard must not introduce a const _ binding"

# ─────────────────────────────────────────────────────────────────────────────
# 7. VARIABLE BINDING
# ─────────────────────────────────────────────────────────────────────────────

test "variable binding captures the matched value", ->
  double = (x) ->
    match x
      | 0 -> 0
      | n -> n * 2

  eq double(0), 0
  eq double(7), 14

test "variable binding — compiles to const assignment in branch", ->
  eqJS """
    f = (x) ->
      match x
        | 0 -> "zero"
        | n -> "got \#{n}"
  """, """
    const f = function(x) {
      const m = x;
      if (m === 0) {
        return "zero";
      } else if (true) {
        const n = m;
        return `got ${n}`;
      }
    };
  """

test "variable binding always matches (no test on value)", ->
  f = (x) ->
    match x
      | n -> n + 1

  eq f(0),   1
  eq f(5),   6
  eq f(-3), -2

test "variable binding with guard — only runs when guard passes", ->
  sign = (n) ->
    match n
      | 0          -> "zero"
      | n if n > 0 -> "positive: #{n}"
      | n          -> "negative: #{n}"

  eq sign(0),  "zero"
  eq sign(5),  "positive: 5"
  eq sign(-3), "negative: -3"

# ─────────────────────────────────────────────────────────────────────────────
# 8. GUARDS
# ─────────────────────────────────────────────────────────────────────────────

test "guard with integer binding — positive/negative/zero", ->
  sign = (n) ->
    match n
      | 0          -> "zero"
      | n if n > 0 -> "positive"
      | _          -> "negative"

  eq sign(0),   "zero"
  eq sign(5),   "positive"
  eq sign(-3),  "negative"

test "guard compiles to && condition", ->
  eqJS """
    f = (n) ->
      match n
        | n if n > 0 -> "pos"
        | _          -> "other"
  """, """
    const f = function(n) {
      const m = n;
      if (true && m > 0) {
        const n = m;
        return "pos";
      } else if (true) {
        return "other";
      }
    };
  """

test "guard with complex expression", ->
  classify = (n) ->
    match n
      | n if n % 2 is 0 and n > 0  -> "positive even"
      | n if n % 2 isnt 0 and n > 0 -> "positive odd"
      | _ -> "non-positive"

  eq classify(4),  "positive even"
  eq classify(3),  "positive odd"
  eq classify(-2), "non-positive"
  eq classify(0),  "non-positive"

test "guard uses the bound variable", ->
  f = (s) ->
    match s
      | s if s.length > 3 -> "long: #{s}"
      | s                  -> "short: #{s}"

  eq f("hi"),    "short: hi"
  eq f("hello"), "long: hello"

# ─────────────────────────────────────────────────────────────────────────────
# 9. OR-PATTERNS
# ─────────────────────────────────────────────────────────────────────────────

test "or-pattern matches any of the listed values", ->
  isVowel = (c) ->
    match c
      | "a", "e", "i", "o", "u" -> yes
      | _                        -> no

  eq isVowel("a"), yes
  eq isVowel("e"), yes
  eq isVowel("b"), no
  eq isVowel("z"), no

test "or-pattern with integers", ->
  isWeekend = (day) ->
    match day
      | 6, 7 -> yes
      | _    -> no

  eq isWeekend(6), yes
  eq isWeekend(7), yes
  eq isWeekend(1), no
  eq isWeekend(5), no

test "or-pattern compiles to || conditions", ->
  eqJS """
    f = (c) ->
      match c
        | "a", "e" -> "vowel"
        | _        -> "other"
  """, """
    const f = function(c) {
      const m = c;
      if (m === "a" || m === "e") {
        return "vowel";
      } else if (true) {
        return "other";
      }
    };
  """

test "or-pattern with five string values — vowels", ->
  eqJS """
    f = (c) ->
      match c
        | "a", "e", "i", "o", "u" -> "vowel"
        | _                        -> "consonant"
  """, """
    const f = function(c) {
      const m = c;
      if (m === "a" || m === "e" || m === "i" || m === "o" || m === "u") {
        return "vowel";
      } else if (true) {
        return "consonant";
      }
    };
  """

# ─────────────────────────────────────────────────────────────────────────────
# 10. MATCH AS EXPRESSION
# ─────────────────────────────────────────────────────────────────────────────

test "match used as expression in assignment", ->
  x = 3
  label = match x
    | 1 -> "one"
    | 2 -> "two"
    | _ -> "many"
  eq label, "many"

test "match expression returns the matched branch value", ->
  result = match 0
    | 0 -> "zero"
    | _ -> "other"
  eq result, "zero"

test "match expression in function call argument", ->
  describe = (n) ->
    "value is: " + (match n
      | 0 -> "zero"
      | 1 -> "one"
      | _ -> "other")

  eq describe(0), "value is: zero"
  eq describe(1), "value is: one"
  eq describe(9), "value is: other"

test "match used as return value of a function", ->
  classify = (n) ->
    match n
      | 0          -> "zero"
      | n if n > 0 -> "positive"
      | _          -> "negative"

  eq classify(0),   "zero"
  eq classify(1),   "positive"
  eq classify(-1),  "negative"

# ─────────────────────────────────────────────────────────────────────────────
# 11. IMMUTABILITY — const subject and bindings
# ─────────────────────────────────────────────────────────────────────────────

test "match subject is compiled as const", ->
  compiled = CoffeeScript.compile """
    f = (x) ->
      match x
        | 0 -> "zero"
        | _ -> "other"
  """, bare: yes
  ok /const m\w* = x/.test(compiled), "subject variable must be const"

test "match binding is compiled as const", ->
  compiled = CoffeeScript.compile """
    f = (x) ->
      match x
        | n -> n + 1
  """, bare: yes
  ok /const n =/.test(compiled), "bound variable must be const"

test "no var keyword in match output", ->
  compiled = CoffeeScript.compile """
    f = (n) ->
      match n
        | 0          -> "zero"
        | n if n > 0 -> "pos"
        | _          -> "neg"
  """, bare: yes
  ok not /\bvar\b/.test(compiled), "match output must not contain var"

# ─────────────────────────────────────────────────────────────────────────────
# 12. GENERATED JS STRUCTURE
# ─────────────────────────────────────────────────────────────────────────────

test "full match compiles to const declaration + if/else if chain", ->
  eqJS """
    describe = (n) ->
      match n
        | 0          -> "zero"
        | 1          -> "one"
        | n if n < 0 -> "negative"
        | _          -> "many"
  """, """
    const describe = function(n) {
      const m = n;
      if (m === 0) {
        return "zero";
      } else if (m === 1) {
        return "one";
      } else if (true && m < 0) {
        const n = m;
        return "negative";
      } else if (true) {
        return "many";
      }
    };
  """

test "first arm uses if, subsequent arms use else if", ->
  compiled = CoffeeScript.compile """
    f = (n) ->
      match n
        | 0 -> "zero"
        | 1 -> "one"
        | _ -> "other"
  """, bare: yes
  ifMatches    = compiled.match /\bif\b/g
  elseIfMatches = compiled.match /else if/g
  ok ifMatches?.length >= 1,     "must have at least one if"
  ok elseIfMatches?.length >= 2, "must have else if for subsequent arms"

test "match with single arm and wildcard compiles cleanly", ->
  eqJS """
    f = (x) ->
      match x
        | _ -> 42
  """, """
    const f = function(x) {
      const m = x;
      if (true) {
        return 42;
      }
    };
  """

# ─────────────────────────────────────────────────────────────────────────────
# 13. EDGE CASES
# ─────────────────────────────────────────────────────────────────────────────

test "match on computed expression (function call result)", ->
  double = (n) -> n * 2
  f = ->
    match double(3)
      | 6 -> "correct"
      | _ -> "wrong"
  eq f(), "correct"

test "match on string method result", ->
  f = (s) ->
    match s.toLowerCase()
      | "hello" -> "greeting"
      | _       -> "other"

  eq f("HELLO"), "greeting"
  eq f("Hello"), "greeting"
  eq f("bye"),   "other"

test "nested match expressions", ->
  f = (x, y) ->
    match x
      | 0 ->
          match y
            | 0 -> "both zero"
            | _ -> "x zero"
      | _ -> "x non-zero"

  eq f(0, 0), "both zero"
  eq f(0, 1), "x zero"
  eq f(1, 0), "x non-zero"

test "match inside a loop", ->
  results = []
  for n in [0, 1, 2, -1]
    results.push(match n
      | 0          -> "zero"
      | n if n > 0 -> "pos"
      | _          -> "neg"
    )

  arrayEq results, ["zero", "pos", "pos", "neg"]

test "match with multiline body in arm", ->
  f = (n) ->
    match n
      | 0 ->
          x = 10
          y = 20
          x + y
      | _ -> -1

  eq f(0), 30
  eq f(1), -1

test "or-pattern with three values", ->
  f = (n) ->
    match n
      | 1, 2, 3 -> "small"
      | _        -> "large"

  eq f(1), "small"
  eq f(2), "small"
  eq f(3), "small"
  eq f(4), "large"
