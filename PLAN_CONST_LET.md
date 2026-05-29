# Plan de refactorisation : Immutabilité totale

> **Philosophie** : Le compilateur applique un modèle **copy-on-write** systématique.
> Aucune structure (variable, tableau, objet) n'est jamais modifiée en place.
> Toute "modification" produit une nouvelle copie. La mutabilité est un contrat
> explicite (`let`), pas un comportement par défaut.

---

## Les trois piliers

| Pilier | Règle | Mot-clé / mécanisme |
|--------|-------|---------------------|
| **Variables** | Immuables par défaut | `const` implicite, `let` explicite |
| **Tableaux** | Gelés à la création, mutations → nouvelle copie | `Object.freeze()` + spread |
| **Objets** | Gelés à la création, mutations → nouvelle copie | `Object.freeze()` + spread |

---

## Cartographie complète des mutations à traiter

### Variables

| Situation CoffeeScript | Comportement actuel | Nouveau comportement |
|------------------------|--------------------|-----------------------|
| `x = 1` | `var x; x = 1` | `const x = 1` |
| `let x = 1` | *(nouveau mot-clé)* | `let x = 1` |
| `x = 1` puis `x = 2` | `var x; x=1; x=2` | **CompileError** : `x` est const |
| `let x = 1` puis `x = 2` | *(nouveau)* | `let x = 1; x = 2` |

### Tableaux — mutations d'index

| Situation CoffeeScript | Comportement actuel | Nouveau comportement |
|------------------------|--------------------|-----------------------|
| `arr[i] = x` (`arr` const) | `arr[i] = x` | **CompileError** : `arr` est const |
| `arr[i] = x` (`arr` let) | `arr[i] = x` | `arr = [...arr.slice(0,i), x, ...arr.slice(i+1)]` |
| `arr[i..j] = [x,y]` (`arr` let) | range splice | `arr = [...arr.slice(0,i), x, y, ...arr.slice(j+1)]` |

### Tableaux — méthodes mutantes → réécriture automatique

Le compilateur **réécrit silencieusement** tout appel de méthode mutante en son
équivalent copy-on-write. Si le récepteur est `const`, la réécriture produit un
**CompileError** (impossible de réassigner). Si le récepteur est `let`, la
réécriture procède automatiquement.

| Appel CoffeeScript | JS actuel | JS compilé (réécriture automatique) |
|--------------------|-----------|--------------------------------------|
| `arr.push x` | `arr.push(x)` | `arr = Object.freeze([...arr, x])` |
| `arr.push(x, y)` | `arr.push(x,y)` | `arr = Object.freeze([...arr, x, y])` |
| `arr.pop()` | `arr.pop()` | `arr = Object.freeze(arr.slice(0, -1))` |
| `arr.shift()` | `arr.shift()` | `arr = Object.freeze(arr.slice(1))` |
| `arr.unshift x` | `arr.unshift(x)` | `arr = Object.freeze([x, ...arr])` |
| `arr.splice(i, n)` | `arr.splice(i,n)` | `arr = Object.freeze([...arr.slice(0,i), ...arr.slice(i+n)])` |
| `arr.splice(i, n, x)` | `arr.splice(i,n,x)` | `arr = Object.freeze([...arr.slice(0,i), x, ...arr.slice(i+n)])` |
| `arr.sort()` | `arr.sort()` | `arr = Object.freeze(arr.toSorted())` |
| `arr.sort(fn)` | `arr.sort(fn)` | `arr = Object.freeze(arr.toSorted(fn))` |
| `arr.reverse()` | `arr.reverse()` | `arr = Object.freeze(arr.toReversed())` |
| `arr.fill(v)` | `arr.fill(v)` | `arr = Object.freeze(arr.toFilled(v))` ¹ |
| `arr.fill(v, s, e)` | `arr.fill(v,s,e)` | `arr = Object.freeze(arr.toFilled(v, s, e))` ¹ |
| `arr.copyWithin(t,s,e)` | mutant | `arr = Object.freeze(arr.toSpliced(...))` ² |

