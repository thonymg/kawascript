# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/object
# ─────────────────────────────────────────────────────────────────────────────

{prop, propOr, path, pathOr, props, assoc, dissoc, pick, omit, pickBy,
 evolve, merge, mergeLeft, mergeDeep, where, whereEq,
 toPairs, fromPairs, keys, values, mapKeys} = require '../src/stdlib/object'

test "prop — reads a property", ->
  eq prop('a', {a: 1, b: 2}), 1

test "propOr — returns default when missing", ->
  eq propOr('unknown', 'name', {}), 'unknown'
  eq propOr('unknown', 'name', {name: 'Alice'}), 'Alice'

test "path — deep access", ->
  obj = {a: {b: {c: 42}}}
  eq path(['a','b','c'], obj), 42
  eq path(['a','x','c'], obj), undefined

test "pathOr — deep access with default", ->
  obj = {a: {b: 1}}
  eq pathOr(99, ['a','b'], obj), 1
  eq pathOr(99, ['a','x'], obj), 99

test "assoc — immutable set", ->
  obj = {a: 1}
  result = assoc 'b', 2, obj
  eq result.b, 2
  eq obj.b, undefined

test "dissoc — immutable delete", ->
  obj = {a: 1, b: 2, c: 3}
  result = dissoc 'b', obj
  eq result.b, undefined
  eq result.a, 1
  eq result.c, 3

test "pick — projection by keys", ->
  obj = {a:1, b:2, c:3}
  eq JSON.stringify(pick(['a','c'], obj)), '{"a":1,"c":3}'

test "omit — inverse projection", ->
  obj = {a:1, b:2, c:3}
  eq JSON.stringify(omit(['b'], obj)), '{"a":1,"c":3}'

test "evolve — transforms values by spec", ->
  double = (n) -> n * 2
  upper  = (s) -> s.toUpperCase()
  obj    = {price: 10, name: 'hello', untouched: 99}
  result = evolve {price: double, name: upper}, obj
  eq result.price,     20
  eq result.name,      'HELLO'
  eq result.untouched, 99

test "where — object predicate matching", ->
  ident = (x) -> x
  isAdult = (n) -> n > 18
  spec = {age: isAdult, active: ident}
  ok    where(spec, {age: 25, active: yes}), "should pass"
  ok not where(spec, {age: 15, active: yes}), "should fail"

test "whereEq — object equality matching", ->
  spec = {role: 'admin', active: yes}
  ok    whereEq(spec, {role: 'admin', active: yes, name: 'Alice'})
  ok not whereEq(spec, {role: 'user', active: yes})

test "merge — right properties win", ->
  result = merge {a:1, b:2}, {b:3, c:4}
  eq result.a, 1
  eq result.b, 3
  eq result.c, 4

test "mergeLeft — left properties win", ->
  result = mergeLeft {a:1, b:2}, {b:3, c:4}
  eq result.b, 2

test "mergeDeep — recursive merge", ->
  a = {x: {y: 1, z: 2}}
  b = {x: {y: 10, w: 3}}
  result = mergeDeep a, b
  eq result.x.y, 10
  eq result.x.z, 2
  eq result.x.w, 3

test "toPairs / fromPairs", ->
  obj = {a:1, b:2}
  pairs = toPairs obj
  eq pairs.length, 2
  result = fromPairs [['a',1],['b',2]]
  eq result.a, 1
  eq result.b, 2

test "keys / values", ->
  obj = {a:1, b:2, c:3}
  arrayEq keys(obj), ['a','b','c']
  arrayEq values(obj), [1,2,3]

test "mapKeys — transforms keys", ->
  obj = {a: 1, b: 2}
  result = mapKeys ((k) -> k.toUpperCase()), obj
  eq result.A, 1
  eq result.B, 2
