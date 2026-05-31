# Block E — Suffixes `?`/`!` sur Identifiants et Stdlib Fonctionnelle

## Référence Ramda — Analyse et Inspiration

> Ramda v0.32.0 (oct. 2025, activement maintenu, 24k★) est la bibliothèque FP JS de
> référence. Ce document analyse son API comme **source d'inspiration**, pas comme
> dépendance. KawaScript implémente nativement une stdlib alignée sur les conventions
> Ramda (data-last, tout-curried) pour bénéficier de l'interopérabilité avec le
> pipe operator (Block B) sans ajouter de dépendance externe.

### Ce que Ramda apporte qu'on n'a pas encore prévu

#### Pour `kawa/fn` — combinateurs manquants

| Fonction Ramda | Export KawaScript | Utilité | Priorité |
|---|---|---|---|
| `curryN(n, fn)` | `curryN` | Curry avec arité explicite (variadic functions) | ★★★ |

#### Pour `kawa/array` — fonctions manquantes

| Fonction Ramda | Utilité | Équivalent Ruby | Priorité |
|---|---|---|---|
| `flatten` / `unnest` | Aplatir sur 1 niveau ou profondément | `flatten` | ★★★ |
| `scan(fn, acc, arr)` | `reduce` qui retourne toutes les valeurs intermédiaires | - | ★★★ |
| `groupWith(fn, arr)` | Grouper les éléments consécutifs | `chunk_while` | ★★★ |
| `sortBy(fn, arr)` | Trier par clé extraite | `sort_by` | ★★★ |
| `ascend(fn)` / `descend(fn)` | Comparateurs pour `sort` / `sortBy` | - | ★★ |
| `mean(arr)` / `median(arr)` | Statistiques de base | - | ★★ |
| `product(arr)` | Produit de tous les éléments | `reduce(:*)` | ★ |
| `all(pred, arr)` | Tous les éléments passent | `all?` | ★★★ |
| `any(pred, arr)` | Au moins un élément passe | `any?` | ★★★ |
| `none(pred, arr)` | Aucun élément ne passe | `none?` | ★★ |
| `count(pred, arr)` | Nombre d'éléments qui passent | `count` | ★★ |
| `take(n, arr)` / `drop(n, arr)` | Slicing par index | `first(n)` / `drop(n)` | ★★ |
| `takeWhile(pred, arr)` | Prendre jusqu'à prédicat faux | `take_while` | ★★ |
| `dropWhile(pred, arr)` | Dropper jusqu'à prédicat vrai | `drop_while` | ★★ |
| `head` / `tail` / `last` / `init` | Accesseurs idiomatiques | `first/last` | ★★ |
| `flatten` (deep) | Aplatissement récursif | `flatten` | ★★★ |
| `intersperse(sep, arr)` | Insérer un séparateur entre chaque élément | `join` mais en array | ★★ |
| `intersection(a, b)` | Éléments communs aux deux listes | `&` | ★★ |
| `union(a, b)` | Union sans doublons | `\|` | ★★ |
| `difference(a, b)` | Éléments de `a` absents de `b` | `-` | ★★ |
| `transpose(matrix)` | Transposer une matrice 2D | `transpose` | ★ |
| `indexBy(fn, arr)` | Transformer array en objet indexé par clé | `index_by` | ★★ |
| `collectBy(fn, arr)` | `groupBy` qui retourne array d'arrays (ordre préservé) | - | ★★ |
| `without(values, arr)` | Supprimer des valeurs | `-` | ★★ |
| `dropRepeats(arr)` | Supprimer les répétitions consécutives | - | ★ |
| `range(from, to)` | `[from..to-1]` (fonctionnel, curried) | - | ★★ |
| `xprod(a, b)` | Produit cartésien | - | ★ |
| `unfold(fn, seed)` | Générer une liste depuis une graine | - | ★ |

#### Nouveau module `kawa/object` (inspiré Ramda)

Ramda a un ensemble de fonctions objet très puissant — absent de notre plan.

```coffee
# kawa/object — Utilitaires objet immutables

export prop    = (key, obj) -> obj[key]
export propOr  = (default_, key, obj) -> obj[key] ? default_
export path    = (keys, obj) -> keys.reduce ((o, k) -> o?[k]), obj
export pathOr  = (default_, keys, obj) -> path(keys, obj) ? default_

export assoc   = (key, val, obj) -> {...obj, [key]: val}
export dissoc  = (key, obj) -> Object.fromEntries Object.entries(obj).filter ([k]) -> k isnt key

export pick    = (keys, obj) -> Object.fromEntries keys.filter((k) -> k of obj).map (k) -> [k, obj[k]]
export omit    = (keys, obj) -> Object.fromEntries Object.entries(obj).filter ([k]) -> k not in keys

# evolve — transformer les valeurs selon un spec de fonctions
export evolve = (spec, obj) ->
  Object.fromEntries Object.entries(obj).map ([k, v]) ->
    [k, if typeof spec[k] is 'function' then spec[k](v) else v]

# where — tester un objet contre un spec de prédicats
export where = (spec, obj) ->
  Object.entries(spec).every ([k, pred]) -> pred obj[k]

export toPairs = (obj) -> Object.entries obj
export fromPairs = (pairs) -> Object.fromEntries pairs
export keys = Object.keys
export values = Object.values
export mapKeys = (fn, obj) -> Object.fromEntries Object.entries(obj).map ([k, v]) -> [fn(k), v]
```

