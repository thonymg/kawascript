prop = (key, obj) -> obj[key]

propOr = (default_, key, obj) -> if obj[key]? then obj[key] else default_

path = (keys, obj) -> keys.reduce ((o, k) -> o?[k]), obj

pathOr = (default_, keys, obj) ->
  result = path keys, obj
  if result? then result else default_

props = (keys, obj) -> keys.map (k) -> obj[k]

assoc = (key, val, obj) -> {...obj, [key]: val}

dissoc = (key, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k]) -> k isnt key

pick = (keys, obj) ->
  Object.fromEntries keys.filter((k) -> k of obj).map (k) -> [k, obj[k]]

omit = (keys, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k]) -> not (k in keys)

pickBy = (pred, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k, v]) -> pred v, k

evolve = (spec, obj) ->
  Object.fromEntries Object.entries(obj).map ([k, v]) ->
    [k, if typeof spec[k] is 'function' then spec[k](v) else v]

merge = (a, b) -> {...a, ...b}

mergeLeft = (a, b) -> {...b, ...a}

mergeRight = (a, b) -> {...a, ...b}

mergeDeep = (a, b) ->
  result = Object.assign new Object(), a
  for own k, v of b
    if v? and typeof v is 'object' and not Array.isArray(v) and
       a[k]? and typeof a[k] is 'object' and not Array.isArray(a[k])
      result[k] = mergeDeep a[k], v
    else
      result[k] = v
  result

where = (spec, obj) ->
  Object.entries(spec).every ([k, pred]) -> pred obj[k]

whereEq = (spec, obj) ->
  Object.entries(spec).every ([k, v]) -> obj[k] is v

toPairs = (obj) -> Object.entries obj

fromPairs = (pairs) -> Object.fromEntries pairs

keys = (obj) -> Object.keys obj

values = (obj) -> Object.values obj

mapKeys = (fn, obj) ->
  Object.fromEntries Object.entries(obj).map ([k, v]) -> [fn(k), v]

module.exports = {prop, propOr, path, pathOr, props, assoc, dissoc, pick, omit, pickBy, evolve, merge, mergeLeft, mergeRight, mergeDeep, where, whereEq, toPairs, fromPairs, keys, values, mapKeys}
