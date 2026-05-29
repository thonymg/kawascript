# Block B — Ergonomie du Pipe : Placeholder `_` et Composition `>>=`

## Prérequis

- **Block A complété** : le compilateur doit bootstrapper correctement avant d'ajouter
  de nouveaux tokens.

## Statut actuel

| Feature | État |
|---------|------|
| `_` comme placeholder de pipe | ❌ `_` identifiant pris → ambiguïté avec usages lodash/discard existants |
| `>>=` composition forward | ❌ `>>=` est le compound-assign de shift-droit |

Vérification :
```
5 |> add _ 3   →  add _(3)(5)   # FAUX — _ est un identifiant
h = f >>= g    →  h = (f >>= g) # FAUX — >>= = compound assign
```

## Spécification

```coffee
# Placeholder : _ = valeur pipée, position explicite
"hello" |> slice _, 1, 3    # → slice("hello", 1, 3)
users   |> reduce _, 0, fn  # → reduce(users, 0, fn)

# Composition forward : f >>= g = (x) -> g(f(x))
transform = double >>= inc   # → (x) -> inc(double(x))
5 |> double >>= inc          # → inc(double(5)) = 11
```

> `_` et `>>=` sont interdépendants car ils font partie de la même PR de refactoring
> du lexer (précédences) et des mêmes tests "pipeline ergonomique".

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

### Fichier : `test/pipe_operator.coffee`

Ajouter une nouvelle section "PHASE 2 — ERGONOMIE" :

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# 12. PLACEHOLDER _
# ─────────────────────────────────────────────────────────────────────────────

test "placeholder _ — valeur pipée en position non-première", ->
  slice = (str, start, end) -> str.slice start, end
  eq ("hello" |> slice _, 1, 3), "ell"

test "placeholder _ — valeur pipée comme dernier argument", ->
  myReduce = (init, fn, data) -> data.reduce fn, init
  result = [1, 2, 3] |> myReduce 0, ((a, b) -> a + b), _
  eq result, 6

test "placeholder _ — compiles to positional insert", ->
  eqJS """
    slice = (str, start, end) -> str.slice start, end
    result = "hello" |> slice _, 1, 3
  """, """
    const slice = function(str, start, end) {
      return str.slice(start, end);
    };
    const result = slice("hello", 1, 3);
  """

test "placeholder _ — multiple placeholders are invalid (syntax error expected)", ->
  throws (-> CoffeeScript.compile "a |> f _, _"), /placeholder/

# ─────────────────────────────────────────────────────────────────────────────
# 13. COMPOSITION >>= 
# ─────────────────────────────────────────────────────────────────────────────

test "composition >>= — f >>= g = (x) -> g(f(x))", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = double >>= inc
  eq transform(5), 11

test "composition >>= est left-associative", ->
  a = (x) -> x + 1
  b = (x) -> x * 2
  c = (x) -> x - 3
  # (a >>= b) >>= c = (x) -> c(b(a(x)))
  eq ((a >>= b >>= c)(4)), c(b(a(4)))

test "composition >>= — compiles to function wrapping", ->
  eqJS """
    transform = double >>= inc
  """, """
    const transform = function(__x) {
      return inc(double(__x));
    };
  """

test "pipe avec composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double >>= inc), 11

test "chaîne de composition puis pipe", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  negate = (x) -> -x
  transform = double >>= inc >>= negate
  eq (5 |> transform), -11
```

---

## Étape 2 — Implémentation

### 2a. Placeholder `_`

**Fichier** : `src/lexer.coffee`

`_` est déjà un **identifiant valide** en CoffeeScript (le regex `IDENTIFIER` inclut `[$\w\x7f-\uffff]+`
— ligne ~1279 de lexer.coffee). Il est lexé en `IDENTIFIER` avec valeur `'_'`, pas en opérateur.
`_` n'apparaît pas comme variable locale dans les méthodes de `src/lexer.coffee` concernées.

**Aucune modification du lexer**. La désambiguïsation se fait uniquement au niveau du
**nœud PipeOp** : quand un argument du call est un `IdentifierLiteral` de valeur `'_'`
sans propriétés, c'est le placeholder.

Avantage de `_` sur `%` : token `IDENTIFIER` (comparaison directe `v.value is '_'`)
vs `%` qui était un token `MATH` binaire — impossible à utiliser seul grammaticalement.
Convention FP universelle : Haskell, Elm, OCaml, Scala utilisent `_` comme wildcard.

> Aucune modification du lexer pour `_` — le nœud PipeOp gère la substitution.

### 2b. Nouveau token `COMPOSE_FWD`

**Fichier** : `src/lexer.coffee`

`>>=` est actuellement dans `COMPOUND_ASSIGN` (ligne ~1429) :
```coffee
COMPOUND_ASSIGN = [
  '-=', '+=', '/=', '*=', '%=', '||=', '&&=', '?=', '<<=', '>>=', '>>>='  # ← >>=
  '&=', '^=', '|=', '**=', '//=', '%%='
]
```

Cela signifie que `a >>= 3` (right-shift-assign) ne fonctionnera plus — **breaking change
délibéré** : `>>=` est repurposé pour la composition de fonctions.

`<<` et `>>` (bitshift) restent intacts dans `SHIFT = ['<<', '>>', '>>>']`.

Diff dans `src/lexer.coffee` :

```diff
# Ligne ~1429 — retirer >>= de COMPOUND_ASSIGN
 COMPOUND_ASSIGN = [
-  '-=', '+=', '/=', '*=', '%=', '||=', '&&=', '?=', '<<=', '>>=', '>>>='  
+  '-=', '+=', '/=', '*=', '%=', '||=', '&&=', '?=', '<<=', '>>>='  # >>= retiré
   '&=', '^=', '|=', '**=', '//=', '%%='
 ]