> **`evolve` et `where` sont les deux fonctions objet les plus idiomatiques
> de Ramda.** Elles permettent :
> ```coffee
> # Transformer un objet en appliquant des fonctions aux valeurs
> evolve {price: multiply(1.2), name: trim}, product
>
> # Filtrer par spec de prédicats (très lisible)
> users |> filter where {age: gt(18), active: identity}
> ```

Mais pour les sections partielles c'est élégant. **Reporter en Block F si besoin**.

### Convention data-last — alignement avec Block B

Toutes les fonctions de `kawa/fn`, `kawa/array` et `kawa/object` doivent être
**data-last** (données en dernier argument) pour fonctionner naturellement avec `|>` :

```coffee
# ✓ data-last — compose bien avec |>
filter pred, arr          # fn, data
groupBy fn, arr           # fn, data
prop 'name', obj          # key, data

# ✗ data-first — ne se compose pas avec |>
arr.filter pred           # méthode native, ok localement
```

> Cela diffère de la convention Ruby (méthodes sur l'objet) mais c'est cohérent
> avec le pipe operator planifié en Block B.

### `scan` — la fonction la plus sous-estimée

`scan` est comme `reduce` mais retourne toutes les valeurs intermédiaires :

```coffee
scan multiply, 1, [1,2,3,4,5]
# → [1, 1, 2, 6, 24, 120]  (factorielles!)

# Running total
scan add, 0, [10, 20, 30]
# → [0, 10, 30, 60]
```

C'est fondamental pour la visualisation de données, les animations d'état, et les
algorithmes de dynamic programming. À ajouter en priorité haute.

### `groupWith` — le `chunk_while` Ruby qu'on n'a pas

Notre `windows` (= `aperture` Ramda) est une fenêtre glissante fixe. `groupWith`
groupe les éléments *consécutifs* selon un prédicat :

```coffee
groupWith equals, [0,1,1,2,3,5,8]
# → [[0],[1,1],[2],[3],[5],[8]]   (run-length encoding)

groupWith (a, b) -> b - a is 1, [1,2,3,5,6,10]
# → [[1,2,3],[5,6],[10]]   (séquences consécutives)
```

C'est plus général que `chunk` et couvre un cas très fréquent.

---

## Prérequis

- **Block A complété** : le compilateur doit bootstrapper.
- Block B, C, D sont indépendants de ce block.

## Spécification

### Suffixes d'identifiants

```coffee
# ? = prédicat (convention sémantique, pas de transformation JS)
isEmpty? = (arr) -> arr.length is 0
isEmpty?([])  # → true

# ! = mutation / side-effect (convention sémantique)
reset! = -> counter = 0
reset!()
```

**Ce que le compilateur doit faire** :
- `isEmpty?` est lexé comme un identifiant valide `isEmpty?`
- `reset!` est lexé comme `reset!`
- Aucune transformation JS — ce sont juste des noms de fonctions valides en KawaScript
  compilés vers des identifiants JS sans les suffixes : `isEmpty?` → `isEmpty`, `reset!` → `reset`

### Stdlib fonctionnelle

Module `kawa/fn` importable depuis le KawaScript compilé :

```coffee
import {compose,  identity, always, flip, curry, partial, memoize} from 'kawa/fn'
```

Les fonctions sont elle-mêmes écrites en KawaScript.

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

> **⚠️ Attention** : `cake test` exécute **automatiquement** tous les fichiers `*.coffee` dans
> `test/`. Ne placer les fichiers de test stdlib dans `test/` qu'à partir du moment où le
> module correspondant existe dans `src/stdlib/`, sinon le `require` échouera et cassera
> toute la suite de tests.

> **Important** : les fichiers de test dans `test/` sont **automatiquerment exécutés** par
> `cake test`. Ne les placer dans `test/` qu'en même temps que le module implementé —
> jamais avant. Sinon `require '../src/stdlib/fn'` échouera et cassera la suite entière.

### Fichier : `test/operators.coffee` (ou nouveau `test/identifier_suffixes.coffee`)

```coffee
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
  # a? is valid, but a?b should parse as a? b (existential check + b)
  # This test ensures mid-word ? is still existential
  throws (-> CoffeeScript.compile "a?b = 1"), /unexpected/

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
```

### Fichier : `test/stdlib_fn.coffee` (nouveau)

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# STDLIB FONCTIONNELLE — kawa/fn
# ─────────────────────────────────────────────────────────────────────────────

{compose, pipe, identity, always, flip, curry, partial, memoize,
 tap, complement, once, juxt, converge} = require '../src/stdlib/fn'

test "identity — returns its argument unchanged", ->
  eq identity(42), 42
  eq identity("hello"), "hello"
  obj = {a: 1}
  eq identity(obj), obj

test "always — returns a function that always returns the given value", ->
  alwaysFive = always(5)
  eq alwaysFive(), 5
  eq alwaysFive(1, 2, 3), 5

test "compose — right-to-left function composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = compose inc, double
  eq transform(5), 11

test "compose — multiple functions", ->
  a = (x) -> x + 1
  b = (x) -> x * 2
  c = (x) -> x - 3
  eq compose(c, b, a)(4), 7

test "pipe — left-to-right function composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = pipe double, inc
  eq transform(5), 11

test "flip — swaps first two arguments", ->
  sub = (a, b) -> a - b
  flippedSub = flip sub
  eq flippedSub(3, 10), 7

test "curry — transforms function into curried form", ->
  add = curry (a, b) -> a + b
  add5 = add 5
  eq add5(3), 8
  eq add(2)(3), 5

test "curry — arity 3", ->
  clamp = curry (lo, hi, x) -> Math.min hi, Math.max lo, x
  clamp0to10 = clamp 0, 10
  eq clamp0to10(5),   5
  eq clamp0to10(-1),  0
  eq clamp0to10(15), 10

test "partial — partially applies arguments", ->
  add = (a, b, c) -> a + b + c
  add1and2 = partial add, 1, 2
  eq add1and2(3), 6

test "memoize — caches by composite key (multiple args)", ->
  callCount = 0
  add = memoize (a, b) ->
    callCount += 1
    a + b
  eq add(2, 3), 5
  eq add(2, 3), 5
  eq callCount, 1
  eq add(2, 4), 6
  eq callCount, 2

test "memoize — custom keyFn", ->
  callCount = 0
  fn = memoize ((x) -> callCount += 1; x * 2), ([x]) -> x
  eq fn(5), 10
  eq fn(5), 10
  eq callCount, 1

test "tap — returns value unchanged, runs side effect", ->
  log = []
  result = tap((x) -> log.push x)(42)
  eq result, 42
  arrayEq log, [42]

test "complement — inverts a predicate", ->
  isEven = (n) -> n % 2 is 0
  isOdd  = complement isEven
  eq isOdd(3), yes
  eq isOdd(4), no

test "once — executes function only once", ->
  callCount = 0
  fn = once -> callCount += 1; 'done'
  eq fn(), 'done'
  eq fn(), 'done'
  eq callCount, 1

test "juxt — applies multiple functions to same input", ->
  result = juxt(Math.min, Math.max)(3, 1, 4, 1, 5)
  arrayEq result, [1, 5]

test "converge — combines results of multiple functions", ->
  avg = converge(
    ((a, b) -> (a + b) / 2),
    Math.min,
    Math.max
  )
  eq avg(4, 2, 10), 6  # (min=2, max=10) → (2+10)/2 = 6
```

### Fichier : `test/stdlib_array.coffee` (nouveau)

```coffee
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
```

### Fichier : `test/stdlib_string.coffee` (nouveau)

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/string
# ─────────────────────────────────────────────────────────────────────────────

{words, lines, truncate, underscore, camelize, dasherize, capitalize} = require '../src/stdlib/string'

test "words — splits on whitespace", ->
  arrayEq words("hello world  foo"), ['hello','world','foo']

test "lines — splits on newline", ->
  arrayEq lines("a\nb\nc"), ['a','b','c']

test "truncate — short string unchanged", ->
  eq truncate("hello", 10), "hello"

test "truncate — long string truncated with ellipsis", ->
  eq truncate("hello world", 8), "hello w…"

test "underscore — camelCase to snake_case", ->
  eq underscore("helloWorld"),   "hello_world"
  eq underscore("HTMLParser"),   "html_parser"

test "camelize — snake_case to camelCase", ->
  eq camelize("hello_world"),   "helloWorld"
  eq camelize("foo-bar-baz"),   "fooBarBaz"

test "dasherize — to kebab-case", ->
  eq dasherize("helloWorld"),   "hello-world"

test "capitalize — first letter uppercase", ->
  eq capitalize("hello"), "Hello"
```

### Fichier : `test/stdlib_augment.coffee` (nouveau)

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/augment (prototype extensions opt-in)
# ─────────────────────────────────────────────────────────────────────────────

# Ce test charge le module augment qui mute les prototypes
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
  keys = Object.keys []
  ok not keys.includes('compact'),  "compact should not be enumerable"
  ok not keys.includes('sum'),      "sum should not be enumerable"

test "augment — String#camelize", ->
  eq 'hello_world'.camelize(), 'helloWorld'

test "augment — String#words", ->
  arrayEq 'hello world'.words(), ['hello', 'world']
```

### Fichier : `test/stdlib_array_phase2.coffee` (Phase 2 — Ramda-inspired)

```coffee
{flatten, unnest, scan, groupWith, sortBy, ascend, descend,
 all, any, none, count, take, drop, takeWhile, dropWhile,
 head, tail, last, init, intersperse, intersection, union,
 difference, without, mean, median, product, range,
 transpose, indexBy, collectBy, dropRepeats, xprod} = require '../src/stdlib/array'

identity = (x) -> x  # utilisé dans le test collectBy

test "flatten — deep flatten", ->
  arrayEq flatten([1,[2,[3,[4]]]]), [1,2,3,4]

test "unnest — single level flatten", ->
  arrayEq unnest([[1,2],[3,4]]), [1,2,3,4]
  arrayEq unnest([[1,[2]],[3]]), [1,[2],3]  # only one level

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
  eq all((n) -> n > 0, [1,2,3]),  yes
  eq all((n) -> n > 1, [1,2,3]),  no
  eq any((n) -> n > 2, [1,2,3]),  yes
  eq any((n) -> n > 5, [1,2,3]),  no
  eq none((n) -> n > 5, [1,2,3]), yes
  eq none((n) -> n > 2, [1,2,3]), no
  eq count((n) -> n > 1, [1,2,3,4]), 3

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
```

### Fichier : `test/stdlib_object.coffee` (nouveau)

```coffee
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
  eq obj.b, undefined  # not mutated

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
  eq result.untouched, 99  # non-spec keys pass through

test "where — object predicate matching", ->
  identity = (x) -> x
  gt18 = where {age: (n) -> n > 18, active: identity}
  ok    gt18({age: 25, active: yes}), "should pass"
  ok not gt18({age: 15, active: yes}), "should fail"

test "whereEq — object equality matching", ->
  isAdmin = whereEq {role: 'admin', active: yes}
  ok    isAdmin({role: 'admin', active: yes, name: 'Alice'})
  ok not isAdmin({role: 'user',  active: yes})

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
  arrayEq fromPairs([['a',1],['b',2]]), {a:1, b:2}

test "keys / values", ->
  obj = {a:1, b:2, c:3}
  arrayEq keys(obj), ['a','b','c']
  arrayEq values(obj), [1,2,3]

test "mapKeys — transforms keys", ->
  obj = {a: 1, b: 2}
  result = mapKeys ((k) -> k.toUpperCase()), obj
  eq result.A, 1
  eq result.B, 2
```

---

## Étape 2 — Implémentation

### 2a. Suffixes `?` et `!` — Lexer

**Fichier** : `src/lexer.coffee`

Le `?` actuel est ambigu : `a?` peut être soit un identifiant `a?` (nouveau), soit
l'opérateur existentiel `a ?` (check d'existence). La règle de désambiguïsation :

> `?` est un **suffixe d'identifiant** uniquement lorsqu'il suit **immédiatement** un identifiant
> (sans espace) ET qu'il n'est **pas** suivi d'un `.`, `[`, `(` ou `)` (qui indiqueraient
> l'opérateur existentiel chaîné `?.`).

**Approche** : dans `identifierToken`, après avoir capturé l'identifiant :

```diff
  identifierToken: ->
    ...
    # Capturer l'identifiant de base
    [input] = IDENTIFIER.exec @chunk
    id      = input

+   # Suffixe ? : le capturer si le prochain char est ? et non suivi de . ou [
+   if @chunk[id.length] is '?' and @chunk[id.length + 1] not in ['.', '[', '?']
+     id = id + '?'
+   # Suffixe ! : le capturer si le prochain char est !
+   else if @chunk[id.length] is '!'
+     id = id + '!'

    ...
    tag = 'IDENTIFIER'
    @token tag, id, 0, id.length   # Avancer de id.length, incluant le suffixe
```

> **Attention** : `?` dans `a?.b` est l'opérateur soak — il NE doit PAS être capturé comme
> suffixe. La vérification `@chunk[id.length + 1] not in ['.', '[']` s'en assure.

### 2b. Transformation lors de la compilation JS

**Fichier** : `src/nodes.coffee`, dans `IdentifierLiteral.compileNode`

Lors de la compilation vers JS, supprimer les suffixes `?` et `!` :

```diff
exports.IdentifierLiteral = class IdentifierLiteral extends Literal
  compileNode: (o) ->
-   [@makeCode @value]
+   [@makeCode @value.replace(/[?!]$/, '')]
```

> Cela affecte aussi `@value` dans `assigns`, `astProperties`, etc. — utiliser uniquement
> dans `compileNode`. Pour l'AST : conserver le nom sans suffixe dans `astProperties.name`.

### 2c. Stdlib fonctionnelle

#### Structure des modules

```
src/stdlib/
  fn.coffee        # Combinateurs FP purs (compose, pipe, curry, etc.)
  array.coffee     # Utilitaires tableau inspirés Ruby (compact, zip, sum, etc.)
  string.coffee    # Utilitaires chaîne (words, lines, camelize, etc.)
  augment.coffee   # Extensions prototype opt-in (voir §2f)
  index.coffee     # Re-exports
```

#### Fichier : `src/stdlib/fn.coffee`

```coffee
# kawa/fn — Combinateurs fonctionnels standard de KawaScript

export identity = (x) -> x

export always = (x) -> -> x

export compose = (fns...) ->
  (x) -> fns.reduceRight ((acc, fn) -> fn acc), x

export pipe = (fns...) ->
  (x) -> fns.reduce ((acc, fn) -> fn acc), x

export flip = (fn) ->
  (a, b, rest...) -> fn b, a, rest...

export curry = (fn) ->
  arity = fn.length
  curried = (args...) ->
    if args.length >= arity
      fn args...
    else
      # NOTE : utiliser le spread explicite (...) pour éviter l'ambiguïté CoffeeScript
      (moreArgs...) -> curried ...(args.concat moreArgs)
  curried

export partial = (fn, partialArgs...) ->
  (remainingArgs...) -> fn partialArgs..., remainingArgs...

# keyFn est injectable pour les args non-primitifs (ex: keyFn = ([a,b]) -> "#{a}:#{b}")
export memoize = (fn, keyFn = JSON.stringify) ->
  cache = new Map()
  (args...) ->
    key = keyFn args
    unless cache.has key
      cache.set key, fn args...
    cache.get key

# Injecter un side-effect dans un pipeline sans rompre la valeur
export tap = (fn) -> (x) -> fn x; x

# Inverser le résultat booléen d'un prédicat
export complement = (fn) -> (args...) -> not fn args...

# N'exécuter une fonction qu'une seule fois, mettre la valeur en cache ensuite
export once = (fn) ->
  called = no
  result = undefined
  (args...) ->
    unless called
      called = yes
      result = fn args...
    result

# Appliquer N fonctions au même input et retourner un tableau de résultats
export juxt = (fns...) -> (x) -> fn x for fn in fns

# Passer les résultats de N fonctions à une fonction de combinaison
# converge(add, [double, inc])(4) → add(double(4), inc(4)) → add(8, 5) → 13
export converge = (combining, fns...) ->
  (x) -> combining ...(fn x for fn in fns)
```

#### Fichier : `src/stdlib/array.coffee`

Fonctions standalone (pas de mutation de prototype — voir `augment.coffee` pour ça).

```coffee
# kawa/array — Utilitaires tableau inspirés d'Enumerable Ruby

# Supprimer les valeurs falsy (null, undefined, false, 0, '')
export compact = (arr) ->
  arr.filter Boolean

# Combiner plusieurs tableaux élément par élément : zip([1,2],[3,4]) → [[1,3],[2,4]]
export zip = (arr, others...) ->
  arr.map (x, i) -> [x, ...(other[i] for other in others)]

# Sommer les éléments, avec un mapper optionnel
export sum = (arr, fn = identity) ->
  arr.reduce ((acc, x) -> acc + fn x), 0

# Séparer en [éléments qui passent, éléments qui échouent]
export partition = (arr, fn) ->
  passing = []; failing = []
  for x in arr
    if fn x then passing.push x else failing.push x
  [passing, failing]

# Découper en groupes de taille n : chunk([1..6], 2) → [[1,2],[3,4],[5,6]]
export chunk = (arr, n) ->
  result = []
  i = 0
  while i < arr.length
    result.push arr[i...i+n]
    i += n
  result

# Fenêtre glissante de taille n : windows([1..4], 2) → [[1,2],[2,3],[3,4]]
export windows = (arr, n) ->
  arr.slice(i, i+n) for i in [0..arr.length - n] by 1

# Dédupliquer par valeur ou par clé
export uniq = (arr) -> [...new Set arr]
export uniqBy = (arr, fn) ->
  seen = new Set()
  arr.filter (x) ->
    key = fn x
    return no if seen.has key
    seen.add key
    yes

# Trouver le min/max par clé
export minBy = (arr, fn) -> arr.reduce (a, b) -> if fn(a) <= fn(b) then a else b
export maxBy = (arr, fn) -> arr.reduce (a, b) -> if fn(a) >= fn(b) then a else b

# Fréquences : tally(['a','b','a']) → Map { 'a' => 2, 'b' => 1 }
export tally = (arr) ->
  arr.reduce ((m, x) -> m.set x, (m.get(x) ? 0) + 1), new Map()

# Grouper par clé (retourne un Map pour préserver l'ordre)
export groupBy = (arr, fn) ->
  arr.reduce ((m, x) ->
    key = fn x
    unless m.has key then m.set key, []
    m.get(key).push x
    m
  ), new Map()

identity = (x) -> x  # local, non exporté
```

#### Fichier : `src/stdlib/array.coffee` (Phase 2 — inspiré Ramda)

```coffee
# --- Aplatissement ---
export flatten = (arr) -> arr.flat Infinity
export unnest  = (arr) -> arr.flat 1  # 1 niveau seulement (Ramda: unnest)

# --- scan : reduce qui retourne toutes les valeurs intermédiaires ---
# scan(add, 0, [1,2,3]) → [0, 1, 3, 6]
# scan(multiply, 1, [1..5]) → [1, 1, 2, 6, 24, 120]
export scan = (fn, acc, arr) ->
  result = [acc]
  for x in arr
    acc = fn acc, x
    result.push acc
  result

# --- Groupement consécutif (Ramda groupWith = Ruby chunk_while) ---
# groupWith(equals, [1,1,2,3,3]) → [[1,1],[2],[3,3]]
# groupWith((a,b) -> b-a is 1, [1,2,3,5,6,10]) → [[1,2,3],[5,6],[10]]
export groupWith = (pred, arr) ->
  return [] if arr.length is 0
  groups = []
  current = [arr[0]]
  for i in [1...arr.length]
    if pred arr[i-1], arr[i]
      current.push arr[i]
    else
      groups.push current
      current = [arr[i]]
  groups.push current
  groups

# --- Tri fonctionnel ---
export ascend  = (fn) -> (a, b) -> if fn(a) < fn(b) then -1 else if fn(a) > fn(b) then 1 else 0
export descend = (fn) -> (a, b) -> if fn(a) > fn(b) then -1 else if fn(a) < fn(b) then 1 else 0
export sortBy  = (fn, arr) -> [...arr].sort ascend fn

# --- Prédicats sur collections ---
export all   = (pred, arr) -> arr.every pred
export any   = (pred, arr) -> arr.some pred
export none  = (pred, arr) -> not arr.some pred
export count = (pred, arr) -> arr.filter(pred).length

# --- Slicing ---
export take      = (n, arr) -> arr.slice 0, n
export drop      = (n, arr) -> arr.slice n
export takeWhile = (pred, arr) -> arr.slice 0, arr.findIndex (x) -> not pred x
export dropWhile = (pred, arr) -> arr.slice arr.findIndex (x) -> not pred x

# --- Accesseurs idiomatiques ---
export head = (arr) -> arr[0]
export tail = (arr) -> arr.slice 1
export last = (arr) -> arr[arr.length - 1]
export init = (arr) -> arr.slice 0, -1

# --- Séparateur ---
export intersperse = (sep, arr) ->
  return arr if arr.length < 2
  result = [arr[0]]
  for i in [1...arr.length]
    result.push sep, arr[i]
  result

# --- Opérations ensemblistes ---
export intersection = (a, b) -> a.filter (x) -> b.includes x
export union        = (a, b) -> [...new Set [...a, ...b]]
export difference   = (a, b) -> a.filter (x) -> not b.includes x
export without      = (values, arr) -> arr.filter (x) -> not values.includes x

# --- Statistiques ---
export mean    = (arr) -> arr.reduce(((a, b) -> a + b), 0) / arr.length
export median  = (arr) ->
  sorted = [...arr].sort (a, b) -> a - b
  mid = Math.floor sorted.length / 2
  if sorted.length % 2 is 0
    (sorted[mid - 1] + sorted[mid]) / 2
  else
    sorted[mid]
export product = (arr) -> arr.reduce ((a, b) -> a * b), 1

# --- Génération ---
export range = (from, to) -> [from...to]  # [from, from+1, ..., to-1]

# --- Transformation ---
export transpose = (matrix) ->
  matrix[0].map (_, i) -> matrix.map (row) -> row[i]

export indexBy = (fn, arr) ->
  Object.fromEntries arr.map (x) -> [fn(x), x]

# collectBy : comme groupBy mais retourne array d'arrays, ordre préservé
export collectBy = (fn, arr) ->
  seen = []
  groups = new Map()
  for x in arr
    key = fn x
    unless groups.has key
      seen.push key
      groups.set key, []
    groups.get(key).push x
  seen.map (k) -> groups.get k

# dropRepeats : supprimer les répétitions consécutives
export dropRepeats = (arr) ->
  arr.filter (x, i) -> i is 0 or x isnt arr[i-1]

# xprod : produit cartésien
export xprod = (a, b) ->
  a.flatMap (x) -> b.map (y) -> [x, y]
```

#### Fichier : `src/stdlib/object.coffee` (nouveau — inspiré Ramda)

Utilitaires objet immutables. Pas de mutation, tout retourne un nouvel objet.

```coffee
# kawa/object — Utilitaires objet immutables, inspiré Ramda

# --- Accès ---

# Lire une propriété (curried : prop('name') retourne une fonction)
export prop    = (key, obj) -> obj[key]
export propOr  = (default_, key, obj) -> obj[key] ? default_

# Lire un chemin profond : path(['a','b'], {a:{b:1}}) → 1
export path    = (keys, obj) -> keys.reduce ((o, k) -> o?[k]), obj
export pathOr  = (default_, keys, obj) -> path(keys, obj) ? default_

# props(['a','b'], {a:1,b:2,c:3}) → [1, 2]
export props   = (keys, obj) -> keys.map (k) -> obj[k]

# --- Modification immutable ---

# assoc : ajouter/remplacer une clé sans muter
export assoc   = (key, val, obj) -> {...obj, [key]: val}

# dissoc : supprimer une clé sans muter
export dissoc  = (key, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k]) -> k isnt key

# --- Projection ---

# pick(['a','b'], {a:1,b:2,c:3}) → {a:1, b:2}
export pick    = (keys, obj) ->
  Object.fromEntries keys.filter((k) -> k of obj).map (k) -> [k, obj[k]]

# omit(['c'], {a:1,b:2,c:3}) → {a:1, b:2}
export omit    = (keys, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k]) -> k not in keys