> ¹ `Array.prototype.toFilled` n'est pas natif — un helper `__toFilled__` est injecté.
> ² `copyWithin` est réécrit via `toSpliced` + slices — voir Étape 6d.

**Cas `const` → CompileError** : si `arr` est `const`, toute réécriture qui
réassigne `arr` est impossible → le compilateur lève une erreur et suggère
de déclarer `arr` avec `let`.

### Objets — mutations de propriétés

| Situation CoffeeScript | Comportement actuel | Nouveau comportement |
|------------------------|--------------------|-----------------------|
| `obj.prop = x` (`obj` const) | `obj.prop = x` | **CompileError** : `obj` est const |
| `obj.prop = x` (`obj` let) | `obj.prop = x` | `obj = {...obj, prop: x}` |
| `obj[key] = x` (`obj` let) | `obj[key] = x` | `obj = {...obj, [key]: x}` |
| `delete obj.prop` | `delete obj.prop` | **CompileError** — utiliser la déstructuration |

### Littéraux — gel systématique

| Expression | Sortie actuelle | Nouvelle sortie |
|------------|----------------|-----------------|
| `[1, 2, 3]` | `[1, 2, 3]` | `Object.freeze([1, 2, 3])` |
| `{a: 1, b: 2}` | `{a: 1, b: 2}` | `Object.freeze({a: 1, b: 2})` |
| `[[1,2],[3,4]]` | `[[1,2],[3,4]]` | `__freeze__([[1,2],[3,4]])` (deep) |

---

## Exemples cibles

### Variables

```coffeescript
# Entrée
square = (x) -> x * x
author = "Wittgenstein"
let counter = 0
counter = counter + 1
```
```javascript
// Sortie
const square = function(x) { return x * x; };
const author = "Wittgenstein";
let counter = 0;
counter = counter + 1;
```

### Tableau immuable par défaut

```coffeescript
# Entrée
colors = ["red", "green", "blue"]
```
```javascript
// Sortie — gelé, toute tentative de mutation lève TypeError en runtime
const colors = Object.freeze(["red", "green", "blue"]);
```

### Tableau mutable (let) avec "mutation" → copie

```coffeescript
# Entrée
let items = [1, 2, 3]
items[0] = 99          # rewrite automatique
```
```javascript
// Sortie
let items = Object.freeze([1, 2, 3]);
items = Object.freeze([...items.slice(0, 0), 99, ...items.slice(1)]);
```

### Objet mutable (let) avec "mutation" → copie

```coffeescript
# Entrée
let config = {debug: false, level: 1}
config.debug = true    # rewrite automatique
config["level"] = 2    # rewrite automatique
```
```javascript
// Sortie
let config = Object.freeze({debug: false, level: 1});
config = Object.freeze({...config, debug: true});
config = Object.freeze({...config, ["level"]: 2});
```

### Méthodes mutantes — réécriture automatique

```coffeescript
# Entrée
let items = ["a", "b", "c"]
items.push "d"
items.reverse()
items.sort()
```
```javascript
// Sortie — réécriture automatique, aucune erreur
let items = Object.freeze(["a", "b", "c"]);
items = Object.freeze([...items, "d"]);
items = Object.freeze(items.toReversed());
items = Object.freeze(items.toSorted());
```

```coffeescript
# Entrée
let nums = [3, 1, 4, 1, 5]
nums.splice 2, 1         # supprimer l'élément à l'index 2
nums.splice 1, 0, 99     # insérer 99 à l'index 1
```
```javascript
// Sortie
let nums = Object.freeze([3, 1, 4, 1, 5]);
nums = Object.freeze([...nums.slice(0, 2), ...nums.slice(2 + 1)]);
nums = Object.freeze([...nums.slice(0, 1), 99, ...nums.slice(1 + 0)]);
```

### Erreurs de compilation (cas non réécribles)

```coffeescript
x = 1
x = 2                  # ← CompileError : 'x' est const

arr = [1, 2, 3]
arr.push 4             # ← CompileError : 'arr' est const
                       #   Déclarez-le avec 'let' pour la réécriture automatique

obj = {a: 1}
obj.a = 2              # ← CompileError : 'obj' est const

delete obj.a           # ← CompileError : delete est mutatif
                       #   Utilisez : const {a, ...rest} = obj
```

