# Plan d'implémentation : Pattern Matching

> **Philosophie** : Le pattern matching est l'outil naturel pour brancher
> sur la forme d'une valeur. Il remplace les `switch/when` verbeux et les
> cascades `if/else if` fragiles. Il doit être une **expression** (retourne
> une valeur), être **exhaustif** par construction, et s'intégrer
> naturellement dans la syntaxe KawaScript.

---

## Syntaxe cible

```coffee
describe = (n) ->
  match n
  | 0 -> "zero"
  | 1 -> "one"
  | n if n < 0 -> "negative"
  | _ -> "many"
```

---

## Références dans d'autres langages

### OCaml / F# (inspiration principale)
```ocaml
match n with
| 0 -> "zero"
| 1 -> "one"
| n when n < 0 -> "negative"
| _ -> "many"
```
**Points forts** : syntaxe `|` par branche, wildcard `_`, liaison de variable,
`when` pour les guards. KawaScript utilise `if` (plus familier) à la place de `when`.

### Rust
```rust
match n {
    0 => "zero",
    1 => "one",
    n if n < 0 => "negative",
    _ => "many",
}
```
**Points forts** : patterns destructurés (`(x, y)`, `Some(v)`), guards, exhaustivité
vérifiée à la compilation. KawaScript s'inspire du guard `n if n < 0`.

### Haskell (case expression)
```haskell
case n of
  0 -> "zero"
  1 -> "one"
  n | n < 0 -> "negative"
  _ -> "many"
```
**Points forts** : tout est expression, pas de `break` nécessaire, guards avec `|`.
Inspire l'idée que `match` est une expression en KawaScript.

### Elixir
```elixir
case n do
  0 -> "zero"
  1 -> "one"
  n when n < 0 -> "negative"
  _ -> "many"
end
```
**Points forts** : guards avec `when`, pattern matching sur types et structures.

### Scala 3
```scala
n match
  case 0 => "zero"
  case 1 => "one"
  case n if n < 0 => "negative"
  case _ => "many"
```
**Points forts** : `case` par branche, guards avec `if`, destructuration riche.
Même convention `if` pour les guards que KawaScript.

### Gleam
```gleam
case n {
  0 -> "zero"
  1 -> "one"
  n if n < 0 -> "negative"
  _ -> "many"
}
```
**Points forts** : langage récent, syntaxe épurée, guards `if`, wildcard `_`.

### Bilan comparatif

| Fonctionnalité            | OCaml | Rust | Haskell | Scala | KawaScript (cible) |
|---------------------------|-------|------|---------|-------|--------------------|
| Séparateur de branche     | `\|`  | `n =>` | `n ->` | `case n =>` | `\| n ->` |
| Wildcard                  | `_`   | `_`  | `_`     | `_`   | `_`                |
| Liaison de variable       | `n`   | `n`  | `n`     | `n`   | `n`                |
| Guard                     | `when`| `if` | `\|`    | `if`  | `if`               |
| Expression (retourne)     | ✓     | ✓    | ✓       | ✓     | ✓                  |
| Destructuration tableau   | ✓     | ✓    | ✓       | ✓     | Phase 2            |
| Destructuration objet     | ✓     | ✓    | ✗       | ✓     | Phase 2            |
| Exhaustivité vérifiée     | ✓     | ✓    | warn    | ✓     | Phase 2 (warn)     |

---

## Catalogue des patterns (Phase 1 → Phase 2)

### Phase 1 — Patterns scalaires

| Pattern          | Exemple                    | Sémantique                          |
|------------------|----------------------------|-------------------------------------|
| Littéral entier  | `\| 42 ->`                 | `=== 42`                            |
| Littéral flottant| `\| 3.14 ->`               | `=== 3.14`                          |
| Littéral string  | `\| "ok" ->`               | `=== "ok"`                          |
| Littéral bool    | `\| true ->` / `\| false ->`| `=== true`                         |
| Null / undefined | `\| null ->` / `\| undefined ->`| comparaison stricte             |
| Wildcard         | `\| _ ->`                  | toujours vrai, pas de liaison       |
| Liaison variable | `\| n ->`                  | toujours vrai, lie `n` à la valeur  |
| Guard            | `\| n if n < 0 ->`         | vrai si la condition est remplie    |
| Or-pattern       | `\| 0, 1 ->`               | `=== 0 \|\| === 1`                  |

### Phase 2 — Patterns structuraux

