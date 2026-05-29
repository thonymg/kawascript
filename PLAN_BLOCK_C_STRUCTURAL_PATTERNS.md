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

test "array pattern — [head, ...tail] compiles to destructure", ->
  eqJS """
    f = (arr) ->
      match arr
        | [h, ...t] -> h
  """, """
    const f = function(arr) {
      const __m = arr;
      if (Array.isArray(__m) && __m.length >= 1) {
        const h = __m[0];
        const t = __m.slice(1);
        return h;
      }
    };
  """

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

## Étape 2 — Implémentation

### 2a. Nouvelles classes PatternNode

**Fichier** : `src/nodes.coffee`, après `OrPattern` (~ligne 6010)

#### `ArrayPattern`

```coffee
exports.ArrayPattern = class ArrayPattern extends PatternNode
  # [p1, p2, ...rest] or [p1, p2]
  constructor: (@elements, @restName = null) ->
    # @elements : array de PatternNode (sans le rest)
    # @restName : string ou null si pas de rest
    super()
  children: ['elements']

  compileTest: (o, subjectFrags) ->
    # Condition: Array.isArray(subject) && subject.length >= @elements.length
    lenCheck = if @restName?
      "#{@elements.length}"    # au moins N éléments
    else
      "#{@elements.length}"    # exactement N éléments
    strictLen = if @restName? then ">=" else "==="
    checks = [
      @makeCode "Array.isArray("
      subjectFrags...
      @makeCode ") && "
      subjectFrags...
      @makeCode ".length #{strictLen} #{lenCheck}"
    ]
    # Sub-patterns : vérifier chaque élément positionnel
    for pat, i in @elements when pat not instanceof BindingPattern or pat.isWildcard() is no
      elemFrags = [subjectFrags..., @makeCode("[#{i}]")]
      subCheck = pat.compileTest o, elemFrags
      checks.push @makeCode(" && "), subCheck...
    checks

  bindings: ->
    result = []
    for pat, i in @elements
      result.push pat.bindings()...
    result.push @restName if @restName?
    result

  compileBindings: (o, subjectFrags) ->
    # Génère les déclarations de liaison : const h = s[0]; const t = s.slice(1);
    frags = []
    idt = o.indent
    for pat, i in @elements
      for name in pat.bindings()
        frags.push @makeCode "#{idt}const #{name} = "
        frags.push subjectFrags...
        frags.push @makeCode "[#{i}];\n"
    if @restName?
      frags.push @makeCode "#{idt}const #{@restName} = "
      frags.push subjectFrags...
      frags.push @makeCode ".slice(#{@elements.length});\n"
    frags
```

#### `ObjectPattern`

```coffee
exports.ObjectPattern = class ObjectPattern extends PatternNode
  # {key: pattern, key2, ...}
  # @pairs : [{key: string, pattern: PatternNode, exact: val|null}]
  constructor: (@pairs) -> super()

  compileTest: (o, subjectFrags) ->
    # subject != null && typeof subject === 'object'
    checks = [
      subjectFrags...
      @makeCode " != null && typeof "
      subjectFrags...
      @makeCode " === 'object'"
    ]
    for {key, pattern, exact} in @pairs
      propFrags = [subjectFrags..., @makeCode ".#{key}"]
      if exact?
        checks.push @makeCode " && "
        checks.push propFrags...
        checks.push @makeCode " === #{JSON.stringify exact}"
      else if pattern not instanceof BindingPattern
        checks.push @makeCode " && "
        checks.push pattern.compileTest(o, propFrags)...
    checks

  bindings: ->
    result = []
    for {key, pattern} in @pairs when not pattern?.exact?
      result.push pattern?.bindings?() or [key]...
    result

  compileBindings: (o, subjectFrags) ->
    frags = []
    idt = o.indent
    for {key, pattern} in @pairs when not pattern?.exact?
      for name in (pattern?.bindings?() or [key])
        frags.push @makeCode "#{idt}const #{name} = "
        frags.push subjectFrags...
        frags.push @makeCode ".#{key};\n"
    frags
```

#### `RangePattern`

```coffee
exports.RangePattern = class RangePattern extends PatternNode
  constructor: (@from, @to, @exclusive = no) -> super()
  children: ['from', 'to']

  compileTest: (o, subjectFrags) ->
    fromFrags = @from.compileToFragments o, LEVEL_PAREN
    toFrags   = @to.compileToFragments   o, LEVEL_PAREN
    upperOp   = if @exclusive then '<' else '<='
    [
      subjectFrags...
      @makeCode ' >= '
      fromFrags...
      @makeCode " && "
      subjectFrags...
      @makeCode " #{upperOp} "
      toFrags...
    ]

  bindings: -> []
```

