# Block C — Patterns Structuraux (Phase 2 du Pattern Matching)

## Prérequis

- **Block A complété** : le compilateur doit bootstrapper correctement.
- Phase 1 déjà implémentée : `LiteralPattern`, `BindingPattern`, `OrPattern`, `MatchArm`, `MatchNode`.

## Statut actuel

| Pattern | État |
|---------|------|
| Littéral, wildcard, liaison, guard, or-pattern | ✅ Phase 1 — implémenté |
| `[head, ...tail]`, `[0, 1, 2]` | ❌ Phase 2 — non implémenté |
| `{x, y}`, `{type: "circle", r}` | ❌ Phase 2 — non implémenté |
| `1..10` | ❌ Phase 2 — non implémenté |
| `instanceof Error` | ❌ Phase 2 — non implémenté |
| Patterns imbriqués | ❌ Phase 2 — non implémenté |

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

### Fichier : `test/pattern_matching.coffee`

Ajouter après les tests Phase 1 existants :

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — PATTERNS STRUCTURAUX
# ─────────────────────────────────────────────────────────────────────────────

# --- Tableau exact ---

test "array pattern — exact match [0, 1]", ->
  classify = (arr) ->
    match arr
      | [0, 1] -> "zero-one"
      | [1, 0] -> "one-zero"
      | _      -> "other"
  eq classify([0, 1]), "zero-one"
  eq classify([1, 0]), "one-zero"
  eq classify([2, 3]), "other"

test "array pattern — empty array []", ->
  isEmpty = (arr) ->
    match arr
      | [] -> yes
      | _  -> no
  eq isEmpty([]), yes
  eq isEmpty([1]), no

test "array pattern — length mismatch returns false", ->
  f = (arr) ->
    match arr
      | [0, 1, 2] -> yes
      | _         -> no
  eq f([0, 1]), no
  eq f([0, 1, 2]), yes

# --- Tableau avec rest ---

test "array pattern — [head, ...tail] destructuring", ->
  getHead = (arr) ->
    match arr
      | [h, ...t] -> h
      | []        -> null
  eq getHead([1, 2, 3]), 1
  eq getHead([]), null

test "array pattern — [...init, last] destructuring", ->
  getLast = (arr) ->
    match arr
      | [...i, l] -> l
      | []        -> null
  eq getLast([1, 2, 3]), 3

# --- Objet ---

test "object pattern — {x, y} matches and binds", ->
  area = (shape) ->
    match shape
      | {width, height} -> width * height
      | _               -> 0
  eq area({width: 3, height: 4}), 12
  eq area({}), 0

test "object pattern — {type: 'circle', r} specific value + binding", ->
  perimeter = (shape) ->
    match shape
      | {type: "circle", r}    -> 2 * Math.PI * r
      | {type: "square", side} -> 4 * side
      | _                      -> 0
  ok Math.abs(perimeter({type: "circle", r: 1}) - 2 * Math.PI) < 0.0001
  eq perimeter({type: "square", side: 5}), 20

test "object pattern — extra keys in subject don't break match", ->
  getName = (obj) ->
    match obj
      | {name} -> name
      | _      -> "unknown"
  eq getName({name: "Alice", age: 30}), "Alice"

# --- Plage ---

test "range pattern — 1..10 matches integers in range", ->
  category = (n) ->
    match n
      | 1..10  -> "small"
      | 11..100 -> "medium"
      | _      -> "large"
  eq category(5),   "small"
  eq category(50),  "medium"
  eq category(500), "large"

test "range pattern — exclusive range 1...10", ->
  f = (n) ->
    match n
      | 1...10 -> "exclusive"
      | _      -> "no"
  eq f(1),  "exclusive"
  eq f(9),  "exclusive"
  eq f(10), "no"

# --- instanceof ---

test "instanceof pattern — matches by type", ->
  describe = (e) ->
    match e
      | instanceof TypeError  -> "type error"
      | instanceof RangeError -> "range error"
      | instanceof Error      -> "generic error"
      | _                     -> "not an error"
  eq describe(new TypeError("t")),  "type error"
  eq describe(new RangeError("r")), "range error"
  eq describe(new Error("e")),      "generic error"
  eq describe("str"),               "not an error"

# --- Patterns imbriqués ---

test "nested pattern — {items: [first, ...rest]}", ->
  getFirst = (obj) ->
    match obj
      | {items: [f, ...r]} -> f
      | _                  -> null
  eq getFirst({items: [1, 2, 3]}), 1
  eq getFirst({items: []}),        null
  eq getFirst({}),                 null

test "nested pattern — [[a, b], c]", ->
  f = (arr) ->
    match arr
      | [[a, b], c] -> a + b + c
      | _           -> 0
  eq f([[1, 2], 3]), 6

# --- Guards avec patterns structuraux ---

test "array pattern with guard", ->
  f = (arr) ->
    match arr
      | [h, ...t] if h > 0 -> "positive head"
      | [h, ...t]          -> "non-positive head"
      | _                  -> "empty"
  eq f([5, 1, 2]),  "positive head"
  eq f([-1, 2, 3]), "non-positive head"
  eq f([]),         "empty"