---

## Nœuds AST concernés

| Nœud AST | Fichier | Rôle actuel | Modification |
|----------|---------|-------------|--------------|
| `Block.compileWithDeclarations` | `nodes.coffee` ~706 | Hisse `var` | Supprimer le bloc hoisted |
| `Assign.addScopeVariables` | `nodes.coffee` ~3542 | Déclare les vars | Typer `const`/`let`, vérifier réassignation |
| `Assign.compileNode` | `nodes.coffee` | Émet `name = val` | Émettre `const`/`let` inline + détecter mutation d'index/prop |
| `Arr.compileNode` | `nodes.coffee` | Émet `[...]` | Entourer de `Object.freeze(...)` |
| `Obj.compileNode` | `nodes.coffee` | Émet `{...}` | Entourer de `Object.freeze(...)` (ou `__freeze__` pour deep) |
| `Call.compileNode` | `nodes.coffee` | Émet les appels | Détecter et errorer sur les méthodes mutantes |
| `Op.compileNode` | `nodes.coffee` | Opérateurs | Errorer sur `delete` |
| `Range.compileNode` | `nodes.coffee` ~2341 | `var idx` | `let idx` |
| `Range.compileArray` | `nodes.coffee` ~2400 | `var result` | `let result` |
| `ExportDeclaration.compileNode` | `nodes.coffee` ~3308 | `var` | `const` |
| `Scope` | `scope.litcoffee` | Suit les `var` | Typer `const`/`let`, block-scope |

---

## Étapes de refactorisation

### Étape 1 — `let` comme mot-clé du langage

**Fichiers** : `src/lexer.coffee` + `src/grammar.coffee`

```coffeescript
# src/lexer.coffee — ajouter à KEYWORDS
'let'

# src/grammar.coffee — nouvelle règle
LetDeclaration: [
  o 'LET SimpleAssignable = Expression', -> new Assign $3, $5, null, letDeclaration: yes
]
```

Le flag `letDeclaration: yes` distingue `let x = 1` de `x = 1` dans tout le pipeline.

---

### Étape 2 — Refondre le Scope : function-scope → block-scope

**Fichier** : `src/scope.litcoffee`

#### Nouveau modèle

```
FunctionScope  (fermetures, paramètres)
  └── BlockScope  (if / for / while / try…)
        └── BlockScope  (imbriqué)
```

#### Changements

```litcoffee
# Types de variables :
#   'const'  — x = 1  (défaut)
#   'let'    — let x = 1  (mutabilité explicite)
#   'param'  — paramètre de fonction
#   'arguments', 'import', 'export'  — inchangés

constructor: (@parent, @expressions, @method, @referencedVars, @isBlock = no) ->
  @variables = if @isBlock then [] else [{name: 'arguments', type: 'arguments'}]
  @comments  = {}
  @positions = {}
  @utilities = {} unless @parent
  @root      = @parent?.root ? this

# find() : cherche dans le bloc courant, remonte jusqu'au function-scope
find: (name, type = 'const') ->
  return yes if Object::hasOwnProperty.call @positions, name
  if @parent and (@isBlock or @parent.isBlock)
    return @parent.find name, type
  @add name, type
  no

# check() : ne remonte pas au-delà de la frontière de fonction
check: (name) ->
  return yes if Object::hasOwnProperty.call @positions, name
  return @parent.check(name) if @parent and @isBlock
  no

# La variable est-elle let ?
isLetVar: (name) ->
  @type(name) is 'let' or (@parent?.isBlock and @parent.isLetVar(name))

# Plus besoin de declaredVariables() ni hasDeclarations() — tout est inline
```

#### Création des block-scopes dans `Block`

```coffeescript
# Block.compileNode() — chaque bloc non-fonction crée son propre scope
unless o.scope.expressions is this
  o = merge o, scope: new Scope(o.scope, this, null, [], yes)  # isBlock: yes
```

---

