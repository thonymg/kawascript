# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/array
# ─────────────────────────────────────────────────────────────────────────────

{compact, zip, sum, partition, chunk, windows,
 uniq, uniqBy, minBy, maxBy, tally, groupBy} = require '../src/stdlib/array'

test "compact — removes falsy values", ->
  arrayEq compact([1, null, 2, undefined, 0, false, 3]), [1, 2, 3]

test "zip — combines arrays element-wise", ->
  arrayEq zip([1,2,3], [4,5,6]), [[1,4],[2,5],[3,6]]

test "zip — three arrays", ->
  arrayEq zip([1,2], [3,4], [5,6]), [[1,3,5],[2,4,6]]

test "sum — sums elements", ->
  eq sum([1,2,3,4]), 10

test "sum — with mapper", ->
  eq sum([{v:1},{v:2},{v:3}], (x) -> x.v), 6

test "partition — splits by predicate", ->
  [evens, odds] = partition [1,2,3,4,5], (n) -> n % 2 is 0
  arrayEq evens, [2, 4]
  arrayEq odds,  [1, 3, 5]

test "chunk — groups of n", ->
  arrayEq chunk([1,2,3,4,5,6], 2), [[1,2],[3,4],[5,6]]

test "chunk — last group smaller", ->
  arrayEq chunk([1,2,3,4,5], 2), [[1,2],[3,4],[5]]

test "windows — sliding window", ->
  arrayEq windows([1,2,3,4], 2), [[1,2],[2,3],[3,4]]

test "uniq — removes duplicates", ->
  arrayEq uniq([1,2,1,3,2]), [1,2,3]

test "uniqBy — removes duplicates by key", ->
  input = [{id:1,v:'a'},{id:2,v:'b'},{id:1,v:'c'}]
  result = uniqBy input, (x) -> x.id
  eq result.length, 2
  eq result[0].id, 1
  eq result[1].id, 2

test "minBy / maxBy", ->
  arr = [{n:3},{n:1},{n:2}]
  eq minBy(arr, (x) -> x.n).n, 1
  eq maxBy(arr, (x) -> x.n).n, 3

test "tally — frequency map", ->
  t = tally ['a','b','a','c','b','a']
  eq t.get('a'), 3
  eq t.get('b'), 2
  eq t.get('c'), 1

test "groupBy — groups elements by key", ->
  g = groupBy [1,2,3,4,5,6], (n) -> if n % 2 is 0 then 'even' else 'odd'
  arrayEq g.get('even'), [2,4,6]
  arrayEq g.get('odd'),  [1,3,5]
