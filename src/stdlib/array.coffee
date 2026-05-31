identity = (x) -> x

compact = (arr) -> arr.filter Boolean

zip = (arr, others...) -> arr.map (x, i) -> [x, ...(other[i] for other in others)]

sum = (arr, fn = identity) -> arr.reduce ((acc, x) -> acc + fn x), 0

partition = (arr, fn) ->
  arr.reduce ((acc, x) ->
    [passing, failing] = acc
    if fn x
      [[...passing, x], failing]
    else
      [passing, [...failing, x]]
  ), [[], []]

chunk = (arr, n) ->
  indices = [0...Math.ceil(arr.length / n)]
  indices.map (i) -> arr[i*n...(i+1)*n]

windows = (arr, n) -> arr.slice(i, i+n) for i in [0..arr.length - n]

uniq = (arr) -> [...new Set arr]

uniqBy = (arr, fn) ->
  seen = new Set()
  arr.filter (x) ->
    key = fn x
    return no if seen.has key
    seen.add key
    yes

minBy = (arr, fn) -> arr.reduce (a, b) -> if fn(a) <= fn(b) then a else b

maxBy = (arr, fn) -> arr.reduce (a, b) -> if fn(a) >= fn(b) then a else b

tally = (arr) -> arr.reduce ((m, x) -> m.set x, (m.get(x) ? 0) + 1), new Map()

groupBy = (arr, fn) ->
  arr.reduce ((m, x) ->
    key = fn x
    existing = m.get key
    m.set key, if existing then [...existing, x] else [x]
    m
  ), new Map()

flatten = (arr) -> arr.flat Infinity

unnest = (arr) -> arr.flat 1

scan = (fn, acc, arr) ->
  arr.reduce ((result, x) ->
    newAcc = fn result[result.length - 1], x
    [...result, newAcc]
  ), [acc]

groupWith = (pred, arr) ->
  return [] if arr.length is 0
  arr.slice(1).reduce ((groups, x) ->
    current = groups[groups.length - 1]
    if pred current[current.length - 1], x
      [...groups.slice(0, -1), [...current, x]]
    else
      [...groups, [x]]
  ), [[arr[0]]]

ascend = (fn) -> (a, b) ->
  if fn(a) < fn(b) then -1 else if fn(a) > fn(b) then 1 else 0

descend = (fn) -> (a, b) ->
  if fn(a) > fn(b) then -1 else if fn(a) < fn(b) then 1 else 0

sortBy = (fn, arr) ->
  let copy = Array.from arr
  copy.sort ascend fn
  copy

all = (pred, arr) -> arr.every pred

any = (pred, arr) -> arr.some pred

none = (pred, arr) -> not arr.some pred

count = (pred, arr) -> arr.filter(pred).length

take = (n, arr) -> arr.slice 0, n

drop = (n, arr) -> arr.slice n

takeWhile = (pred, arr) ->
  idx = arr.findIndex (x) -> not pred x
  if idx is -1 then arr else arr.slice 0, idx

dropWhile = (pred, arr) ->
  idx = arr.findIndex (x) -> not pred x
  if idx is -1 then [] else arr.slice idx

head = (arr) -> arr[0]

tail = (arr) -> arr.slice 1

last = (arr) -> arr[arr.length - 1]

init = (arr) -> arr.slice 0, -1

intersperse = (sep, arr) ->
  return arr if arr.length < 2
  arr.slice(1).reduce ((result, x) ->
    [...result, sep, x]
  ), [arr[0]]

intersection = (a, b) -> a.filter (x) -> b.includes x

union = (a, b) -> [...new Set [...a, ...b]]

difference = (a, b) -> a.filter (x) -> not b.includes x

without = (values, arr) -> arr.filter (x) -> not values.includes x

mean = (arr) -> arr.reduce(((a, b) -> a + b), 0) / arr.length

median = (arr) ->
  let sorted = Array.from arr
  sorted.sort (a, b) -> a - b
  mid = Math.floor sorted.length / 2
  if sorted.length % 2 is 0
    (sorted[mid-1] + sorted[mid]) / 2
  else
    sorted[mid]

product = (arr) -> arr.reduce ((a, b) -> a * b), 1

range = (from, to) -> [from...to]

transpose = (matrix) -> matrix[0].map (_, i) -> matrix.map (row) -> row[i]

indexBy = (fn, arr) -> Object.fromEntries arr.map (x) -> [fn(x), x]

collectBy = (fn, arr) ->
  {keys, groups} = arr.reduce ((acc, x) ->
    key = fn x
    existing = acc.groups[key]
    if existing
      {keys: acc.keys, groups: {...acc.groups, [key]: [...existing, x]}}
    else
      {keys: [...acc.keys, key], groups: {...acc.groups, [key]: [x]}}
  ), {keys: [], groups: {}}
  keys.map (k) -> groups[k]

dropRepeats = (arr) -> arr.filter (x, i) -> i is 0 or x isnt arr[i-1]

xprod = (a, b) -> a.flatMap (x) -> b.map (y) -> [x, y]

module.exports = {compact, zip, sum, partition, chunk, windows, uniq, uniqBy, minBy, maxBy, tally, groupBy, flatten, unnest, scan, groupWith, sortBy, ascend, descend, all, any, none, count, take, drop, takeWhile, dropWhile, head, tail, last, init, intersperse, intersection, union, difference, without, mean, median, product, range, transpose, indexBy, collectBy, dropRepeats, xprod}