```

Dans `literalToken`, ajouter **avant** le check `COMPOUND_ASSIGN` (ligne ~804) :

```diff
    else if value in MATH            then tag = 'MATH'
    else if value in COMPARE         then tag = 'COMPARE'
+   else if value is '>>='           then tag = 'COMPOSE_FWD'
    else if value in COMPOUND_ASSIGN then tag = 'COMPOUND_ASSIGN'
```

Le regex `OPERATOR` (~ligne 1326) capture déjà `>>=` comme token 3 chars via
`([&|<>*/%])\2=?` — aucune modification du regex nécessaire.

Ajouter `COMPOSE_FWD` à `UNFINISHED` :
```diff
exports.UNFINISHED = UNFINISHED = [...,
-  'BIN?', 'EXTENDS', 'PIPE']
+  'BIN?', 'EXTENDS', 'PIPE', 'COMPOSE_FWD']
```

### 2c. Règles grammaticales

**Fichier** : `src/grammar.coffee`

Dans `Operation` (bloc des opérateurs binaires), ajouter après la règle PIPE :

```coffee
o 'Expression COMPOSE_FWD Expression', -> new ComposeOp $1, $3
```

Dans `operators` (table de précédences), ajouter **au-dessus** de PIPE :

```coffee
['left', 'COMPOSE_FWD']  # plus haut que PIPE
['left', 'PIPE']
```

> `>>=` doit avoir une précédence PLUS HAUTE que `|>` pour que
> `5 |> double >>= inc` parse comme `5 |> (double >>= inc)`.

### 2d. Nœud `ComposeOp`

**Fichier** : `src/nodes.coffee`

Ajouter après la classe `PipeOp` :

```coffee
#### ComposeOp

# La composition de fonctions : `f >>= g` = `(x) -> g(f(x))`
exports.ComposeOp = class ComposeOp extends Base
  constructor: (@left, @right) -> super()
  children: ['left', 'right']
  isStatement: NO

  compileNode: (o) ->
    # Générer un nom de variable temporaire unique pour le paramètre
    paramName = o.scope.freeVariable '__x', reserve: yes

    # f >>= g  =  (x) -> g(f(x))
    innerCall = new Call @left,  [new IdentifierLiteral paramName]
    outerCall = new Call @right, [innerCall]
    body = new Block [outerCall]
    lambda = new Code [new Param new IdentifierLiteral(paramName)], body
    lambda.compileToFragments o, LEVEL_PAREN
```

### 2e. Placeholder `_` dans `PipeOp.compilePipeIntoCall`

**Fichier** : `src/nodes.coffee`, méthode `PipeOp.compilePipeIntoCall`

`_` est un `IdentifierLiteral` avec valeur `'_'` — la détection est directe :

```diff
  compilePipeIntoCall: (o, leftFrags, call) ->
    fnFrags  = call.variable.compileToFragments o, LEVEL_ACCESS
-   argFrags = [].concat leftFrags
+
+   # Détecter la présence d'un placeholder _
+   # _ est un IdentifierLiteral — convention FP universelle (Haskell, Elm, OCaml)
+   isPlaceholder = (a) ->
+     v = a.unwrap()
+     v instanceof IdentifierLiteral and v.value is '_' and not v.properties?.length
+
+   if call.args.some isPlaceholder
+     argFrags = []
+     for arg in call.args
+       if isPlaceholder arg
+         argFrags = argFrags.concat leftFrags
+       else
+         argFrags.push @makeCode ', '  unless argFrags.length is 0
+         argFrags = argFrags.concat arg.compileToFragments o, LEVEL_LIST
+   else
+     argFrags = [].concat leftFrags
     for arg in call.args
       argFrags.push @makeCode ', '
       argFrags = argFrags.concat arg.compileToFragments o, LEVEL_LIST

    [].concat fnFrags, [@makeCode '('], argFrags, [@makeCode ')']
```

> **Ambiguïté `_` comme identifiant existant** : si un pipe call passe une vraie
> variable nommée `_` (lodash : `_ = require 'lodash'`), elle serait interprétée
> comme placeholder. En pratique, lodash s'utilise via ses méthodes (`_.map`, etc.),
> pas en passant `_` nu en argument — la collision est rare. Si nécessaire, utiliser
> la syntaxe explicite `f(_, x)` pour passer la variable `_` sans ambiguïté.

---

## Checklist de livraison

- [ ] `>>=` n'est plus un compound-assign : `f >>= g` produit une composition
- [ ] `>>` et `<<` restent des bitshifts valides (SHIFT inchangé)
- [ ] `>>>` reste valide (SHIFT inchangé)
- [ ] `<<=` reste valide (dans COMPOUND_ASSIGN, non modifié)
- [ ] `_` dans pipe → positionnement explicite de la valeur pipée
- [ ] `_` hors contexte pipe reste un identifiant normal
- [ ] Tests composition : tous les tests "COMPOSITION >>=" passent
- [ ] Tests placeholder : tous les tests "PLACEHOLDER _" passent
- [ ] `node ./bin/cake test` — 0 régression
