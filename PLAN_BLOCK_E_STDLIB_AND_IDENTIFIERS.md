# Block E — Suffixes `?`/`!` sur Identifiants et Stdlib Fonctionnelle

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
import {compose, pipe, identity, always, flip, curry, partial, memoize} from 'kawa/fn'
```

Les fonctions sont elle-mêmes écrites en KawaScript.

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

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

# Ces tests importent les fonctions directement depuis le module
{compose, pipe, identity, always, flip, curry, partial, memoize} = require '../src/stdlib/fn'

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
  # compose(inc, double)(5) = inc(double(5)) = 11
  transform = compose inc, double
  eq transform(5), 11

test "compose — multiple functions", ->
  a = (x) -> x + 1
  b = (x) -> x * 2
  c = (x) -> x - 3
  # compose(c, b, a)(4) = c(b(a(4))) = c(b(5)) = c(10) = 7
  eq compose(c, b, a)(4), 7

test "pipe — left-to-right function composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  # pipe(double, inc)(5) = inc(double(5)) = 11
  transform = pipe double, inc
  eq transform(5), 11

test "flip — swaps first two arguments", ->
  sub = (a, b) -> a - b
  flippedSub = flip sub
  eq flippedSub(3, 10), 7   # sub(10, 3)

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

test "memoize — caches results by first argument", ->
  callCount = 0
  expensive = memoize (n) ->
    callCount += 1
    n * n
  eq expensive(5), 25
  eq expensive(5), 25
  eq callCount, 1  # only computed once
  eq expensive(6), 36
  eq callCount, 2
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

**Fichier** : `src/stdlib/fn.coffee` (nouveau fichier à créer)

```coffee
# kawa/fn — Bibliothèque fonctionnelle standard de KawaScript

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
      (moreArgs...) -> curried args.concat(moreArgs)...
  curried

export partial = (fn, partialArgs...) ->
  (remainingArgs...) -> fn partialArgs..., remainingArgs...

export memoize = (fn) ->
  cache = new Map()
  (arg, rest...) ->
    unless cache.has arg
      cache.set arg, fn arg, rest...
    cache.get arg
```

### 2d. Packaging de la stdlib

**Fichier** : `src/stdlib/index.coffee`

```coffee
export * from './fn'
```

**Ajouter au `package.json`** le champ `exports` pour permettre :

```json
"exports": {
  ".": "./lib/coffeescript/index.js",
  "./fn": "./lib/stdlib/fn.js"
}
```

**Build** : ajouter `cake build:stdlib` dans `Cakefile` pour compiler la stdlib :

```coffee
task 'build:stdlib', 'Compile stdlib sources', ->
  exec "node bin/coffee -c -o lib/stdlib src/stdlib/"
```

---

## Checklist de livraison

- [ ] `isEmpty?` est un identifiant valide, compile vers `isEmpty` en JS
- [ ] `reset!` est un identifiant valide, compile vers `reset` en JS
- [ ] `a?.b` reste l'opérateur existentiel soak (non affecté)
- [ ] `a? = 1` — `a?` comme LHS fonctionne
- [ ] Tous les tests `identifier_suffixes` passent
- [ ] `identity`, `always`, `compose`, `pipe`, `flip`, `curry`, `partial`, `memoize` — tous les tests passent
- [ ] `import {compose} from 'kawa/fn'` résout correctement depuis un projet KawaScript
- [ ] Tests existants de l'opérateur `?` — 0 régression (opérateur existentiel intact)
- [ ] `node ./bin/cake test` — tous les tests passent