### Étape 3 — Supprimer le bloc hoisted, inliner `const`/`let`

**Fichier** : `src/nodes.coffee`

#### 3a — `Block.compileWithDeclarations()` (~ligne 706)

Supprimer la section qui émet `var x, y, z;` — elle n'a plus de raison d'être.

#### 3b — `Assign.addScopeVariables()` (~ligne 3542)

```coffeescript
# Typer selon letDeclaration, vérifier la réassignation d'un const
declarationType = if @letDeclaration then 'let' else 'const'
alreadyDeclared = o.scope.find name.value, declarationType

if alreadyDeclared and not o.scope.isLetVar(name.value)
  name.error "Cannot reassign const '#{name.value}'.
              Declare it mutable with: let #{name.value} = ..."

name.isDeclaration ?= not alreadyDeclared
```

#### 3c — `Assign.compileNode()` — préfixer `const`/`let`

```coffeescript
if name.isDeclaration
  keyword = if o.scope.isLetVar(name.value) then 'let' else 'const'
  fragments.unshift @makeCode "#{keyword} "
```

---

### Étape 4 — Réécriture des mutations d'index et de propriété

**Fichier** : `src/nodes.coffee` — `Assign.compileNode()`

Détecter si le membre gauche d'une assignation est un accès à un index ou une propriété.

#### 4a — Détection

```coffeescript
# Dans Assign.compileNode(), avant d'émettre les fragments :
lhs = @variable.unwrap()
isIndexMutation  = lhs instanceof Value and lhs.base? and
                   lhs.properties.length > 0 and
                   lhs.properties[lhs.properties.length - 1] instanceof Index
isPropMutation   = lhs instanceof Value and lhs.base? and
                   lhs.properties.length > 0 and
                   lhs.properties[lhs.properties.length - 1] instanceof Access
```

#### 4b — Vérification que le conteneur est `let`

```coffeescript
if isIndexMutation or isPropMutation
  containerName = lhs.base.value
  unless o.scope.isLetVar(containerName)
    @error "Cannot mutate '#{containerName}': it is const.
            Declare it mutable with: let #{containerName} = ..."
```

#### 4c — Réécriture copy-on-write

```coffeescript
# Mutation d'index : arr[i] = x  →  arr = [...arr.slice(0,i), x, ...arr.slice(i+1)]
if isIndexMutation
  idx = lhs.properties[lhs.properties.length - 1].index.compile o
  base = lhs.base.compile o
  val  = @value.compile o
  return @makeCode(
    "#{base} = Object.freeze([...#{base}.slice(0, #{idx}),
     #{val}, ...#{base}.slice(#{idx} + 1)])"
  )

# Mutation de propriété : obj.prop = x  →  obj = {...obj, prop: x}
if isPropMutation
  prop = lhs.properties[lhs.properties.length - 1].name.value
  base = lhs.base.compile o
  val  = @value.compile o
  # Propriété dynamique : obj[key] = x  →  obj = {...obj, [key]: x}
  isDynamic = lhs.properties[lhs.properties.length - 1] instanceof Index
  propStr = if isDynamic then "[#{prop}]" else prop
  return @makeCode "#{base} = Object.freeze({...#{base}, #{propStr}: #{val}})"
```

---

### Étape 5 — Gel des littéraux (`Object.freeze`)

**Fichier** : `src/nodes.coffee`

#### 5a — Littéraux simples (pas de nesting)

```coffeescript
# Arr.compileNode() — entourer le tableau compilé
compileNode: (o) ->
  fragments = super(o)
  [open, ..., close] = fragments
  # Insérer Object.freeze( ... ) autour
  fragments.unshift @makeCode 'Object.freeze('
  fragments.push    @makeCode ')'
  fragments

# Obj.compileNode() — même principe
```

#### 5b — Structures imbriquées → helper `__freeze__` (deep freeze)

Pour les tableaux/objets contenant eux-mêmes des tableaux/objets, un simple
`Object.freeze` ne gèle que le premier niveau. Injecter un helper une seule fois
en tête du fichier compilé quand des littéraux imbriqués sont détectés :