| Pattern             | Exemple                        | Sémantique                          |
|---------------------|--------------------------------|-------------------------------------|
| Tableau exact       | `\| [0, 1] ->`                 | longueur + valeurs                  |
| Tableau partiel     | `\| [head, ...tail] ->`        | au moins 1 élément, rest binding    |
| Objet              | `\| {x, y} ->`                 | propriétés présentes, liaisons      |
| Objet partiel       | `\| {type: "circle", r} ->`    | `type === "circle"`, lie `r`        |
| Plage              | `\| 1..10 ->`                  | `>= 1 && <= 10`                     |
| Type               | `\| instanceof Error ->`       | `instanceof Error`                  |
| Patterns imbriqués  | `\| {items: [first, ...]} ->`  | combinaison                         |

---

## Architecture de l'implémentation

L'implémentation suit le pipeline standard de KawaScript :

```
Source .coffee
    │
    ▼
┌─────────┐   MATCH token          ┌─────────────┐
│  Lexer  │──────────────────────► │   Parser    │
│         │   MATCH_PIPE token     │   (Jison)   │
│         │──────────────────────► │             │
└─────────┘                        └──────┬──────┘
                                          │ AST
                                          ▼
                                   ┌─────────────┐
                                   │    Nodes    │
                                   │ MatchNode   │
                                   │ MatchArm    │
                                   │ PatternNode │
                                   └──────┬──────┘
                                          │ compileNode()
                                          ▼
                                   JavaScript (if/else chain)
```

---

## Étape 1 — Lexer (`src/lexer.coffee`)

### 1a. Nouveau mot-clé `match`

```coffee
# Dans COFFEE_KEYWORDS :
COFFEE_KEYWORDS = [
  'undefined', 'Infinity', 'NaN'
  'then', 'unless', 'until', 'loop', 'of', 'by', 'when'
  'let', 'match'                          # ← ajout de 'match'
]
```

### 1b. Désambiguïsation de `|`

Le caractère `|` est déjà utilisé comme opérateur OR binaire (`a | b`).
À l'intérieur d'un bloc `match`, un `|` en début de ligne doit devenir
`MATCH_PIPE` (comme `WHEN` devient `LEADING_WHEN`).

**Technique** : dans `literalToken()`, détecter `|` précédé d'un `LINE_BREAK` :

```coffee
# Dans literalToken(), après la gestion des autres symboles :
if value is '|' and @tag() in LINE_BREAK
  @token 'MATCH_PIPE', value
  return 1
```

Cette technique est identique à celle de `LEADING_WHEN` dans `identifierToken()`.
Elle fonctionne parce que `a | b` n'est jamais précédé d'un saut de ligne
dans un usage normal d'opérateur binaire (le rewriter interdit les lignes
se terminant sur un opérande gauche isolé).

### 1c. Wildcard `_`

`_` est déjà un identifiant valide en CoffeeScript. Le traitement spécial
(« jamais lié, toujours vrai ») sera géré au niveau du nœud AST `PatternNode`,
pas du lexer.

---

## Étape 2 — Grammaire (`src/grammar.coffee`)

### 2a. Ajout du non-terminal `Match`

```coffee
Match: [
  o 'MATCH Expression INDENT MatchArms OUTDENT',
    -> new MatchNode $2, $4
  o 'MATCH ExpressionLine INDENT MatchArms OUTDENT',
    -> new MatchNode $2, $4
]

MatchArms: [
  o 'MatchArm',              -> [$1]
  o 'MatchArms MatchArm',    -> $1.concat $2
]

MatchArm: [
  # | pattern ->  body
  o 'MATCH_PIPE MatchPattern ARROW Block',
    -> new MatchArm $2, null, $4
  # | pattern if guard -> body
  o 'MATCH_PIPE MatchPattern IF Expression ARROW Block',
    -> new MatchArm $2, $4, $6
  # Avec TERMINATOR optionnel
  o 'MATCH_PIPE MatchPattern ARROW Block TERMINATOR',
    -> LOC(1, 4) new MatchArm $2, null, $4
  o 'MATCH_PIPE MatchPattern IF Expression ARROW Block TERMINATOR',
    -> LOC(1, 6) new MatchArm $2, $4, $6
]

MatchPattern: [
  o 'Literal',               -> new LiteralPattern $1
  o 'IDENTIFIER',            -> new BindingPattern $1      # lie la valeur à un nom
  o '_',                     -> new WildcardPattern        # _ est un IDENTIFIER
  o 'NULL',                  -> new LiteralPattern new NullLiteral $1
  o 'UNDEFINED',             -> new LiteralPattern new UndefinedLiteral $1
  o 'BOOL',                  -> new LiteralPattern new BooleanLiteral $1.toString()
  # Or-pattern : | 0, 1 ->
  o 'MatchPattern , MatchPattern',
    -> new OrPattern $1, $3
]
```