# pickBy : pick selon prédicat sur la valeur
export pickBy  = (pred, obj) ->
  Object.fromEntries Object.entries(obj).filter ([k, v]) -> pred v, k

# --- Transformation ---

# evolve : transformer les valeurs selon un spec de fonctions
# evolve({price: multiply(1.2), name: trim}, product)
# Seules les clés présentes dans spec sont transformées
export evolve = (spec, obj) ->
  Object.fromEntries Object.entries(obj).map ([k, v]) ->
    [k, if typeof spec[k] is 'function' then spec[k](v) else v]

# merge : fusion simple (dernier écrase)
export merge      = (a, b) -> {...a, ...b}
export mergeLeft  = (a, b) -> {...b, ...a}
export mergeRight = (a, b) -> {...a, ...b}  # alias de merge

# mergeDeep : fusion récursive
# NOTE : utiliser `in` (pas `of`) car Object.entries retourne un Array
export mergeDeep = (a, b) ->
  result = {...a}
  for [k, v] in Object.entries b
    if typeof v is 'object' and v? and not Array.isArray(v) and typeof result[k] is 'object'
      result[k] = mergeDeep result[k], v
    else
      result[k] = v
  result

# --- Matching ---

# where : tester si un objet satisfait un spec de prédicats
# where({age: (n) -> n > 18, active: identity}, user)
export where   = (spec, obj) ->
  Object.entries(spec).every ([k, pred]) -> pred obj[k]

