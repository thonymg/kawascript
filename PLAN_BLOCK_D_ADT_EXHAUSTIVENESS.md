# Block D — Types Algébriques de Données (ADT) et Exhaustivité

## Prérequis

- **Block A complété** : le compilateur doit bootstrapper.
- **Block C complété** : patterns structuraux doivent fonctionner (les patterns de constructeur en dépendent).

## Spécification

Les ADT en KawaScript permettent de déclarer des types à somme typés :

```coffee
type Shape
  | Circle { r }
  | Square { side }
  | Rect   { width, height }

# Utilisation dans match (exhaustive)
area = (shape) ->
  match shape
    | Circle {r}         -> Math.PI * r * r
    | Square {side}      -> side * side
    | Rect   {width, height} -> width * height

# Création
s = Circle {r: 5}
```

**Exhaustivité** : si tous les constructeurs du type sont couverts, le compilateur n'émet pas
d'avertissement. Sinon : erreur de compilation.

> Ce block est le plus exploratoire. Les décisions architecturales suivantes s'imposeront
> peut-être lors de l'implémentation. Le plan décrit l'architecture cible.

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

### Fichier : `test/pattern_matching.coffee`

Ajouter après les tests Block C :

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — ADT ET EXHAUSTIVITÉ
# ─────────────────────────────────────────────────────────────────────────────

# --- Déclaration et utilisation basiques ---

test "ADT — type declaration creates constructor functions", ->
  # type Color | Red | Green | Blue
  # Doit produire : const Red = {__tag: "Red"}; ...
  eqJS """
    type Color
      | Red
      | Green
      | Blue
  """, """
    const Red   = Object.freeze({__tag: 'Red'   , __type: 'Color'});
    const Green = Object.freeze({__tag: 'Green' , __type: 'Color'});
    const Blue  = Object.freeze({__tag: 'Blue'  , __type: 'Color'});
  """

test "ADT — constructor with data creates tagged value", ->
  # type Shape | Circle {r} | Square {side}
  eqJS """
    type Shape
      | Circle {r}
      | Square {side}
  """, """
    const Circle = function({r}) { return Object.freeze({__tag: 'Circle', __type: 'Shape', r}); };
    const Square = function({side}) { return Object.freeze({__tag: 'Square', __type: 'Shape', side}); };
  """

test "ADT — constructor call creates frozen tagged object", ->
  # Requires type declaration above or separate setup
  # Using inline approach:
  Circle = ({r}) -> Object.freeze {__tag: 'Circle', __type: 'Shape', r}
  c = Circle {r: 5}
  eq c.r, 5
  eq c.__tag, 'Circle'
  throws (-> c.r = 10), /Cannot assign to read only|object is not extensible/i

test "ADT — match on constructor tag", ->
  Circle = ({r}) -> {__tag: 'Circle', r}
  Square = ({side}) -> {__tag: 'Square', side}

  area = (shape) ->
    match shape
      | Circle {r}    -> Math.PI * r * r
      | Square {side} -> side * side
      | _             -> 0

  ok Math.abs(area(Circle {r: 1}) - Math.PI) < 0.0001
  eq area(Square {side: 4}), 16

# --- Exhaustivité ---

test "ADT — exhaustive match compiles without default arm", ->
  # All 2 constructors of Color covered → no error
  ok (-> CoffeeScript.compile("""
    type Color | Red | Green | Blue
    f = (c) ->
      match c
        | Red   -> 'red'
        | Green -> 'green'
        | Blue  -> 'blue'
  """))()  # Should not throw

test "ADT — non-exhaustive match with no wildcard throws compile error", ->
  throws (-> CoffeeScript.compile("""
    type Color | Red | Green | Blue
    f = (c) ->
      match c
        | Red   -> 'red'
        | Green -> 'green'
  """)), /non-exhaustive|missing.*Blue/i