```

---

## Pourquoi le plan original était problématique

Trois bugs bloquants identifiés à l'analyse :

1. **Token `OBJECT_PARAM` inexistant** — n'est défini ni dans le lexer ni dans la grammar. Le parser refuse de se compiler.
2. **`buildObjectPattern` inaccessible au runtime** — les helpers définis dans `grammar.coffee` ne sont disponibles qu'à la génération du parser (phase de build). La fonction `o()` transforme les actions en strings JS exécutées dans le contexte Jison (`yy.*`). `buildObjectPattern($1)` serait un symbole indéfini à l'exécution.
3. **Substitution de guard cassée** — pour `| [h, ...t] if h > 0 ->`, le code actuel substitue `h → __m` (le sujet entier). Il aurait fallu `h → __m[0]`. La méthode `compileBindings()` proposée ne corrige pas ça car elle n'est pas intégrée dans la logique de `compileArm`.

De plus, la règle `MatchPatternList` crée des conflits shift/reduce potentiels avec `MatchPattern , MatchPattern` (OrPattern).

---

## Étape 2 — Implémentation

### Principe

- **Zéro nouveau token, zéro nouvelle règle intermédiaire** : les règles grammar existantes `Array`, `Object`, `Literal` sont réutilisées directement.
- **`bindingAccessors()` au lieu de `compileBindings()`** : les patterns structuraux exposent une map `{name → accessorSuffix}` utilisée à la fois par `injectBindings` et la substitution de guard — les deux restent cohérents.

```
ArrayPattern [h, ...t]        → { h: '[0]',      t: '.slice(1)' }
ObjectPattern {width, height} → { width: '.width', height: '.height' }
```

---

### 2a. Nouvelles classes PatternNode

**Fichier** : `src/nodes.coffee`, après `OrPattern` (~ligne 6010)

#### `ArrayPattern`

Reçoit un nœud `Arr` existant et l'interprète à la volée comme pattern.

```coffee
exports.ArrayPattern = class ArrayPattern extends PatternNode
  constructor: (@arr) -> super()
  children: ['arr']

  _parseSingle: (node) ->
    base = if node instanceof Value and not node.properties.length then node.base else node
    if base instanceof IdentifierLiteral then new BindingPattern base.value
    else if base instanceof Arr          then new ArrayPattern base
    else if base instanceof Obj          then new ObjectPattern base
    else                                      new LiteralPattern base

  _parse: ->
    elements = []; restName = null
    for el in @arr.objects
      if el instanceof Splat
        b = el.name; b = b.base if b instanceof Value
        restName = b.value
      else elements.push @_parseSingle el
    {elements, restName}

  compileTest: (o, subjectFrags) ->
    {elements, restName} = @_parse()
    s = (f.code for f in subjectFrags).join ''
    op = if restName? then '>=' else '==='
    result = [@makeCode "Array.isArray(#{s}) && #{s}.length #{op} #{elements.length}"]
    for pat, i in elements when pat not instanceof BindingPattern
      result.push @makeCode ' && '
      result = result.concat pat.compileTest(o, [@makeCode "#{s}[#{i}]"])
    result

  bindingAccessors: ->
    {elements, restName} = @_parse()
    acc = {}
    for pat, i in elements when pat instanceof BindingPattern and not pat.isWildcard()
      acc[pat.name] = "[#{i}]"
    acc[restName] = ".slice(#{elements.length})" if restName?
    acc

  bindings: ->
    {elements, restName} = @_parse()
    names = (pat.name for pat in elements when pat instanceof BindingPattern and not pat.isWildcard())
    names.push restName if restName?; names
```

#### `ObjectPattern`

Reçoit un nœud `Obj` existant et l'interprète à la volée comme pattern.

```coffee
exports.ObjectPattern = class ObjectPattern extends PatternNode
  constructor: (@obj) -> super()
  children: ['obj']

  _parse: ->
    for prop in @obj.properties
      if prop instanceof Assign and prop.context is 'object'
        key = prop.variable.base.value
        valBase = prop.value
        valBase = valBase.base if valBase instanceof Value and not valBase.properties.length
        if valBase instanceof IdentifierLiteral
          {key, binding: valBase.value, exact: null}
        else
          {key, binding: null, exact: valBase}
      else
        k = (if prop instanceof Value then prop.base else prop).value
        {key: k, binding: k, exact: null}

  compileTest: (o, subjectFrags) ->
    s = (f.code for f in subjectFrags).join ''
    result = [@makeCode "#{s} != null && typeof #{s} === 'object'"]
    for {key, binding, exact} in @_parse()
      if exact?
        result.push @makeCode " && #{s}.#{key} === "
        result = result.concat exact.compileToFragments(o, LEVEL_PAREN)
      else if binding?
        result.push @makeCode " && '#{key}' in #{s}"
    result

  bindingAccessors: ->
    acc = {}
    for {key, binding} in @_parse() when binding?
      acc[binding] = ".#{key}"
    acc

  bindings: -> (p.binding for p in @_parse() when p.binding?)
