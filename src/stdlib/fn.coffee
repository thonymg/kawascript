identity = (x) -> x

always = (x) -> -> x

compose = (fns...) -> (x) -> fns.reduceRight ((acc, fn) -> fn acc), x

pipe = (fns...) -> (x) -> fns.reduce ((acc, fn) -> fn acc), x

flip = (fn) -> (a, b, rest...) -> fn b, a, rest...

curry = (fn) ->
  arity = fn.length
  curried = (args...) ->
    if args.length >= arity
      fn args...
    else
      (moreArgs...) -> curried (args.concat moreArgs)...
  curried

partial = (fn, partialArgs...) -> (remainingArgs...) -> fn partialArgs..., remainingArgs...

memoize = (fn, keyFn = JSON.stringify) ->
  cache = new Map()
  (args...) ->
    key = keyFn args
    unless cache.has key
      cache.set key, fn args...
    cache.get key

tap = (fn) -> (x) -> fn x; x

complement = (fn) -> (args...) -> not fn args...

once = (fn) ->
  called = no
  result = undefined
  (args...) ->
    unless called
      called = yes
      result = fn args...
    result

juxt = (fns...) -> (args...) -> fn args... for fn in fns

converge = (combining, fns...) -> (args...) -> combining ...(fn args... for fn in fns)

module.exports = {identity, always, compose, pipe, flip, curry, partial, memoize, tap, complement, once, juxt, converge}