# whereEq : version simplifiée avec égalité stricte
export whereEq = (spec, obj) ->
  Object.entries(spec).every ([k, v]) -> obj[k] is v

# --- Conversion ---
export toPairs   = (obj) -> Object.entries obj
export fromPairs = (pairs) -> Object.fromEntries pairs
export keys      = (obj) -> Object.keys obj
export values    = (obj) -> Object.values obj

# mapKeys : transformer les clés
export mapKeys   = (fn, obj) ->
  Object.fromEntries Object.entries(obj).map ([k, v]) -> [fn(k), v]
```

> **Note sur `evolve` et `where`** — ce sont les deux fonctions les plus puissantes
> de ce module. Ensemble avec le pipe operator :
> ```coffee
> products
>   |> filter where {inStock: identity, category: (c) -> c is 'electronics'}
>   |> map evolve {price: multiply(1.2), name: capitalize}
>   |> sortBy prop 'price'
> ```

#### Fichier : `src/stdlib/string.coffee`

```coffee
# kawa/string — Utilitaires chaîne

# Découper en mots (whitespace quelconque)
export words = (s) -> s.trim().split /\s+/

# Découper en lignes
export lines = (s) -> s.split /\r?\n/

# Tronquer intelligemment avec ellipse
export truncate = (s, len, ellipsis = '…') ->
  if s.length <= len then s else s.slice(0, len - ellipsis.length) + ellipsis

