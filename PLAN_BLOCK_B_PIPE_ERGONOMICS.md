# Block B — Ergonomie du Pipe : Placeholder `%` et Composition `>>`/`<<`

## Prérequis

- **Block A complété** : le compilateur doit bootstrapper correctement avant d'ajouter
  de nouveaux tokens.

## Statut actuel

| Feature | État |
|---------|------|
| `%` comme placeholder de pipe | ❌ `%` est le modulo — parsing incorrect |
| `>>` composition forward | ❌ `>>` est le décalage bit-à-droite |
| `<<` composition backward | ❌ `<<` est le décalage bit-à-gauche |

Vérification :
```
5 |> add % 3   →  add % 3(5)   # FAUX — % = modulo
h = f >> g     →  h = f >> g   # FAUX — >> = bitshift
```

## Spécification

```coffee
# Placeholder : % = valeur pipée, position explicite
"hello" |> slice %, 1, 3    # → slice("hello", 1, 3)
users   |> reduce %, 0, fn  # → reduce(users, 0, fn)

# Composition forward : f >> g = (x) -> g(f(x))
transform = double >> inc   # → (x) -> inc(double(x))
5 |> double >> inc          # → inc(double(5)) = 11

# Composition backward : f << g = (x) -> f(g(x))
transform = inc << double   # → (x) -> inc(double(x))   (même résultat, ordre déclaratif inversé)
```

> `%` et `>>` sont interdépendants car ils font partie de la même PR de refactoring
> du lexer (précédences) et des mêmes tests "pipeline ergonomique".

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

### Fichier : `test/pipe_operator.coffee`

Ajouter une nouvelle section "PHASE 2 — ERGONOMIE" :

```coffee
# ─────────────────────────────────────────────────────────────────────────────
# 12. PLACEHOLDER %
# ─────────────────────────────────────────────────────────────────────────────

test "placeholder % — valeur pipée en position non-première", ->
  slice = (str, start, end) -> str.slice start, end
  eq ("hello" |> slice %, 1, 3), "ell"

test "placeholder % — valeur pipée comme dernier argument", ->
  myReduce = (init, fn, data) -> data.reduce fn, init
  result = [1, 2, 3] |> myReduce 0, ((a, b) -> a + b), %
  eq result, 6

test "placeholder % — compiles to positional insert", ->
  eqJS """
    slice = (str, start, end) -> str.slice start, end
    result = "hello" |> slice %, 1, 3
  """, """
    const slice = function(str, start, end) {
      return str.slice(start, end);
    };
    const result = slice("hello", 1, 3);
  """

test "placeholder % — multiple placeholders are invalid (syntax error expected)", ->
  throws (-> CoffeeScript.compile "a |> f %, %"), /placeholder/

# ─────────────────────────────────────────────────────────────────────────────
# 13. COMPOSITION >> ET <<
# ─────────────────────────────────────────────────────────────────────────────

test "composition >> — f >> g = (x) -> g(f(x))", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = double >> inc
  eq transform(5), 11

test "composition << — f << g = (x) -> f(g(x))", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  transform = inc << double   # inc(double(x))
  eq transform(5), 11

test "composition >> est left-associative", ->
  a = (x) -> x + 1
  b = (x) -> x * 2
  c = (x) -> x - 3
  # (a >> b) >> c = (x) -> c(b(a(x)))
  eq ((a >> b >> c)(4)), c(b(a(4)))

test "composition >> — compiles to IIFE wrapping", ->
  eqJS """
    transform = double >> inc
  """, """
    const transform = function(__x) {
      return inc(double(__x));
    };
  """

test "composition << — compiles to IIFE wrapping", ->
  eqJS """
    transform = inc << double
  """, """
    const transform = function(__x) {
      return inc(double(__x));
    };
  """

test "pipe avec composition", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  eq (5 |> double >> inc), 11

test "chaîne de composition puis pipe", ->
  double = (x) -> x * 2
  inc    = (x) -> x + 1
  negate = (x) -> -x
  transform = double >> inc >> negate
  eq (5 |> transform), -11
```

---

## Étape 2 — Implémentation

### 2a. Nouveau token `PIPE_PLACEHOLDER`

**Fichier** : `src/lexer.coffee`

Le `%` est TOUJOURS dans `MATH`. On ne peut pas le retirer car `a % b` doit rester valide.
La solution : le placeholder `%` n'est valide QU'à l'intérieur d'un appel de pipe.
La désambiguïsation se fait au niveau du **nœud PipeOp** (à la compilation), pas au lexer.

Le token `MATH` avec valeur `'%'` est réutilisé. PipeOp détectera sa présence dans
ses arguments et le remplacera par la valeur pipée.

> Aucune modification du lexer pour `%` — le nœud PipeOp gère la substitution.

### 2b. Nouveaux tokens `COMPOSE_FWD` et `COMPOSE_BWD`

**Fichier** : `src/lexer.coffee`

`>>` et `<<` sont actuellement dans `SHIFT`. Retirer `>>` et `<<` de `SHIFT` et
les gérer séparément :

```diff
# Ligne ~1439
-SHIFT = ['<<', '>>', '>>>']
+SHIFT = ['>>>']   # Garder seulement >>>
```

