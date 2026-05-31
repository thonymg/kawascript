# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/array Phase 2 (Ramda-inspired)
# ─────────────────────────────────────────────────────────────────────────────

{flatten, unnest, scan, groupWith, sortBy, ascend, descend,
 all, any, none, count, take, drop, takeWhile, dropWhile,
 head, tail, last, init, intersperse, intersection, union,
 difference, without, mean, median, product, range,
 transpose, indexBy, collectBy, dropRepeats, xprod} = require '../src/stdlib/array'

identity = (x) -> x

test "flatten — deep flatten", ->
  arrayEq flatten([1,[2,[3,[4]]]]), [1,2,3,4]

test "unnest — single level flatten", ->
  arrayEq unnest([[1,2],[3,4]]), [1,2,3,4]
  arrayEq unnest([[1,[2]],[3]]), [1,[2],3]

test "scan — intermediate reductions", ->
  add = (a, b) -> a + b
  arrayEq scan(add, 0, [1,2,3,4]), [0,1,3,6,10]

test "scan — factorial via multiply", ->
  multiply = (a, b) -> a * b
  arrayEq scan(multiply, 1, [1,2,3,4,5]), [1,1,2,6,24,120]

test "groupWith — consecutive grouping", ->
  eq_ = (a, b) -> a is b
  result = groupWith eq_, [1,1,2,3,3,3,2]
  eq result.length, 4
  arrayEq result[0], [1,1]
  arrayEq result[1], [2]
  arrayEq result[2], [3,3,3]
  arrayEq result[3], [2]

test "groupWith — consecutive sequences", ->
  consecutive = (a, b) -> b - a is 1
  result = groupWith consecutive, [1,2,3,5,6,10]
  arrayEq result[0], [1,2,3]
  arrayEq result[1], [5,6]
  arrayEq result[2], [10]

test "sortBy — sort by extracted key", ->
  arr = [{n:3},{n:1},{n:2}]
  result = sortBy ((x) -> x.n), arr
  arrayEq result.map((x) -> x.n), [1,2,3]

test "all / any / none / count", ->
  gt0 = (n) -> n > 0
  gt1 = (n) -> n > 1
  gt2 = (n) -> n > 2
  gt5 = (n) -> n > 5
  eq all(gt0, [1,2,3]),  yes
  eq all(gt1, [1,2,3]),  no
  eq any(gt2, [1,2,3]),  yes
  eq any(gt5, [1,2,3]),  no
  eq none(gt5, [1,2,3]), yes
  eq none(gt2, [1,2,3]), no
  eq count(gt1, [1,2,3,4]), 3

test "take / drop", ->
  arrayEq take(3, [1,2,3,4,5]), [1,2,3]
  arrayEq drop(2, [1,2,3,4,5]), [3,4,5]

test "takeWhile / dropWhile", ->
  lt3 = (n) -> n < 3
  arrayEq takeWhile(lt3, [1,2,3,4,1]), [1,2]
  arrayEq dropWhile(lt3, [1,2,3,4,1]), [3,4,1]

test "head / tail / last / init", ->
  eq head([1,2,3]), 1
  arrayEq tail([1,2,3]), [2,3]
  eq last([1,2,3]), 3
  arrayEq init([1,2,3]), [1,2]

test "intersperse", ->
  arrayEq intersperse(0, [1,2,3]), [1,0,2,0,3]
  arrayEq intersperse(',', ['a','b','c']), ['a',',','b',',','c']

test "intersection / union / difference / without", ->
  arrayEq intersection([1,2,3,4], [2,4,6]), [2,4]
  arrayEq union([1,2,3], [2,3,4]), [1,2,3,4]
  arrayEq difference([1,2,3,4], [2,4]), [1,3]
  arrayEq without([2,4], [1,2,3,4,5]), [1,3,5]

test "mean / median / product", ->
  eq mean([1,2,3,4,5]), 3
  eq median([1,2,3,4,5]), 3
  eq median([1,2,3,4]),   2.5
  eq product([1,2,3,4,5]), 120

test "range", ->
  arrayEq range(1, 5), [1,2,3,4]
  arrayEq range(0, 3), [0,1,2]

test "transpose", ->
  arrayEq transpose([[1,2,3],[4,5,6]]), [[1,4],[2,5],[3,6]]

test "indexBy", ->
  arr = [{id:'a',v:1},{id:'b',v:2}]
  result = indexBy ((x) -> x.id), arr
  eq result.a.v, 1
  eq result.b.v, 2

test "collectBy — ordered grouped arrays", ->
  arr = ['a','b','c','a','b']
  result = collectBy identity, arr
  arrayEq result[0], ['a','a']
  arrayEq result[1], ['b','b']
  arrayEq result[2], ['c']

test "dropRepeats", ->
  arrayEq dropRepeats([1,1,2,3,3,3,2]), [1,2,3,2]

test "xprod — cartesian product", ->
  arrayEq xprod([1,2],[3,4]), [[1,3],[1,4],[2,3],[2,4]]