```javascript
// Helper injecté automatiquement (une seule fois par fichier)
const __freeze__ = (v) => {
  if (v !== null && typeof v === 'object') {
    Object.keys(v).forEach(k => __freeze__(v[k]));
    Object.freeze(v);
  }
  return v;
};
```

Les littéraux avec nesting utilisent `__freeze__(...)` au lieu de `Object.freeze(...)`.
Les littéraux plats (scalaires uniquement) utilisent `Object.freeze(...)` directement.

---

### Étape 6 — Réécriture automatique des méthodes mutantes

**Fichier** : `src/nodes.coffee` — `Call.compileNode()`

Le compilateur intercepte les appels de méthodes mutantes connues et les réécrit
en leur équivalent copy-on-write **avant** d'émettre du JavaScript.

#### 6a — Table de réécriture

```coffeescript
# src/nodes.coffee — constante de réécriture
MUTATING_REWRITES =
  push: (base, args) ->
    "#{base} = Object.freeze([...#{base}, #{args.join ', '}])"

  pop: (base, _args) ->
    "#{base} = Object.freeze(#{base}.slice(0, -1))"

  shift: (base, _args) ->
    "#{base} = Object.freeze(#{base}.slice(1))"

  unshift: (base, args) ->
    "#{base} = Object.freeze([#{args.join ', '}, ...#{base}])"

  splice: (base, args) ->
    [i, n, ...items] = args
    itemsStr = if items.length then ", #{items.join ', '}" else ''
    "#{base} = Object.freeze([...#{base}.slice(0, #{i})" +
    "#{itemsStr}, ...#{base}.slice(#{i} + #{n})])"

  sort: (base, args) ->
    comparator = if args.length then args[0] else ''
    if comparator
      "#{base} = Object.freeze(#{base}.toSorted(#{comparator}))"
    else
      "#{base} = Object.freeze(#{base}.toSorted())"

  reverse: (base, _args) ->
    "#{base} = Object.freeze(#{base}.toReversed())"

  fill: (base, args) ->
    # Utilise le helper __toFilled__ injecté en tête de fichier
    "#{base} = Object.freeze(__toFilled__(#{base}, #{args.join ', '}))"

  copyWithin: (base, args) ->
    [target, start, end_] = args
    endStr = if end_ then ", #{end_}" else ''
    # Réécriture via slice
    "#{base} = Object.freeze([" +
    "...#{base}.slice(0, #{target}), " +
    "...#{base}.slice(#{start}#{endStr}), " +
    "...#{base}.slice(#{target} + (#{end_ or base + '.length'} - #{start}))])"
```

#### 6b — Détection et réécriture dans `Call.compileNode()`

```coffeescript
compileNode: (o) ->
  # Détecter : receiver.method(args)
  if @variable instanceof Value and @variable.properties.length > 0
    lastProp = @variable.properties[@variable.properties.length - 1]
    if lastProp instanceof Access
      methodName = lastProp.name.value
      rewriter   = MUTATING_REWRITES[methodName]

      if rewriter
        # Identifier le récepteur (arr dans arr.push(x))
        receiverNode = new Value @variable.base, @variable.properties[...-1]
        receiverName = receiverNode.compile o

        # Vérifier que le récepteur est let (sinon CompileError)
        unless o.scope.isLetVar(receiverName)
          @error "'#{receiverName}.#{methodName}()' est une opération mutante.
                  '#{receiverName}' est const — déclarez-le avec 'let' pour
                  permettre la réécriture immutable automatique."

        # Compiler les arguments
        compiledArgs = (arg.compile o for arg in @args)

        # Injecter les helpers nécessaires (fill → __toFilled__)
        @injectHelperIfNeeded methodName, o

        # Retourner la réécriture copy-on-write
        return [@makeCode rewriter(receiverName, compiledArgs)]

  # Pas de réécriture → compilation normale
  super(o)
```

#### 6c — Helper `__toFilled__` (injecté une fois)

`Array.prototype.toFilled` n'est pas encore standardisé. Le compiler injecte
ce helper en tête de fichier quand `fill()` est détecté :