> **Note** : `_` est lexé comme `IDENTIFIER` avec la valeur `"_"`.
> `BindingPattern` détecte ce cas et crée un `WildcardPattern` à la place.

### 2b. Enregistrement de `Match` dans `Expression`

```coffee
Expression: [
  # ... toutes les règles existantes ...
  o 'Match'            # ← ajout
]
```

### 2c. Précédence pour `MATCH` et `MATCH_PIPE`

```coffee
operators = [
  # ... règles existantes ...
  ['right', 'MATCH']
  ['right', 'MATCH_PIPE']
]
```

---

## Étape 3 — Nœuds AST (`src/nodes.coffee`)

### 3a. `PatternNode` (classe de base)

```coffee
# Classe de base pour tous les patterns
class PatternNode extends Base
  # Retourne des fragments de code représentant
  # la condition de test : subject === value, etc.
  # @param o       - options de compilation
  # @param subject - les fragments CodeFragment du sujet (ex: `__m0__`)
  compileTest: (o, subject) -> throw new Error 'abstract'

  # Retourne un objet { name, fragments } pour chaque variable liée
  # dans ce pattern (pour injection dans le corps de la branche).
  bindings: -> []

  isWildcard: -> no
```

### 3b. `LiteralPattern`

```coffee
class LiteralPattern extends PatternNode
  constructor: (@literal) -> super()
  children: ['literal']

  compileTest: (o, subjectCode) ->
    [].concat subjectCode,
      @makeCode(' === '),
      @literal.compileToFragments(o, LEVEL_PAREN)

  bindings: -> []
```

### 3c. `BindingPattern`

```coffee
class BindingPattern extends PatternNode
  constructor: (@name) -> super()

  isWildcard: -> @name is '_'

  # Wildcard et binding sont toujours vrais (pas de test)
  compileTest: (o, subjectCode) -> [@makeCode 'true']

  bindings: ->
    return [] if @isWildcard()
    [@name]
```

### 3d. `OrPattern`

```coffee
class OrPattern extends PatternNode
  constructor: (@left, @right) -> super()
  children: ['left', 'right']

  compileTest: (o, subjectCode) ->
    leftTest  = @left.compileTest(o, subjectCode)
    rightTest = @right.compileTest(o, subjectCode)
    [].concat leftTest, [@makeCode(' || ')], rightTest

  bindings: -> []   # or-patterns n'introduisent pas de liaisons
```

### 3e. `MatchArm`

```coffee
class MatchArm extends Base
  constructor: (@pattern, @guard, @body) -> super()
  children: ['pattern', 'guard', 'body']

  # Compile l'arm en une branche if.
  # @param o           - options de compilation
  # @param subjectFrags - les CodeFragment pour la variable sujet
  # @param isFirst     - si vrai, émet `if`, sinon `else if`
  compileArm: (o, subjectFrags, isFirst) ->
    idt  = o.indent
    idt2 = idt + TAB
    o2   = merge o, indent: idt2

    # 1. Construire la condition
    condFrags = @pattern.compileTest(o2, subjectFrags)
    if @guard
      guardFrags = @guard.compileToFragments(o2, LEVEL_PAREN)
      condFrags  = [].concat condFrags, [@makeCode(' && ')], guardFrags

    keyword = if isFirst then 'if' else 'else if'

    # 2. Injecter les liaisons de variables dans le corps
    bodyWithBindings = @injectBindings(o2, subjectFrags)

    # 3. Assembler
    [].concat(
      [@makeCode("#{idt}#{keyword} (")],
      condFrags,
      [@makeCode(') {\n')],
      bodyWithBindings,
      [@makeCode("\n#{idt}}")]
    )

  # Génère les `const name = __m__` en tête du corps de branche
  injectBindings: (o, subjectFrags) ->
    fragments = []
    for name in @pattern.bindings()
      fragments = fragments.concat(
        [@makeCode("#{o.indent}const #{name} = ")],
        subjectFrags,
        [@makeCode(';\n')]
      )
    fragments.concat @body.compileToFragments(o, LEVEL_TOP)
```

### 3f. `MatchNode` — le nœud principal

