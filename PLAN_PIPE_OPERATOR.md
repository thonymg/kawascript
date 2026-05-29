# Plan d'implémentation : Opérateur Pipe `|>`

> **Philosophie** : Le pipe `|>` rend le flux de données explicite et
> lisible. Là où le chaînage par `.` est lié à la POO (méthodes d'un objet),
> `|>` est purement fonctionnel : il pipe une valeur comme premier argument
> de n'importe quelle fonction, rendant composables des fonctions ordinaires
> non liées à un prototype.

---

## Syntaxe cible

```coffee
result = [1, 2, 3, 4, 5]
  |> filter (x) -> x > 2
  |> map (x) -> x * 2
  |> reduce 0, (acc, x) -> acc + x
```

**Sémantique** : `a |> f b, c` compile en `f(a, b, c)` — la valeur de
gauche est insérée comme **premier argument** de l'appel de droite.

---

## Différences fondamentales avec le chaînage `.`

| Critère                | Chaînage `.`                        | Pipe `\|>`                             |
|------------------------|-------------------------------------|----------------------------------------|
| Scope                  | Méthodes du prototype               | N'importe quelle fonction              |
| Insertion de la valeur | `this` implicite                    | Premier argument explicite             |
| Couplage               | Fort (l'objet doit avoir la méthode)| Faible (séparation données / fonctions)|
| Style                  | POO                                 | Fonctionnel                            |
| Exemple                | `arr.filter(fn).map(fn)`            | `arr \|> filter fn \|> map fn`         |
| Fonction custom        | Impossible sans `prototype`         | Directement : `arr \|> myFn`           |

```coffee
# Dot chaining — lié au prototype Array
[1,2,3]
  .filter (x) -> x > 2     # Array.prototype.filter
  .map (x) -> x * 2        # Array.prototype.map

# Pipe — n'importe quelle fonction
[1,2,3]
  |> filter (x) -> x > 2   # filter est une fonction ordinaire
  |> transform              # transform peut venir de n'importe où
  |> log                    # log est console.log, une fonction externe
```

---

## Références dans d'autres langages

### F# / OCaml (inspiration principale)
```fsharp
[1..5]
|> List.filter (fun x -> x > 2)
|> List.map (fun x -> x * 2)
|> List.reduce (+)
```
**Sémantique** : `a |> f` = `f a`. La valeur est passée comme DERNIER argument
(style fonctionnel / currying). Fonctions data-last.

### Elixir
```elixir
[1, 2, 3, 4, 5]
|> Enum.filter(fn x -> x > 2 end)
|> Enum.map(fn x -> x * 2 end)
|> Enum.reduce(0, fn acc, x -> acc + x end)
```
**Sémantique** : `a |> f(b, c)` = `f(a, b, c)`. Valeur en PREMIER argument.
Fonctions data-first. **KawaScript adopte ce modèle.**

### R (natif depuis 4.1)
```r
c(1, 2, 3, 4, 5) |>
  Filter(f = function(x) x > 2, x = _) |>
  sapply(function(x) x * 2) |>
  Reduce(`+`, .)
```
**Sémantique** : Valeur en premier argument, avec placeholder `_` ou `_`.

### Hack-style (TC39 JavaScript — Stage 2)
```javascript
[1, 2, 3, 4, 5]
  |> filter(%, x => x > 2)
  |> map(%, x => x * 2)
  |> reduce(%, 0, (acc, x) => acc + x)
```
**Sémantique** : Placeholder explicite `%`. Maximum de flexibilité mais
syntaxe plus lourde. Non retenu pour KawaScript (Phase 1).

### Clojure (thread-first `->`  et thread-last `->>`)
```clojure
(->> [1 2 3 4 5]
     (filter #(> % 2))
     (map #(* % 2))
     (reduce + 0))
```
**Sémantique** : `->>` insère la valeur en DERNIER argument (currying). `->` en premier.

### Gleam
```gleam
[1, 2, 3, 4, 5]
|> list.filter(fn(x) { x > 2 })
|> list.map(fn(x) { x * 2 })
|> list.fold(0, fn(acc, x) { acc + x })
```
**Sémantique** : Valeur en premier argument.

### Bilan comparatif

| Langage    | Placement  | Syntaxe               | Partielles | Placeholder |
|------------|------------|------------------------|------------|-------------|
| F# / OCaml | Dernier    | `a \|> f`              | Currying   | Non         |
| Elixir     | **Premier**| `a \|> f(b, c)`        | Non        | Non         |
| Hack/JS    | Flexible   | `a \|> f(%, b)`        | Explicite  | `%`         |
| Gleam      | Premier    | `a \|> f(b)`           | Non        | Non         |
| Clojure ->>| Dernier    | `->> a (f b)`          | Non        | Non         |
| **KawaScript** | **Premier** | `a \|> f b, c` | Non (Phase 2) | Non (Phase 2) |

---

## Décision de conception : data-first vs data-last

KawaScript adopte la sémantique **data-first** (Elixir, Gleam) :

```
a |> f b, c    ≡    f(a, b, c)
```

### Justification

1. **Cohérence avec JavaScript** : les méthodes natives (`filter(fn)`, `reduce(fn, init)`)
   placent les données comme récepteur `this`. L'analogue fonctionnel place les données
   en premier argument.

2. **Lisibilité directe** : `arr |> reduce 0, fn` se lit
   "prendre arr, réduire avec initial=0 et fn". L'ordre `(arr, 0, fn)` est naturel.

3. **Praticité** : les fonctions utilitaires de l'écosystème JavaScript sont souvent
   `(data, ...options)` — pas besoin de les réécrire.

### Cas d'usage

```coffee
# Fonctions ordinaires (data-first)
myFilter = (data, predicate) -> data.filter predicate
myMap    = (data, fn)        -> data.map fn
myReduce = (data, init, fn)  -> data.reduce fn, init

result = [1, 2, 3, 4, 5]
  |> myFilter (x) -> x > 2     # myFilter([1,2,3,4,5], fn)
  |> myMap (x) -> x * 2        # myMap(filtered, fn)
  |> myReduce 0, (acc,x) -> acc + x  # myReduce(mapped, 0, fn)

# Wrappers pour méthodes prototype
filter   = (arr, fn)        -> arr.filter fn
map      = (arr, fn)        -> arr.map fn
reduce   = (arr, init, fn)  -> arr.reduce fn, init

result = [1, 2, 3, 4, 5]
  |> filter (x) -> x > 2
  |> map (x) -> x * 2
  |> reduce 0, (acc, x) -> acc + x
```

---

## Architecture de l'implémentation

```
Source .coffee
    │
    ▼
┌─────────┐   |> → PIPE token      ┌─────────────┐
│  Lexer  │────────────────────►   │   Parser    │
│         │   LINE_CONTINUER +     │   (Jison)   │
│         │   UNFINISHED updated   └──────┬──────┘
└─────────┘                               │ AST
                                          ▼
                                   ┌─────────────┐
                                   │ PipeOp node │
                                   │  left: Expr │
                                   │  right: Expr│
                                   └──────┬──────┘
                                          │ compileNode()
                                          ▼
                                 f(left, ...args)  ou  f(left)
```

---

## Étape 1 — Lexer (`src/lexer.coffee`)

### 1a. Ajouter `|>` dans le regex `OPERATOR`

Le regex `OPERATOR` tente de matcher des opérateurs multi-caractères avant
de retomber sur le single-char `|`. On ajoute `\|>` AVANT l'alternative
qui matche `|` seul :

```coffee
OPERATOR = /// ^ (
  ?: [-=]>             # function  ->  =>
   | \|>               # ← pipe operator  (NOUVEAU — avant |  |=  ||)
   | [-+*/%<>&|^!?=]=  # compound assign / compare
   | >>>=?             # zero-fill right shift
   | ([-+:])\1         # doubles
   | ([&|<>*/%])\2=?   # logic / shift / power
   | \?(\.|::)         # soak access
   | \.{2,3}           # range or splat
) ///
```

L'ordre est crucial : `\|>` doit être essayé AVANT `([&|<>*/%])\2=?`
(qui matcherait `||`) et avant le single-char fallback `|`.

### 1b. Tag du token dans `literalToken()`

```coffee
# Dans literalToken(), dans la cascade else if :
else if value in SHIFT           then tag = 'SHIFT'
else if value is '|>'            then tag = 'PIPE'    # ← NOUVEAU
else if value is '?' and prev?.spaced then tag = 'BIN?'
```

### 1c. Suppression du TERMINATOR en fin de ligne (`|>` trailing)

Lorsqu'une ligne se termine par `|>`, la ligne suivante est une continuation.
On ajoute `'PIPE'` à `UNFINISHED` dans `src/rewriter.coffee` :

```coffee
# src/rewriter.coffee — constante UNFINISHED
exports.UNFINISHED = UNFINISHED = [
  '\\', '.', '?.', '?::', 'UNARY', 'DO', 'DO_IIFE', 'MATH', 'UNARY_MATH',
  '+', '-', '**', 'SHIFT', 'RELATION', 'COMPARE', '&', '^', '|', '&&',
  '||', 'BIN?', 'EXTENDS',
  'PIPE'       # ← NOUVEAU
]
```

### 1d. Suppression du TERMINATOR en début de ligne (`|>` leading)

Lorsqu'une ligne COMMENCE par `|>`, c'est une continuation de l'expression
précédente. On ajoute `\|>` à `LINE_CONTINUER` :

```coffee
# src/lexer.coffee — constante LINE_CONTINUER
LINE_CONTINUER = /// ^ \s* (?: , | \??\.(?![.\d]) | \??:: | \|> ) ///
#                                                              ^^^^ NOUVEAU
```

Cela permet la syntaxe multi-lignes naturelle :

```coffee
result = getData()
  |> process      # |> en début de ligne → continuation
  |> format       # pareil
```

---

## Étape 2 — Grammaire (`src/grammar.coffee`)

### 2a. Règle d'opération

```coffee
Operation: [
  # ... toutes les règles existantes ...

  # Pipe operator
  o 'Expression PIPE Expression',   -> new PipeOp $1, $3
]
```

### 2b. Précédence

Le pipe doit avoir une précédence INFÉRIEURE à tous les opérateurs
arithmétiques et logiques, mais SUPÉRIEURE à `=` (assignment).

On l'insère juste après `['left', 'BIN?']` dans la liste des opérateurs
(rappel : dans cette liste, du haut = plus haute précédence au bas = plus basse) :

```coffee
operators = [
  ['right',     'DO_IIFE']
  ['left',      '.', '?.', '::', '?::']
  ['left',      'CALL_START', 'CALL_END']
  ['nonassoc',  '++', '--']
  ['left',      '?']
  ['right',     'UNARY', 'DO']
  ['right',     'AWAIT']
  ['right',     '**']
  ['right',     'UNARY_MATH']
  ['left',      'MATH']
  ['left',      '+', '-']
  ['left',      'SHIFT']
  ['left',      'RELATION']
  ['left',      'COMPARE']
  ['left',      '&']
  ['left',      '^']
  ['left',      '|']
  ['left',      '&&']
  ['left',      '||']
  ['left',      'BIN?']
  ['left',      'PIPE']      # ← NOUVEAU : plus bas que || mais plus haut que =
  ['nonassoc',  'INDENT', 'OUTDENT']
  ['right',     'YIELD']
  ['right',     '=', ':', 'COMPOUND_ASSIGN', 'RETURN', 'THROW', 'EXTENDS']
  # ... suite inchangée ...
]
```

**Vérifications de précédence :**

| Expression               | Parse attendu              | Correct ? |
|--------------------------|----------------------------|-----------|
| `a + b \|> f`            | `(a + b) \|> f`            | ✓         |
| `a \|\| b \|> f`         | `(a \|\| b) \|> f`         | ✓         |
| `a = b \|> f`            | `a = (b \|> f)`            | ✓         |
| `a \|> f \|> g`          | `(a \|> f) \|> g`          | ✓ (left)  |
| `return a \|> f`         | `return (a \|> f)`         | ✓         |

---

## Étape 3 — Nœuds AST (`src/nodes.coffee`)

### 3a. Classe `PipeOp`

```coffee
exports.PipeOp = class PipeOp extends Base
  constructor: (@left, @right) -> super()

  children: ['left', 'right']

  # Le pipe est une expression — jamais un statement top-level seul
  isStatement: NO

  compileNode: (o) ->
    # Compiler le côté gauche (la valeur à piper)
    leftFrags = @left.compileToFragments o, LEVEL_PAREN

    # Analyser le côté droit pour insérer left comme premier argument
    @compileAsCall o, leftFrags

  compileAsCall: (o, leftFrags) ->
    right = @right.unwrap()

    if right instanceof Call
      # Cas : a |> f b, c
      # right = Call(f, [b, c])
      # → recomposer en Call(f, [a, b, c])
      @compilePipeIntoCall o, leftFrags, right

    else if right instanceof Code
      # Cas : a |> (x) -> x * 2
      # → ((x) -> x * 2)(a)
      fnFrags = @right.compileToFragments o, LEVEL_PAREN
      [].concat(
        [@makeCode '('],
        fnFrags,
        [@makeCode ')('],
        leftFrags,
        [@makeCode ')']
      )

    else
      # Cas : a |> f  (identifiant ou expression)
      # → f(a)
      fnFrags = @right.compileToFragments o, LEVEL_PAREN
      [].concat fnFrags,
        [@makeCode '('],
        leftFrags,
        [@makeCode ')']

  compilePipeIntoCall: (o, leftFrags, call) ->
    # Reconstruire l'appel avec left inséré en premier argument.
    # On évite de muter le nœud Call existant — on génère directement
    # les fragments de code.
    fnFrags   = call.variable.compileToFragments o, LEVEL_ACCESS
    argFrags  = []

    # Premier argument : la valeur pipée
    argFrags = argFrags.concat leftFrags

    # Arguments existants de l'appel de droite
    for arg in call.args
      argFrags.push @makeCode ', '
      argFrags = argFrags.concat arg.compileToFragments o, LEVEL_LIST

    [].concat fnFrags,
      [@makeCode '('],
      argFrags,
      [@makeCode ')']

  astType: -> 'PipeExpression'

  astProperties: (o) ->
    return
      left:  @left.ast o, LEVEL_PAREN
      right: @right.ast o, LEVEL_PAREN
```

---

## Étape 4 — Génération de code JavaScript

### Exemple principal

**Entrée KawaScript :**
```coffee
result = [1, 2, 3, 4, 5]
  |> filter (x) -> x > 2
  |> map (x) -> x * 2
  |> reduce 0, (acc, x) -> acc + x
```

**Sortie JavaScript :**
```javascript
const result = reduce(
  map(
    filter([1, 2, 3, 4, 5], (x) => x > 2),
    (x) => x * 2
  ),
  0,
  (acc, x) => acc + x
);
```

L'opérateur étant left-associatif, le pipe se construit de l'intérieur
vers l'extérieur (wrapping progressif).

### Exemple avec identifiant simple

```coffee
data = getData()
  |> normalize
  |> validate
  |> serialize
```

**Sortie :**
```javascript
const data = serialize(validate(normalize(getData())));
```

### Exemple avec méthode (accès chaîné)

```coffee
result = input
  |> JSON.parse
  |> sanitize
```

**Sortie :**
```javascript
const result = sanitize(JSON.parse(input));
```

### Exemple avec fonction anonyme inline

```coffee
result = value
  |> (x) -> x * 2
  |> (x) -> x + 1
```

**Sortie :**
```javascript
const result = ((x) => x + 1)(((x) => x * 2)(value));
```

### Exemple avec opérateurs arithmétiques (vérification de précédence)

```coffee
result = a + b
  |> Math.abs
  |> (x) -> x * factor
```

**Sortie :**
```javascript
const result = ((x) => x * factor)(Math.abs(a + b));
```

---

## Étape 5 — Intégration avec l'immutabilité

Le pipe ne crée aucune mutation : chaque étape retourne une nouvelle valeur.

```coffee
# Toutes les valeurs intermédiaires sont implicitement const
result = users
  |> filter (u) -> u.active          # nouvelle liste
  |> map (u) -> {name: u.name}       # nouvelle liste d'objets
  |> sortBy (u) -> u.name            # nouvelle liste triée
```

**Sortie :**
```javascript
const result = sortBy(
  map(
    filter(users, (u) => u.active),
    (u) => Object.freeze({ name: u.name })
  ),
  (u) => u.name
);
```

Les objets littéraux créés dans le pipe sont gelés (`Object.freeze`) par
le système d'immutabilité existant.

---

## Étape 6 — Compatibilité avec le pattern matching

Les deux fonctionnalités se composent naturellement :

```coffee
result = input
  |> parse
  |> (data) ->
      match data.status
      | "ok"    -> data.value
      | "error" -> throw new Error data.message
      | _       -> null
  |> format
```

Le `match` étant une expression, il peut s'insérer dans n'importe quelle
étape du pipe sans syntaxe spéciale.

---

## Étape 7 — Tests (`test/pipe_operator.coffee`)

```coffee
# test/pipe_operator.coffee

test "pipe to simple function", ->
  double = (x) -> x * 2
  eq (5 |> double), 10

test "pipe with additional args", ->
  add = (x, n) -> x + n
  eq (5 |> add 3), 8

test "chained pipes", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double |> inc), 11

test "pipe is left-associative", ->
  # (5 |> double) |> inc  ≡  inc(double(5))
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double |> inc), inc(double(5))

test "pipe with array", ->
  myFilter = (arr, fn) -> arr.filter fn
  myMap    = (arr, fn) -> arr.map fn
  result = [1, 2, 3, 4, 5]
    |> myFilter (x) -> x > 2
    |> myMap (x) -> x * 2
  arrayEq result, [6, 8, 10]

test "pipe with reduce", ->
  myFilter = (arr, fn)      -> arr.filter fn
  myMap    = (arr, fn)      -> arr.map fn
  myReduce = (arr, init, fn) -> arr.reduce fn, init
  result = [1, 2, 3, 4, 5]
    |> myFilter (x) -> x > 2
    |> myMap (x) -> x * 2
    |> myReduce 0, (acc, x) -> acc + x
  eq result, 24

test "pipe to method reference", ->
  eq ([1, 2, 3] |> JSON.stringify), '[1,2,3]'

test "pipe with inline lambda", ->
  eq (5 |> (x) -> x * x), 25

test "multiline pipe (leading |>)", ->
  inc    = (x) -> x + 1
  double = (x) -> x * 2
  result =
    5
    |> inc
    |> double
  eq result, 12

test "multiline pipe (trailing |>)", ->
  inc    = (x) -> x + 1
  double = (x) -> x * 2
  result = 5 |>
    inc |>
    double
  eq result, 12

test "pipe has lower precedence than +", ->
  inc = (x) -> x + 1
  eq (2 + 3 |> inc), 6    # (2 + 3) |> inc = inc(5) = 6

test "pipe as expression in assignment", ->
  double = (x) -> x * 2
  x = 5 |> double
  eq x, 10

test "pipe with match expression", ->
  classify = (n) ->
    match n
    | 0        -> "zero"
    | n if n > 0 -> "positive"
    | _        -> "negative"

  result = -3 |> classify
  eq result, "negative"
```

---

## Étape 8 — Phase 2 : Placeholder `%`

Pour les cas où l'argument piped ne doit PAS être en première position,
on peut étendre la syntaxe avec un placeholder explicite :

```coffee
# Phase 2 — non implémenté en Phase 1
[1, 2, 3]
  |> reduce(fn, %)          # % = valeur pipée en dernière position
  |> fn(0, %, extra)        # % = position explicite

# Équivalent :
reduce(fn, [1, 2, 3])
fn(0, reducedResult, extra)
```

**Impact lexer** : `%` est déjà l'opérateur modulo. Le placeholder ne serait
actif qu'à l'intérieur d'un contexte `|>`. Cette feature est plus complexe
(besoin de détecter le contexte dans le nœud) et est donc reportée.

---

## Résumé des fichiers modifiés

| Fichier                    | Modification                                              |
|----------------------------|-----------------------------------------------------------|
| `src/lexer.coffee`         | Ajouter `\|>` à `OPERATOR`, `'PIPE'` dans `literalToken`, `\|>` dans `LINE_CONTINUER` |
| `src/rewriter.coffee`      | Ajouter `'PIPE'` à `UNFINISHED`                           |
| `src/grammar.coffee`       | Ajouter `'Expression PIPE Expression'` dans `Operation`, `['left', 'PIPE']` dans `operators` |
| `src/nodes.coffee`         | Ajouter classe `PipeOp`                                   |
| `test/pipe_operator.coffee`| Suite de tests complète                                   |

---

## Problèmes connus et arbitrages

### Conflit potentiel avec `MATCH_PIPE`

La désambiguïsation de `|` (MATCH_PIPE) et `|>` (PIPE) est automatique :
`|>` est un token de **2 caractères** reconnu par le regex `OPERATOR` AVANT
que le single-char `|` soit jamais considéré. Il n'y a aucun conflit.

```
Chunk "|>"  → OPERATOR regex match → PIPE token (2 chars consommés)
Chunk "|"   → OPERATOR no match    → single char → '|' ou MATCH_PIPE selon contexte
```

### `|>` multilignes vs indentation

Quand `|>` est en tête de ligne sur une ligne PLUS INDENTÉE :

```coffee
result =
  getData()
    |> process     # indent > getData() → INDENT émis, puis |> → LINE_CONTINUER supprime le TERMINATOR
```

La combinaison de `LINE_CONTINUER` et du traitement `INDENT/OUTDENT` existant
devrait gérer ce cas. À valider lors des tests d'intégration.

### Pipe et `return` implicite

Dans un body de fonction, le résultat d'un pipe est retourné implicitement :

```coffee
transform = (x) ->
  x
  |> step1
  |> step2
# → function(x) { return step2(step1(x)); }
```

Cela fonctionne car `PipeOp` n'est pas un `Statement`, donc `makeReturn()`
du `Block` parent enveloppe le résultat normalement.

### Performance

L'opérateur pipe compile en appels de fonctions imbriqués — identique à
l'écriture manuelle. Zéro overhead au runtime. Pas d'IIFE, pas de closures
supplémentaires.

---

## Feuille de route

### Phase 1 (MVP)
- [x] Token `PIPE` pour `|>`
- [x] Précédence correcte (plus basse que `||`, plus haute que `=`)
- [x] Sémantique data-first : `a |> f b, c` → `f(a, b, c)`
- [x] Pipe vers identifiant : `a |> f` → `f(a)`
- [x] Pipe vers méthode : `a |> obj.method` → `obj.method(a)`
- [x] Pipe vers lambda : `a |> (x) -> x * 2` → `((x) => x*2)(a)`
- [x] Multilignes (trailing et leading `|>`)
- [x] Left-associativité : `a |> f |> g` → `g(f(a))`
- [x] Intégration avec immutabilité

### Phase 2
- [ ] Placeholder `%` pour positionnement explicite : `a |> f(b, %, c)`
- [ ] Pipe avec partial application automatique (currying optionnel)
- [ ] Pipe tap (side-effect sans modifier la valeur) : `a |>> console.log`
- [ ] Pipe async : `a |>> fetchData` (await implicite dans contexte async)