```javascript
// Injecté automatiquement si fill() est utilisé
const __toFilled__ = (arr, value, start = 0, end = arr.length) => {
  return Object.freeze(arr.map((v, i) => (i >= start && i < end) ? value : v));
};
```

#### 6d — Helper `__freeze__` (deep freeze, injecté une fois)

```javascript
// Injecté automatiquement si des littéraux imbriqués sont détectés
const __freeze__ = (v) => {
  if (v !== null && typeof v === 'object') {
    Object.keys(v).forEach(k => __freeze__(v[k]));
    Object.freeze(v);
  }
  return v;
};
```

Les helpers sont injectés via le mécanisme `scope.assign` existant (déjà
utilisé pour `__hasProp__`, `__extends__`, etc.) — ils apparaissent en tête
du fichier compilé, une seule fois, même si la méthode est appelée plusieurs fois.

---

### Étape 7 — Erreur sur `delete`

**Fichier** : `src/nodes.coffee` — `Op.compileNode()`

```coffeescript
# Opérateur delete interdit
if @operator is 'delete'
  @error "L'opérateur delete est mutatif.
          Pour supprimer une propriété, utilisez la déstructuration :
          const {prop, ...rest} = obj"
```

---

### Étape 8 — Corriger les autres points d'émission de `var`

| Nœud | Ligne approx. | Changement |
|------|---------------|------------|
| `Range.compileNode()` | ~2341 | `var idx` → `let idx` |
| `Range.compileArray()` | ~2400 | `var result` → `let result` |
| `ExportDeclaration.compileNode()` | ~3308 | `var` → `const` |

---

## Tests de conformité

**Fichier** : `test/const_let_declarations.coffee`