test "ADT — non-exhaustive match with wildcard is OK", ->
  ok (-> CoffeeScript.compile("""
    type Color | Red | Green | Blue
    f = (c) ->
      match c
        | Red -> 'red'
        | _   -> 'other'
  """))()

# --- Constructeurs avec données ---

test "ADT — data constructor match binds fields", ->
  Circle = ({r}) -> {__tag: 'Circle', r}
  Point  = ({x, y}) -> {__tag: 'Point', x, y}

  describePoint = (shape) ->
    match shape
      | Point {x, y} -> "#{x},#{y}"
      | _             -> "not a point"

  eq describePoint(Point {x: 3, y: 4}), "3,4"
```

---

## Étape 2 — Implémentation

### 2a. Nouveau token `TYPE` (mot-clé)

**Fichier** : `src/lexer.coffee`

Ajouter `'type'` au tableau `RESERVED` / `KEYWORDS` :

```diff
# Dans la liste des mots-clés réservés
COFFEE_KEYWORDS = ['true', 'false', 'null', 'this', ..., 'match', 'type']
```

**Important** : Comme pour `match`, vérifier qu'il n'existe pas d'usage de `type` comme
variable dans les fichiers `src/*.coffee`. Si `type` est déjà utilisé comme identifiant
dans le code source du compilateur, appliquer la même stratégie de renommage que pour `match`
(voir Block A).

### 2b. Registre global des types ADT

**Fichier** : `src/helpers.coffee`

Ajouter un `typeRegistry` : un `Map<typeName, Set<constructorName>>` accessible
globalement pendant la compilation.

```coffee
exports.typeRegistry = typeRegistry = new Map()

exports.registerType = (typeName, constructors) ->
  typeRegistry.set typeName, new Set(constructors)

exports.lookupType = (typeName) ->
  typeRegistry.get typeName

exports.clearTypeRegistry = ->
  typeRegistry.clear()
```

> `clearTypeRegistry` doit être appelé en début de chaque compilation (`CoffeeScript.compile`).

### 2c. Nœud `TypeDeclaration`

**Fichier** : `src/nodes.coffee`

```coffee
#### TypeDeclaration

# `type Shape | Circle {r} | Square {side}`
# Chaque entrée est un `TypeVariant` : {name, fields}
exports.TypeDeclaration = class TypeDeclaration extends Base
  constructor: (@typeName, @variants) -> super()
  children: ['variants']
  isStatement: YES
  makeReturn: THIS

  compileNode: (o) ->
    # Enregistrer le type dans le registre global
    constructorNames = (v.name for v in @variants)
    registerType @typeName, constructorNames
    
    frags = []
    for variant in @variants
      if variant.fields.length is 0
        # Pas de données : constante tagged
        frags.push @makeCode "#{@tab}const #{variant.name} = Object.freeze({__tag: '#{variant.name}', __type: '#{@typeName}'});\n"
      else
        # Avec données : fonction constructeur
        fieldList = variant.fields.join ', '
        fieldAssign = (f -> "#{f}").join(', ')
        frags.push @makeCode "#{@tab}const #{variant.name} = function({#{fieldList}}) { return Object.freeze({__tag: '#{variant.name}', __type: '#{@typeName}', #{fieldAssign}}); };\n"
    frags

exports.TypeVariant = class TypeVariant extends Base
  constructor: (@name, @fields = []) -> super()
```

### 2d. Pattern de constructeur `ConstructorPattern`

**Fichier** : `src/nodes.coffee`

```coffee
exports.ConstructorPattern = class ConstructorPattern extends PatternNode
  constructor: (@tag, @innerPattern = null) -> super()
  # @tag : string (nom du constructeur, ex: "Circle")
  # @innerPattern : ObjectPattern ou null

  compileTest: (o, subjectFrags) ->
    tagCheck = [
      subjectFrags...
      @makeCode "?.__tag === '#{@tag}'"
    ]
    return tagCheck unless @innerPattern?
    innerCheck = @innerPattern.compileTest o, subjectFrags
    [tagCheck..., @makeCode(' && '), innerCheck...]

  bindings: ->
    @innerPattern?.bindings() or []

  compileBindings: (o, subjectFrags) ->
    @innerPattern?.compileBindings?(o, subjectFrags) or []
```

### 2e. Règles grammaticales

**Fichier** : `src/grammar.coffee`

```coffee
# Déclaration de type
TypeDeclaration: [
  o 'TYPE IDENTIFIER INDENT TypeVariantList OUTDENT',
    -> new TypeDeclaration $2, $4
  o 'TYPE IDENTIFIER TypeVariantList',
    -> new TypeDeclaration $2, $3
]

TypeVariantList: [
  o 'MATCH_PIPE IDENTIFIER',
    -> [new TypeVariant $2, []]
  o 'MATCH_PIPE IDENTIFIER OBJECT_PARAM',
    -> [new TypeVariant $2, (k for k in $3.keys())]
  o 'TypeVariantList MATCH_PIPE IDENTIFIER',
    -> $1.concat [new TypeVariant $3, []]
  o 'TypeVariantList MATCH_PIPE IDENTIFIER OBJECT_PARAM',
    -> $1.concat [new TypeVariant $3, (k for k in $4.keys())]
]
```

Dans `MatchPattern` (patterns du `match`), ajouter :

```coffee
o 'IDENTIFIER OBJECT_PARAM', -> new ConstructorPattern $1, buildObjectPattern($2)
o 'IDENTIFIER',              -> new ConstructorPattern $1   # si précédé d'un type connu
```

> **Note** : La règle `IDENTIFIER` pour `ConstructorPattern` peut entrer en conflit avec
> `BindingPattern`. La solution : une vérification sémantique post-parse. Pendant la compilation
> de `MatchNode`, vérifier si l'identifiant est dans le registre des constructeurs ADT.
> Si oui → `ConstructorPattern`. Sinon → `BindingPattern` (comportement actuel).

### 2f. Vérification d'exhaustivité dans `MatchNode.compileNode`

**Fichier** : `src/nodes.coffee`, méthode `MatchNode.compileNode`

```diff
  compileNode: (o) ->
    # ...compilation existante...
    
+   # Vérification d'exhaustivité
+   hasWildcard = @arms.some (arm) -> arm.pattern instanceof BindingPattern and arm.pattern.isWildcard()
+   unless hasWildcard
+     # Chercher si le sujet est d'un type ADT connu
+     # (Heuristique: vérifier les patterns ConstructorPattern et leur __type)
+     coveredTags = new Set(@arms
+       .filter((arm) -> arm.pattern instanceof ConstructorPattern)
+       .map((arm) -> arm.pattern.tag))
+     for tag in coveredTags
+       typeName = lookupConstructorType tag
+       if typeName
+         allConstructors = lookupType typeName
+         for ctorName in allConstructors
+           unless coveredTags.has ctorName
+             @error "non-exhaustive match: missing case for '#{ctorName}'"
```

> `lookupConstructorType` est une fonction de `helpers.coffee` qui fait l'inverse de `lookupType` :
> étant donné un nom de constructeur, retourne le nom du type ADT.

---

## Checklist de livraison

- [ ] `type Color | Red | Green | Blue` compile vers les constantes gelées correctes
- [ ] `type Shape | Circle {r}` compile vers la fonction constructeur correcte
- [ ] Pattern `Circle {r}` dans `match` : tag check + bindings
- [ ] Exhaustivité : match complet → pas d'erreur
- [ ] Exhaustivité : match incomplet sans wildcard → erreur de compilation
- [ ] Wildcard `_` supprime la vérification d'exhaustivité
- [ ] Tests Phase 1 et Phase 2 — 0 régression
- [ ] `node ./bin/cake test` — tous les tests passent
