# ─────────────────────────────────────────────────────────────────────────────
# SUFFIXES ? ET ! SUR IDENTIFIANTS
# ─────────────────────────────────────────────────────────────────────────────

test "? suffix — identifier with ? is valid", ->
  isEmpty? = (arr) -> arr.length is 0
  eq isEmpty?([]), yes
  eq isEmpty?([1]), no

test "! suffix — identifier with ! is valid", ->
  counter = 0
  increment! = -> counter += 1
  increment!()
  eq counter, 1

test "? suffix — compiles to identifier without suffix", ->
  eqJS """
    isPositive? = (n) -> n > 0
  """, """
    const isPositive = function(n) {
      return n > 0;
    };
  """

test "! suffix — compiles to identifier without suffix", ->
  eqJS """
    reset! = -> 0
  """, """
    const reset = function() {
      return 0;
    };
  """

test "? and ! as second character only — no suffix mid-word", ->
  # a?b: ? is existential (not suffix), since b follows without = or :
  js = CoffeeScript.compile "a?b", bare: yes
  ok /typeof a/.test(js), "? after a followed by identifier is existential"

test "? suffix — method definition on object", ->
  eqJS """
    obj =
      empty?: -> @arr.length is 0
  """, """
    const obj = {
      'empty?': function() {
        return this.arr.length === 0;
      }
    };
  """