```coffeescript
CoffeeScript = require '../lib/coffeescript'

# ═══ VARIABLES ════════════════════════════════════════════════════════════════

test "simple assignment compiles to const", ->
  eq CoffeeScript.compile("""
    square = (x) -> x * x
    author = "Wittgenstein"
    cube   = (x) -> square(x) * x
  """, bare: yes).trim(), """
    const square = function(x) {
      return x * x;
    };
    const author = "Wittgenstein";
    const cube = function(x) {
      return square(x) * x;
    };
  """

test "explicit let compiles to let", ->
  eq CoffeeScript.compile("""
    let counter = 0
    counter = counter + 1
  """, bare: yes).trim(), """
    let counter = 0;
    counter = counter + 1;
  """

test "reassignment of const throws compile error", ->
  throwsCompileError """
    x = 1
    x = 2
  """

test "no var keyword in output", ->
  ok not /\bvar\b/.test CoffeeScript.compile("""
    a = 1
    let b = 2
    b = b + a
  """, bare: yes)

# ═══ BLOCK SCOPE ══════════════════════════════════════════════════════════════

test "let in if block stays block-scoped", ->
  eq CoffeeScript.compile("""
    validate = (n) ->
      if n > 0
        let msg = "positif"
        console.log msg
  """, bare: yes).trim(), """
    const validate = function(n) {
      if (n > 0) {
        let msg = "positif";
        console.log(msg);
      }
    };
  """

test "using block variable outside its block throws error", ->
  throwsCompileError """
    if true
      let y = 42
    console.log y
  """

test "let at function level accessible throughout function body", ->
  eq CoffeeScript.compile("""
    compute = (n) ->
      let result = 0
      if n > 0
        result = n * 2
      result
  """, bare: yes).trim(), """
    const compute = function(n) {
      let result = 0;
      if (n > 0) {
        result = n * 2;
      }
      return result;
    };
  """

# ═══ TABLEAUX — GEL ═══════════════════════════════════════════════════════════

test "array literal is frozen", ->
  eq CoffeeScript.compile("""
    colors = ["red", "green", "blue"]
  """, bare: yes).trim(),
  'const colors = Object.freeze(["red", "green", "blue"]);'

test "nested array uses deep freeze helper", ->
  compiled = CoffeeScript.compile("""
    matrix = [[1, 2], [3, 4]]
  """, bare: yes)
  ok /\b__freeze__\b/.test(compiled), "Deep nested arrays should use __freeze__"

# ═══ OBJETS — GEL ═════════════════════════════════════════════════════════════

test "object literal is frozen", ->
  eq CoffeeScript.compile("""
    point = {x: 1, y: 2}
  """, bare: yes).trim(),
  'const point = Object.freeze({x: 1, y: 2});'

# ═══ MUTATIONS D'INDEX — COPY-ON-WRITE ════════════════════════════════════════

test "index assignment on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr[0] = 99
  """

test "index assignment on let array rewrites to spread copy", ->
  compiled = CoffeeScript.compile("""
    let items = [1, 2, 3]
    items[0] = 99
  """, bare: yes)
  ok /slice/.test(compiled),         "Should use slice for copy"
  ok not /items\[0\]\s*=/.test(compiled), "Should not contain direct index assignment"

# ═══ MUTATIONS DE PROPRIÉTÉ — COPY-ON-WRITE ═══════════════════════════════════

test "property assignment on const object throws compile error", ->
  throwsCompileError """
    obj = {a: 1}
    obj.a = 2
  """

test "property assignment on let object rewrites to spread copy", ->
  eq CoffeeScript.compile("""
    let config = {debug: false}
    config.debug = true
  """, bare: yes).trim(), """
    let config = Object.freeze({debug: false});
    config = Object.freeze({...config, debug: true});
  """

test "dynamic property assignment on let object rewrites correctly", ->
  compiled = CoffeeScript.compile("""
    let map = {a: 1}
    key = "b"
    map[key] = 2
  """, bare: yes)
  ok /\[key\]/.test(compiled), "Should use computed property key"
  ok /\.\.\./. test(compiled), "Should use spread"

# ═══ MÉTHODES MUTANTES — RÉÉCRITURE AUTOMATIQUE ══════════════════════════════

test "push() on let array rewrites to spread append", ->
  eq CoffeeScript.compile("""
    let arr = [1, 2, 3]
    arr.push 4
  """, bare: yes).trim(), """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze([...arr, 4]);
  """

test "pop() on let array rewrites to slice", ->
  eq CoffeeScript.compile("""
    let arr = [1, 2, 3]
    arr.pop()
  """, bare: yes).trim(), """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze(arr.slice(0, -1));
  """

test "sort() on let array rewrites to toSorted()", ->
  eq CoffeeScript.compile("""
    let arr = [3, 1, 2]
    arr.sort()
  """, bare: yes).trim(), """
    let arr = Object.freeze([3, 1, 2]);
    arr = Object.freeze(arr.toSorted());
  """

test "sort(fn) on let array rewrites to toSorted(fn)", ->
  eq CoffeeScript.compile("""
    let arr = [3, 1, 2]
    arr.sort (a, b) -> a - b
  """, bare: yes).trim(), """
    let arr = Object.freeze([3, 1, 2]);
    arr = Object.freeze(arr.toSorted(function(a, b) { return a - b; }));
  """

test "reverse() on let array rewrites to toReversed()", ->
  eq CoffeeScript.compile("""
    let arr = [1, 2, 3]
    arr.reverse()
  """, bare: yes).trim(), """
    let arr = Object.freeze([1, 2, 3]);
    arr = Object.freeze(arr.toReversed());
  """

test "unshift() on let array rewrites to spread prepend", ->
  eq CoffeeScript.compile("""
    let arr = [2, 3]
    arr.unshift 1
  """, bare: yes).trim(), """
    let arr = Object.freeze([2, 3]);
    arr = Object.freeze([1, ...arr]);
  """

test "splice(i,n) on let array rewrites to slice copy", ->
  eq CoffeeScript.compile("""
    let arr = [1, 2, 3, 4]
    arr.splice 1, 2
  """, bare: yes).trim(), """
    let arr = Object.freeze([1, 2, 3, 4]);
    arr = Object.freeze([...arr.slice(0, 1), ...arr.slice(1 + 2)]);
  """

test "push() on const array throws compile error", ->
  throwsCompileError """
    arr = [1, 2, 3]
    arr.push 4
  """

test "sort() on const array throws compile error", ->
  throwsCompileError """
    arr = [3, 1, 2]
    arr.sort()
  """

# ═══ DELETE ═══════════════════════════════════════════════════════════════════

test "delete operator throws compile error", ->
  throwsCompileError """
    obj = {a: 1, b: 2}
    delete obj.a
  """

# ═══ BOUCLES ══════════════════════════════════════════════════════════════════

test "for loop control variables compile to let", ->
  compiled = CoffeeScript.compile("""
    for i in [1..10]
      console.log i
  """, bare: yes)
  ok /\blet\b/.test(compiled)
  ok not /\bvar\b/.test(compiled)
```