# camelCase → snake_case
export underscore = (s) ->
  s
    .replace /([A-Z]+)([A-Z][a-z])/g, '$1_$2'
    .replace /([a-z\d])([A-Z])/g,     '$1_$2'
    .toLowerCase()

# snake_case / kebab-case → camelCase
export camelize = (s) ->
  s.replace /[-_](.)/g, (_, c) -> c.toUpperCase()

# kebab-case
export dasherize = (s) -> underscore(s).replace /_/g, '-'

# Capitaliser la première lettre
export capitalize = (s) -> s.charAt(0).toUpperCase() + s.slice 1
```

### 2d. Extensions prototype opt-in (`augment.coffee`)

**Philosophie** : ne jamais polluer les prototypes par défaut. L'import de ce module
est un **choix explicite**, à faire uniquement dans un point d'entrée applicatif
(jamais dans une bibliothèque publiée).

Utiliser `Object.defineProperty` avec `enumerable: false` pour éviter les problèmes `for...in`.

```coffee
# kawa/augment — Extensions prototype opt-in, style Ruby
# USAGE : import 'kawa/augment'  ← dans l'entrypoint uniquement

{compact, zip, sum, partition, chunk, windows, uniq, uniqBy,
 minBy, maxBy, tally, groupBy} = require './array'
{words, lines, truncate, underscore, camelize, dasherize, capitalize} = require './string'