Dans `literalToken` (la fonction qui produit les tokens d'opérateurs) :

```diff
    else if value is '|>'       then tag = 'PIPE'
+   else if value is '>>'       then tag = 'COMPOSE_FWD'
+   else if value is '<<'       then tag = 'COMPOSE_BWD'
    else if value is '|' and @tag() in LINE_BREAK then tag = 'MATCH_PIPE'
```

Dans le regex `OPERATOR` (~ligne 1325), `>>` et `<<` sont déjà couverts par
`([&|<>*/%])\2=?`. L'ordre des conditions dans `literalToken` assure que `>>` → `COMPOSE_FWD`
est essayé AVANT `SHIFT`.

Ajouter `COMPOSE_FWD` et `COMPOSE_BWD` à `UNFINISHED` :
```diff
exports.UNFINISHED = UNFINISHED = [...,
-  'BIN?', 'EXTENDS', 'PIPE']
+  'BIN?', 'EXTENDS', 'PIPE', 'COMPOSE_FWD', 'COMPOSE_BWD']
```

### 2c. Règles grammaticales

**Fichier** : `src/grammar.coffee`

Dans `Operation` (bloc des opérateurs binaires), ajouter après la règle PIPE :

```coffee
o 'Expression COMPOSE_FWD Expression', -> new ComposeOp $1, $3, 'fwd'
o 'Expression COMPOSE_BWD Expression', -> new ComposeOp $1, $3, 'bwd'
```

Dans `operators` (table de précédences), ajouter **au-dessus** de PIPE :

```coffee
['left', 'COMPOSE_FWD', 'COMPOSE_BWD']  # plus haut que PIPE
['left', 'PIPE']
```

> `>>` doit avoir une précédence PLUS HAUTE que `|>` pour que
> `5 |> double >> inc` parse comme `5 |> (double >> inc)`.

### 2d. Nœud `ComposeOp`

**Fichier** : `src/nodes.coffee`

Ajouter après la classe `PipeOp` :

```coffee
#### ComposeOp

# La composition de fonctions : `f >> g` = `(x) -> g(f(x))`
#                               `f << g` = `(x) -> f(g(x))`
exports.ComposeOp = class ComposeOp extends Base
  constructor: (@left, @right, @direction) -> super()
  children: ['left', 'right']
  isStatement: NO

  compileNode: (o) ->
    # Générer un nom de variable temporaire unique pour le paramètre
    paramName = o.scope.freeVariable '__x', reserve: yes
    paramFrags = [@makeCode paramName]

    # Selon la direction, first(x) → second(result) ou l'inverse
    [first, second] = if @direction is 'fwd'
      [@left, @right]
    else
      [@right, @left]

    # Compiler first(x)
    innerCall = new Call first, [new IdentifierLiteral paramName]
    # Compiler second(innerCall)
    outerCall = new Call second, [innerCall]
    # Envelopper dans une lambda : (x) -> outerCall
    body = new Block [outerCall]
    lambda = new Code [new Param new IdentifierLiteral(paramName)], body
    lambda.compileToFragments o, LEVEL_PAREN
```

### 2e. Placeholder `%` dans `PipeOp.compilePipeIntoCall`

**Fichier** : `src/nodes.coffee`, méthode `PipeOp.compilePipeIntoCall`

Chercher un argument `MATH('%')` dans `call.args` et le remplacer par `leftFrags` :

```diff
  compilePipeIntoCall: (o, leftFrags, call) ->
    fnFrags  = call.variable.compileToFragments o, LEVEL_ACCESS
-   argFrags = [].concat leftFrags
+
+   # Détecter la présence d'un placeholder %
+   placeholderIdx = call.args.findIndex (a) ->
+     a.unwrap() instanceof Op and a.unwrap().operator is '%' and
+     a.unwrap().second is undefined  # unaire — impossible, mais guard de sécurité
+   # Forme plus simple : chercher un Value qui wraps un Op('%', undefined)
+   # En pratique : arg est une Value(Literal('%')) ou un MATH('%') nu
+   # → chercher `arg instanceof Value and arg.base?.value is '%' and not arg.properties.length`
+   hasPlaceholder = call.args.some (a) ->
+     v = a.unwrap()
+     v instanceof IdentifierLiteral and v.value is '%'

+   if hasPlaceholder
+     argFrags = []
+     for arg in call.args
+       v = arg.unwrap()
+       if v instanceof IdentifierLiteral and v.value is '%'
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

> **Note** : `%` dans le contexte d'un appel implicite `f %, x` — le `%` sera
> parsé comme `MATH('%')`. Il faut vérifier si le token correspond à un `Op` avec
> opérateur `%` et sans opérande gauche (unaire). En pratique, chercher si `arg`
> compile exactement en `%` suffit — via `arg.compileToFragments(o).map(f => f.code).join('') === '%'`.
> Utiliser cette approche si la détection par type de nœud s'avère difficile.

---

## Checklist de livraison

- [ ] `>>` n'est plus un bitshift : `f >> g` ne produit plus de bitshift
- [ ] `<<` n'est plus un bitshift : `f << g` ne produit plus de bitshift  
- [ ] `%` dans pipe → positionnement explicite de la valeur pipée
- [ ] `a % b` hors de pipe reste valide (modulo)
- [ ] Tests composition : tous les tests "COMPOSITION >> ET <<" passent
- [ ] Tests placeholder : tous les tests "PLACEHOLDER %" passent
- [ ] Tests existants de shift bitwise : confirmer `a >>> b` fonctionne toujours
- [ ] `node ./bin/cake test` — 0 régression
