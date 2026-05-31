# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/augment (prototype extensions opt-in)
# ─────────────────────────────────────────────────────────────────────────────

require '../src/stdlib/augment'

test "augment — Array#compact", ->
  arrayEq [1, null, 2, undefined].compact(), [1, 2]

test "augment — Array#sum", ->
  eq [1,2,3,4].sum(), 10

test "augment — Array#uniq", ->
  arrayEq [1,2,1,3].uniq(), [1,2,3]

test "augment — Array#chunk", ->
  arrayEq [1,2,3,4].chunk(2), [[1,2],[3,4]]

test "augment — Array#tally", ->
  t = ['a','b','a'].tally()
  eq t.get('a'), 2

test "augment — prototype properties are non-enumerable", ->
  ks = Object.keys []
  ok not ks.includes('compact'), "compact should not be enumerable"
  ok not ks.includes('sum'),     "sum should not be enumerable"

test "augment — String#camelize", ->
  eq 'hello_world'.camelize(), 'helloWorld'

test "augment — String#words", ->
  arrayEq 'hello world'.words(), ['hello', 'world']