---

## Ordre d'exécution

```
1.  Modifier  src/lexer.coffee                     — token LET
2.  Modifier  src/grammar.coffee                   — règle LetDeclaration
3.  Modifier  src/scope.litcoffee                  — types const/let, block-scope
4.  Écrire    test/const_let_declarations.coffee   — TDD (échecs attendus)
5.  Modifier  Block.compileWithDeclarations        — supprimer le bloc hoisted
6.  Modifier  Assign.addScopeVariables             — vérifier réassignation const
7.  Modifier  Assign.compileNode                   — const/let inline + copy-on-write index/prop
8.  Modifier  Arr.compileNode                      — Object.freeze / __freeze__
9.  Modifier  Obj.compileNode                      — Object.freeze / __freeze__
10. Modifier  Call.compileNode                     — RÉÉCRITURE automatique méthodes mutantes
                                                     (push/pop/shift/unshift/splice/sort/
                                                      reverse/fill/copyWithin)
                                                   — injection helpers __toFilled__, __freeze__
11. Modifier  Op.compileNode                       — erreur sur delete
12. Modifier  Range.compileNode / compileArray     — let pour variables de boucle
13. Modifier  ExportDeclaration.compileNode        — const par défaut
14. Exécuter  bin/cake build                       — recompiler
15. Exécuter  bin/cake test                        — suite complète
```

---

## Points de vigilance

### Rupture sémantique majeure

Le bloc-scope rompt avec le comportement historique de CoffeeScript (tout est
function-scoped). Tout code existant qui déclare une variable dans un `if`/`for`
et l'utilise ensuite à l'extérieur devra être réécrit explicitement.

### Pattern obligatoire pour les let cross-blocs

```coffeescript
# ✗ Incorrect
compute = (n) ->
  if n > 0
    let result = n * 2   # block-scoped → inaccessible dehors
  result                 # CompileError

# ✓ Correct : déclarer au niveau du bloc parent
compute = (n) ->
  let result = 0
  if n > 0
    result = n * 2
  result
```

### Gel superficiel vs profond

`Object.freeze` ne gèle que le premier niveau. Pour les structures imbriquées,
le helper `__freeze__` est injecté une seule fois en tête du fichier compilé
(via le mécanisme `scope.assign` déjà existant pour les helpers générés).

### `Object.freeze` et performance

Geler chaque littéral a un coût. Envisager une option `--no-freeze` pour
désactiver le gel en production (en gardant les erreurs de compilation sur
les mutations).

### Méthodes `toSorted` / `toReversed`

Ces alternatives immutables sont disponibles depuis Node.js 20 et les navigateurs
modernes (2023+). Pour cibler des environnements plus anciens, proposer un polyfill
ou accepter `[...arr].sort()` comme alternative manuelle.

### Destructuration et `delete`

```coffeescript
# À la place de : delete obj.prop
# Utiliser :
{prop, ...rest} = obj
# rest est un nouvel objet sans prop
```

### Bootstrap du compilateur

```bash
bin/cake build   # obligatoire après chaque modification de src/
bin/cake test    # validation complète
```

---

## Indicateur de succès

```bash
bin/cake test
# → 0 failures
# → grep -r '\bvar\b' test/fixtures/  →  0 résultats
# → grep -r '\.push\|\.pop\|\.splice\|delete ' test/fixtures/  →  0 résultats
```