```

> `'key' in subject` vérifie que la clé existe réellement → `area({})` retourne 0 correctement.

#### `RangePattern`

```coffee
exports.RangePattern = class RangePattern extends PatternNode
  constructor: (@from, @to, @exclusive = no) -> super()
  children: ['from', 'to']

  compileTest: (o, subjectFrags) ->
    fromFrags = @from.compileToFragments o, LEVEL_PAREN
    toFrags   = @to.compileToFragments   o, LEVEL_PAREN
    upperOp   = if @exclusive then '<' else '<='
    [].concat(
      subjectFrags, [@makeCode ' >= '],
      fromFrags,
      [@makeCode " && "],
      subjectFrags, [@makeCode " #{upperOp} "],
      toFrags
    )

  bindings: -> []
```

#### `TypePattern`

```coffee
exports.TypePattern = class TypePattern extends PatternNode
  constructor: (@typeName) -> super()
  children: ['typeName']

  compileTest: (o, subjectFrags) ->
    typeFrags = @typeName.compileToFragments o, LEVEL_ACCESS
    [].concat subjectFrags, [@makeCode ' instanceof '], typeFrags

  bindings: -> []
```

---

### 2b. Mettre à jour `MatchArm.injectBindings`

**Fichier** : `src/nodes.coffee`, méthode `MatchArm.injectBindings`

```diff
  injectBindings: (o, subjectFrags) ->
    fragments = []
+   if @pattern.bindingAccessors?
+     subjectCode = (f.code for f in subjectFrags).join ''
+     for own name, acc of @pattern.bindingAccessors()
+       fragments.push @makeCode "#{o.indent}const #{name} = #{subjectCode}#{acc};\n"
+   else
    for name in @pattern.bindings()
      fragments = fragments.concat(
        [@makeCode "#{o.indent}const #{name} = "],
        subjectFrags,
        [@makeCode ';\n']
      )
    fragments.concat @body.compileToFragments o, LEVEL_TOP
```

---

### 2c. Corriger la substitution de guard dans `MatchArm.compileArm`

**Fichier** : `src/nodes.coffee`, méthode `MatchArm.compileArm`

```diff
      bindings = @pattern.bindings()
-     if bindings.length > 0
+     accessors = @pattern.bindingAccessors?() or null
+     if accessors? or bindings.length > 0
        subjectCode = (f.code for f in subjectFrags).join ''
        guardFrags = for f in guardFrags
          unless f.code
            f
          else
            let code = f.code
-           for name in bindings
-             code = code.replace new RegExp("\\b#{name}\\b", 'g'), subjectCode
+           if accessors?
+             for own name, acc of accessors
+               code = code.replace new RegExp("\\b#{name}\\b", 'g'), subjectCode + acc
+           else
+             for name in bindings
+               code = code.replace new RegExp("\\b#{name}\\b", 'g'), subjectCode
            Object.assign Object.create(Object.getPrototypeOf(f)), f, {code}
        condFrags = [].concat condFrags, [@makeCode ' && '], guardFrags
```

---

### 2d. Règles grammaticales

**Fichier** : `src/grammar.coffee`

Dans la règle `MatchPattern`, ajouter **4 lignes** après les règles Phase 1 :

```diff
  MatchPattern: [
    o 'Literal',                             -> new LiteralPattern $1
    o 'IDENTIFIER',                          -> new BindingPattern $1
    o 'MatchPattern , MatchPattern',         -> new OrPattern $1, $3
+   o 'Array',                               -> new ArrayPattern $1
+   o 'Object',                              -> new ObjectPattern $1
+   o 'Literal RangeDots Literal',           -> new RangePattern $1, $3, $2.exclusive
+   o 'RELATION Value',                      -> new TypePattern $2
  ]
```

**Pourquoi ces règles sont sûres :**

- `Array` et `Object` : règles existantes, pas de nouveau token. L'`Arr`/`Obj` parsé est passé directement au constructeur — l'interprétation se fait dans `_parse()` à la compilation.
- `Literal RangeDots Literal` : `..` n'est pas dans `FOLLOW(MatchPattern)` → aucun conflit shift/reduce avec la réduction `Literal → MatchPattern`.
- `RELATION Value` : capture `instanceof Foo` via le token `RELATION` déjà existant (même token que `x instanceof y`). Aucun nouveau token.

Aucune fonction helper dans `grammar.coffee`, aucune nouvelle règle intermédiaire.

---

## Checklist de livraison

- [x] Tests "array pattern exact" passent
- [x] Tests "array pattern avec rest" passent
- [x] Tests "object pattern basic" passent
- [x] Tests "range pattern" passent
- [x] Tests "instanceof pattern" passent
- [x] Tests "nested patterns" passent
- [x] Tests "guard avec pattern structurel" passent
- [x] Tests Phase 1 existants — 0 régression
- [x] `node ./bin/cake test` — 1645 tests passent (2026-05-30)