```coffee
exports.MatchNode = class MatchNode extends Base
  constructor: (@subject, @arms) -> super()
  children: ['subject', 'arms']

  isStatement: YES

  makeReturn: (results, mark) ->
    for arm in @arms
      arm.body.makeReturn results, mark
    this

  compileNode: (o) ->
    # Générer un nom de variable temporaire unique pour le sujet
    tempName  = o.scope.freeVariable 'm'
    idt       = @tab
    idt2      = idt + TAB
    o2        = merge o, indent: idt2

    subjectFrags = [@makeCode(tempName)]

    # const __m0__ = <subject>
    declFrags = [].concat(
      [@makeCode("#{idt}const #{tempName} = ")],
      @subject.compileToFragments(o2, LEVEL_PAREN),
      [@makeCode(';\n')]
    )

    # Compiler chaque bras
    armFrags = []
    for arm, i in @arms
      armFrags = armFrags.concat(
        arm.compileArm(o2, subjectFrags, i is 0)
      )
      armFrags.push @makeCode('\n') if i < @arms.length - 1

    # Dernier bras wildcard → `else` (optimisation cosmétique)
    # (géré automatiquement car `true` && pas de guard → condition triviale)

    [].concat declFrags, armFrags
```

---

## Étape 4 — Génération de code JavaScript

### Exemple de compilation

**Entrée KawaScript :**

```coffee
describe = (n) ->
  match n
  | 0 -> "zero"
  | 1 -> "one"
  | n if n < 0 -> "negative"
  | _ -> "many"
```

**Sortie JavaScript :**

```javascript
const describe = function(n) {
  const __m0__ = n;
  if (__m0__ === 0) {
    return "zero";
  } else if (__m0__ === 1) {
    return "one";
  } else if (__m0__ < 0) {
    const n = __m0__;
    return "negative";
  } else if (true) {
    return "many";
  }
};
```

> **Note** : le dernier bras `| _` génère `else if (true)` — le compilateur
> peut l'optimiser en `else` si le wildcard est la dernière branche.

### Exemple avec or-pattern

**Entrée :**
```coffee
classify = (c) ->
  match c
  | "a", "e", "i", "o", "u" -> "vowel"
  | _ -> "consonant"
```

**Sortie :**
```javascript
const classify = function(c) {
  const __m0__ = c;
  if (__m0__ === "a" || __m0__ === "e" || __m0__ === "i" || __m0__ === "o" || __m0__ === "u") {
    return "vowel";
  } else {
    return "consonant";
  }
};
```

### Exemple avec liaison de variable

**Entrée :**
```coffee
transform = (x) ->
  match x
  | 0 -> "none"
  | n -> "got #{n}"
```

**Sortie :**
```javascript
const transform = function(x) {
  const __m0__ = x;
  if (__m0__ === 0) {
    return "none";
  } else if (true) {
    const n = __m0__;
    return `got ${n}`;
  }
};
```

---

## Étape 5 — Immutabilité et `match`

Le `match` s'intègre naturellement avec le modèle d'immutabilité de KawaScript :

- La variable temporaire `__m0__` est `const` (valeur du sujet gelée).
- Les liaisons de variables dans les bras (`const n = __m0__`) sont `const`.
- Si une liaison doit être mutable, l'utilisateur doit utiliser `let` dans
  le corps de la branche (pas dans le pattern lui-même).

```coffee
# Liaison const (défaut)
result = match x
  | 0 -> "zero"
  | n -> "#{n}"      # n est const dans ce bras

# Si le corps a besoin de mutabilité :
result = match x
  | n ->
    let acc = n
    acc = acc * 2
    acc
```

---

## Étape 6 — Tests (`test/pattern_matching.coffee`)

```coffee
# test/pattern_matching.coffee

test "literal patterns", ->
  f = (n) ->
    match n
    | 0 -> "zero"
    | 1 -> "one"
    | _ -> "other"

  eq f(0), "zero"
  eq f(1), "one"
  eq f(2), "other"

test "guard patterns", ->
  sign = (n) ->
    match n
    | 0 -> "zero"
    | n if n > 0 -> "positive"
    | _ -> "negative"

  eq sign(0),  "zero"
  eq sign(5),  "positive"
  eq sign(-3), "negative"

test "variable binding", ->
  double = (x) ->
    match x
    | 0 -> 0
    | n -> n * 2

  eq double(0), 0
  eq double(7), 14

test "or-pattern", ->
  isVowel = (c) ->
    match c
    | "a", "e", "i", "o", "u" -> yes
    | _ -> no

  eq isVowel("a"), yes
  eq isVowel("b"), no

test "match as expression", ->
  x = 3
  label = match x
    | 1 -> "one"
    | 2 -> "two"
    | _ -> "many"
  eq label, "many"

test "string patterns", ->
  greet = (lang) ->
    match lang
    | "fr" -> "Bonjour"
    | "en" -> "Hello"
    | "es" -> "Hola"
    | _    -> "..."

  eq greet("fr"), "Bonjour"
  eq greet("de"), "..."
```