#### `TypePattern`

```coffee
exports.TypePattern = class TypePattern extends PatternNode
  constructor: (@typeName) -> super()

  compileTest: (o, subjectFrags) ->
    typeFrags = @typeName.compileToFragments o, LEVEL_ACCESS
    [subjectFrags..., @makeCode(' instanceof '), typeFrags...]

  bindings: -> []
```

### 2b. Mettre à jour `MatchArm.injectBindings`

`MatchArm.injectBindings` appelle actuellement `@pattern.bindings()` et génère
`const name = subject;`. Pour les patterns structuraux, les bindings sont plus complexes
(e.g. `const h = s[0]; const t = s.slice(1)`). Les PatternNodes qui ont une méthode
`compileBindings` doivent être utilisés à la place.

**Fichier** : `src/nodes.coffee`, méthode `MatchArm.injectBindings` :

```diff
  injectBindings: (o, subjectFrags) ->
    fragments = []
-   for name in @pattern.bindings()
-     fragments = fragments.concat(
-       [@makeCode "#{o.indent}const #{name} = "],
-       subjectFrags,
-       [@makeCode ';\n']
-     )
+   if @pattern.compileBindings?
+     fragments = fragments.concat @pattern.compileBindings(o, subjectFrags)
+   else
+     for name in @pattern.bindings()
+       fragments = fragments.concat(
+         [@makeCode "#{o.indent}const #{name} = "],
+         subjectFrags,
+         [@makeCode ';\n']
+       )
    fragments.concat @body.compileToFragments o, LEVEL_TOP
```

### 2c. Règles grammaticales

**Fichier** : `src/grammar.coffee`

Dans la règle `MatchPattern` (section du `match`), ajouter après les règles Phase 1 :

```coffee
# Tableau exact : [0, 1, 2]
o 'ARRAY_START MatchPatternList ARRAY_END',
  -> new ArrayPattern $2, null

# Tableau avec rest : [h, ...t]
o 'ARRAY_START MatchPatternList , ... IDENTIFIER ARRAY_END',
  -> new ArrayPattern $2, $5

# Tableau : [h] ou [h, ...t] — toutes variantes via ArrayLiteral grammar
o 'ARRAY_START MatchPatternListOpt ARRAY_END', -> new ArrayPattern $2

# Objet : {x, y} ou {type: "circle", r}
o 'OBJECT_PARAM',         -> buildObjectPattern $1

# Plage inclusive : 1..10
o 'Expression .. Expression', -> new RangePattern $1, $3, no

# Plage exclusive : 1...10
o 'Expression ... Expression', -> new RangePattern $1, $3, yes

# instanceof : instanceof Error
o 'INSTANCEOF Expression', -> new TypePattern $2
```

> **Note** : Les règles exactes dépendent du contexte de priorité dans Jison.
> Commencer par les cas simples et ajouter des règles supplémentaires si des conflits shift/reduce apparaissent.
> Utiliser `%prec` si nécessaire.

### 2d. Règle `MatchPatternList`

Pour les patterns de tableau, ajouter une règle qui liste des patterns séparés par `,` :

```coffee
MatchPatternList: [
  o 'MatchPattern',                              -> [$1]
  o 'MatchPatternList , MatchPattern',            -> $1.concat [$3]
]
```

### 2e. Construire les ObjectPatterns depuis la grammaire

Ajouter une fonction `buildObjectPattern` dans `grammar.coffee` :

```coffee
buildObjectPattern = (obj) ->
  pairs = for prop in obj.properties
    if prop instanceof Assign and prop.context is 'object'
      # {key: Pattern}
      key = prop.variable.base.value
      val = prop.value
      if val instanceof LiteralPattern or val instanceof StringLiteral or val instanceof NumberLiteral
        {key, pattern: new LiteralPattern(val), exact: null}
      else if val instanceof Value and val.base instanceof IdentifierLiteral
        {key, pattern: new BindingPattern(val.base.value), exact: null}
      else
        {key, pattern: new BindingPattern(key), exact: null}
    else
      # Shorthand {x} → bind to name x
      key = prop.base?.value or prop.value
      {key, pattern: new BindingPattern(key), exact: null}
  new ObjectPattern pairs
```

---

## Checklist de livraison

- [ ] Tests "array pattern exact" passent
- [ ] Tests "array pattern avec rest" passent
- [ ] Tests "object pattern basic" passent
- [ ] Tests "range pattern" passent
- [ ] Tests "instanceof pattern" passent
- [ ] Tests "nested patterns" passent
- [ ] Tests Phase 1 existants — 0 régression
- [ ] `node ./bin/cake test` — tous les tests passent