def = (proto, name, fn) ->
  Object.defineProperty proto, name,
    value: fn, enumerable: no, writable: yes, configurable: yes

# Array
def Array::, 'compact',   -> compact @
def Array::, 'sum',       (fn) -> sum @, fn
def Array::, 'zip',       (others...) -> zip @, others...
def Array::, 'partition', (fn) -> partition @, fn
def Array::, 'chunk',     (n) -> chunk @, n
def Array::, 'windows',   (n) -> windows @, n
def Array::, 'uniq',      -> uniq @
def Array::, 'uniqBy',    (fn) -> uniqBy @, fn
def Array::, 'minBy',     (fn) -> minBy @, fn
def Array::, 'maxBy',     (fn) -> maxBy @, fn
def Array::, 'tally',     -> tally @
def Array::, 'groupBy',   (fn) -> groupBy @, fn

# String
def String::, 'words',      -> words @toString()
def String::, 'lines',      -> lines @toString()
def String::, 'truncate',   (len, ellipsis) -> truncate @toString(), len, ellipsis
def String::, 'underscore', -> underscore @toString()
def String::, 'camelize',   -> camelize @toString()
def String::, 'dasherize',  -> dasherize @toString()
def String::, 'capitalize', -> capitalize @toString()
```

Après `import 'kawa/augment'`, on peut écrire :

```coffee
[1, null, 2, undefined, 3].compact()          # → [1, 2, 3]
[1..10].chunk(3)                              # → [[1,2,3],[4,5,6],[7,8,9],[10]]
['foo', 'bar', 'foo'].tally()                 # → Map { 'foo' => 2, 'bar' => 1 }
'hello_world'.camelize()                      # → 'helloWorld'
```

> **Ne pas faire** : ajouter `augment` dans `index.coffee` ou l'importer depuis `fn.coffee`.
> Ce module ne doit jamais s'exécuter implicitement.

### 2e. Packaging de la stdlib

**Fichier** : `src/stdlib/index.coffee`

```coffee
export * from './fn'
export * from './array'
export * from './string'
export * from './object'
# augment est intentionnellement exclu — import explicite requis
```

**Ajouter au `package.json`** le champ `exports` :

```json
"exports": {
  ".":              "./lib/coffeescript/index.js",
  "./fn":           "./lib/stdlib/fn.js",
  "./array":        "./lib/stdlib/array.js",
  "./string":       "./lib/stdlib/string.js",
  "./object":       "./lib/stdlib/object.js",
  "./augment":      "./lib/stdlib/augment.js"
}
```

**Build** : ajouter `cake build:stdlib` dans `Cakefile` :

```coffee
task 'build:stdlib', 'Compile stdlib sources', ->
  exec "node bin/coffee -c -o lib/stdlib src/stdlib/"