---

## Étape 7 — Vérification d'exhaustivité (Phase 2)

Un match sans branche `| _` (wildcard) ou sans couverture complète génère
un warning à la compilation :

```
Warning: match expression may not be exhaustive.
  Consider adding a wildcard branch: | _ -> ...
  at line 3, column 2
```

Implémentation : dans `MatchNode.compileNode()`, vérifier si le dernier bras
est un wildcard ou un binding sans guard. Si ce n'est pas le cas, émettre
un warning et injecter automatiquement un `else { throw new Error('Non-exhaustive match') }`.

---

## Feuille de route

### Phase 1 (MVP)
- [x] Syntaxe de base : `match subject \| pattern -> body`
- [x] Patterns littéraux (nombres, strings, booleans, null, undefined)
- [x] Wildcard `_`
- [x] Liaison de variable (`| n ->`)
- [x] Guard (`| n if n < 0 ->`)
- [x] Or-pattern (`| 0, 1 ->`)
- [x] `match` comme expression (retourne une valeur)
- [x] Intégration avec l'immutabilité (const pour le sujet et les liaisons)

### Phase 2
- [ ] Patterns de tableau : `| [head, ...tail] ->`, `| [x, y] ->`
- [ ] Patterns d'objet : `| {x, y} ->`, `| {type: "circle", r} ->`
- [ ] Patterns de plage : `| 1..10 ->`
- [ ] Pattern instanceof : `| instanceof Error ->`
- [ ] Patterns imbriqués
- [ ] Vérification d'exhaustivité (warning + throw automatique)
- [ ] AST complet pour le tooling (autocomplétion, type inference)

### Phase 3
- [ ] Patterns de type nominal (avec `class`)
- [ ] Refutable vs irrefutable patterns
- [ ] Integration with async/await (match on Promise states)

---

## Problèmes connus et arbitrages

### Ambiguïté de `|`

`|` est déjà l'opérateur bitwise OR. La désambiguïsation repose sur le fait
que `MATCH_PIPE` n'est émis que lorsque `|` est en tête de ligne (précédé
d'un `LINE_BREAK`). Un cas limite :

```coffee
# Ambigu ? Non — le parser sait qu'on est dans un bloc match
x = match n
  | a | b -> a  # `a | b` ici est bitwise OR (opérateur infix, pas en tête de ligne)
```

La règle de tokenization est : `|` est `MATCH_PIPE` si et seulement si le
token précédent est dans `LINE_BREAK = ['INDENT', 'OUTDENT', 'TERMINATOR']`.
À l'intérieur d'une expression (comme `a | b`), `|` est toujours précédé d'un
token non-LINE_BREAK, donc reste `|` (bitwise OR). **Pas de conflit.**

### Variable binding vs référence

Dans `| n ->`, `n` est toujours une **liaison** (nouveau binding), jamais
une référence à une variable existante. Pour comparer à une variable
existante, utiliser un guard :

```coffee
expected = 42
match x
| _ if x is expected -> "match!"
| _ -> "nope"
```

Cette sémantique est identique à OCaml/Rust et évite l'ambiguïté.

### `match` comme mot-clé réservé

`match` devient un mot-clé réservé de KawaScript. Il s'ajoute à `COFFEE_KEYWORDS`
et ne peut plus être utilisé comme identifiant. Impact : minime, `match` n'est
pas un identifiant courant en JavaScript.

---

## Résumé des fichiers modifiés

| Fichier                  | Modification                                               |
|--------------------------|------------------------------------------------------------|
| `src/lexer.coffee`       | Ajouter `'match'` à `COFFEE_KEYWORDS`, émettre `MATCH_PIPE` |
| `src/grammar.coffee`     | Ajouter `Match`, `MatchArms`, `MatchArm`, `MatchPattern`   |
| `src/nodes.coffee`       | Ajouter `MatchNode`, `MatchArm`, `LiteralPattern`, `BindingPattern`, `OrPattern` |
| `test/pattern_matching.coffee` | Suite de tests complète                             |