```

---

## Checklist de livraison

### Suffixes d'identifiants
- [ ] `isEmpty?` est un identifiant valide, compile vers `isEmpty` en JS
- [ ] `reset!` est un identifiant valide, compile vers `reset` en JS
- [ ] `a?.b` reste l'opérateur existentiel soak (non affecté)
- [ ] `a? = 1` — `a?` comme LHS fonctionne
- [ ] Tous les tests `identifier_suffixes` passent
- [ ] Tests existants de l'opérateur `?` — 0 régression (opérateur existentiel intact)

### `kawa/fn` — Phase 1 (fondamentaux)
- [ ] `identity`, `always`, `compose`, `pipe`, `flip`, `curry`, `curryN`, `partial`, `partialRight`
- [ ] `memoize` avec `keyFn` composite — fonctionne sur arguments multiples
- [ ] `tap`, `complement`, `once`, `juxt`, `converge`

### `kawa/array` — Phase 1 (fondamentaux)
- [ ] `compact`, `zip`, `sum`, `partition`, `chunk`, `windows`, `uniq`, `uniqBy`
- [ ] `minBy`, `maxBy`, `tally`, `groupBy`
- [ ] `flatten`, `take`, `drop`, `head`, `tail`, `last`, `init`

### `kawa/array` — Phase 2 (inspiré Ramda)
- [ ] `scan` — reduce avec valeurs intermédiaires
- [ ] `groupWith` — grouper les consécutifs par prédicat (Ruby `chunk_while`)
- [ ] `sortBy`, `ascend`, `descend` — tri fonctionnel
- [ ] `all`, `any`, `none`, `count` — prédicats sur collections
- [ ] `takeWhile`, `dropWhile` — slicing conditionnel
- [ ] `intersection`, `union`, `difference`, `without` — opérations ensemblistes
- [ ] `intersperse`, `transpose`, `indexBy`, `collectBy`
- [ ] `mean`, `median`, `product` — statistiques de base
- [ ] `range` — séquence numérique curried

### `kawa/object` (nouveau — inspiré Ramda)
- [ ] `prop`, `propOr`, `path`, `pathOr` — accès immutable
- [ ] `assoc`, `dissoc` — modification immutable
- [ ] `pick`, `omit` — projection
- [ ] `evolve` — transformer les valeurs par spec
- [ ] `where` — tester un objet contre un spec de prédicats
- [ ] `toPairs`, `fromPairs`, `keys`, `values`, `mapKeys`

### `kawa/string`
- [ ] `words`, `lines`, `truncate`, `underscore`, `camelize`, `dasherize`, `capitalize`

### Augmentation des prototypes
- [ ] `import 'kawa/augment'` ajoute les méthodes sur `Array.prototype` / `String.prototype` avec `enumerable: false`

### Intégration
- [ ] `import {compose} from 'kawa/fn'` résout correctement depuis un projet KawaScript
- [ ] `import {compact} from 'kawa/array'` résout correctement
- [ ] `import {prop} from 'kawa/object'` résout correctement
- [ ] `node ./bin/cake test` — tous les tests passent
