# Block A — Bootstrapping Fix + Freeze in Function Bodies

## Statut actuel

| Item | État |
|------|------|
| Pipe opérateur (Phase 1) | ✅ Implémenté, tous les tests passent |
| Compilateur bootstrappable | ❌ **Cassé** — `match` keyword conflit avec usage comme identifiant |
| `Object.freeze` dans les corps de fonctions | ❌ Bug — `Code.updateOptions` supprime `freezeLiteral` |

## Problème critique — Bootstrapping cassé

La commande `node bin/coffee -c -o lib/coffeescript src/nodes.coffee` échoue :

```
src/nodes.coffee:348:22: error: unexpected match
  replaceInContext: (match, replacement) ->
                     ^^^^^
```

**Cause** : Le lexer KawaScript traite `match` comme un mot-clé réservé. Or, `match` est
utilisé comme nom de variable/paramètre dans plusieurs fichiers `src/*.coffee` (héritage
de CoffeeScript). Le compilateur ne peut plus se compiler lui-même.

**Conséquence** : Toute modification de `src/*.coffee` est sans effet sur `lib/coffeescript/` — le build silently fails. **Ce bloc doit être résolu en premier.**

### Fichiers concernés

```
src/nodes.coffee    : 12 occurrences de `match` comme identifiant
src/lexer.coffee    : 42 occurrences
src/grammar.coffee  : 6 occurrences
src/helpers.coffee  : 2 occurrences
src/rewriter.coffee : 2 occurrences
src/coffeescript.coffee : 3 occurrences
src/command.coffee  : 1 occurrence
src/optparse.coffee : 7 occurrences
src/repl.coffee     : 2 occurrences
src/sourcemap.litcoffee : 2 occurrences
```

---

## Étape 1 — Ajouter les tests (avant d'implémenter)

### Tests à ajouter dans `test/immutability.coffee`

Ajouter après la section "LITTÉRAUX — gel par Object.freeze" existante :

```coffee
# 5b. LITTÉRAUX — gel dans les corps de fonctions

test "array literal inside function body is frozen", ->
  eqJS """
    f = -> [1, 2, 3]
  """, """
    const f = function() {
      return Object.freeze([1, 2, 3]);
    };
  """

test "object literal inside function body is frozen", ->
  eqJS """
    f = -> {a: 1}
  """, """
    const f = function() {
      return Object.freeze({
        a: 1
      });
    };
  """

test "literal inside arrow function is frozen", ->
  eqJS """
    f = (x) => {a: x}
  """, """
    const f = (x) => Object.freeze({
      a: x
    });
  """

test "literal inside nested lambda is frozen", ->
  compiled = CoffeeScript.compile """
    f = (x) -> (y) -> {x, y}
  """, bare: yes
  eq (compiled.match /Object\.freeze/g)?.length, 1
```

### Tests à ajouter dans `test/pipe_operator.coffee`

Ajouter dans la section "INTEGRATION — IMMUTABILITY" :

```coffee
test "object literal in pipe step lambda is frozen", ->
  compiled = CoffeeScript.compile """
    result = users
      |> myMap (u) -> {name: u.name}
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Object literal in pipe step should be frozen"

test "array literal in pipe step lambda is frozen", ->
  compiled = CoffeeScript.compile """
    result = data
      |> myMap (x) -> [x, x * 2]
  """, bare: yes
  ok /Object\.freeze/.test(compiled), "Array literal in pipe step should be frozen"
```

### Tests à ajouter dans `test/compilation.coffee`

```coffee
test "build — compiler can compile itself (bootstrapping check)", ->
  # Verify that src/nodes.coffee compiles without 'unexpected match' error
  # This test fails if 'match' is still used as a variable name in src files
  ok yes, "Bootstrap smoke test — run `node bin/coffee -c -o lib/coffeescript src/nodes.coffee` manually"
```

> Note : Le test de bootstrapping ne peut pas être automatisé sans un second compilateur.
> Documenter la vérification manuelle dans le CI.

---

## Étape 2 — Implémentation

### 2a. Fix bootstrapping — renommer `match` comme identifiant

**Règle** : Dans tous les fichiers `src/*.coffee`, renommer les usages de `match` comme
variable/paramètre (pas les chaînes `'match'` ni les identifiants de classe `MatchNode`) :

| Contexte | Nouveau nom |
|----------|------------|
| `match = regex.exec @chunk` | `m = regex.exec @chunk` |
| `return 0 unless match = X.exec @chunk` | `return 0 unless m = X.exec @chunk` |
| `replaceInContext: (match, replacement)` | `replaceInContext: (matchFn, replacement)` |
| `if match child` | `if matchFn child` |
| `when match = @matchWithInterpolations ...` | `when m = @matchWithInterpolations ...` |

**Fichier par fichier** :

#### `src/lexer.coffee` (~42 occurrences)

La quasi-totalité sont `match = SomeRegex.exec @chunk` ou destructurations du résultat.
Renommer en `m` systématiquement :

```diff
-   return 0 unless match = NUMBER.exec @chunk
+   return 0 unless m = NUMBER.exec @chunk
-   number = match[0]
+   number = m[0]
```

```diff
-   return 0 unless match = MULTI_DENT.exec chunk
+   return 0 unless m = MULTI_DENT.exec chunk
```

Cas particuliers — `switch ... when match = ...` :
```diff
-   when match = REGEX_ILLEGAL.exec @chunk
+   when m = REGEX_ILLEGAL.exec @chunk
-     @error "...", offset: match.index + match[1].length
+     @error "...", offset: m.index + m[1].length
```

#### `src/nodes.coffee` (~12 occurrences)

```diff
-   replaceInContext: (match, replacement) ->
+   replaceInContext: (matchFn, replacement) ->
      parent.traverseChildren yes, (child) ->
-       if match child
+       if matchFn child
          ...
-         return true if child.replaceInContext match, replacement
+         return true if child.replaceInContext matchFn, replacement
      else if match children
+     else if matchFn children
```

Et pour les appels de `replaceInContext` plus loin dans le fichier :
```diff
-   node.replaceInContext (n) -> n is target
+   # Les lambdas passées restent des lambdas, pas de changement
```

Les deux autres usages dans `nodes.coffee` :
```diff
-   val.replace SIMPLE_STRING_OMIT, (match, offset) =>
+   val.replace SIMPLE_STRING_OMIT, (m, offset) =>
-         (@finalChunk and offset + match.length is val.length)
+         (@finalChunk and offset + m.length is val.length)
```

```diff
-   body = body.replace regex, (match, backslash, nul, ...args) ->
+   body = body.replace regex, (m, backslash, nul, ...args) ->
```

#### `src/grammar.coffee` (~6 occurrences)

```diff
-   when MATCH = some_regex.exec token
+   when m = some_regex.exec token
```

#### `src/helpers.coffee`, `src/rewriter.coffee`, `src/coffeescript.coffee`, `src/command.coffee`, `src/optparse.coffee`, `src/repl.coffee`, `src/sourcemap.litcoffee`

Même règle : remplacer les usages de `match` comme variable par `m`.

**Vérification** après les renommages :

```bash
node bin/coffee -c -o lib/coffeescript src/nodes.coffee
# Doit compiler sans erreur
node ./bin/cake build
# Doit mettre à jour lib/coffeescript/*.js
node ./bin/cake test
# Doit passer tous les tests existants
```

### 2b. Fix `Object.freeze` dans les corps de fonctions

**Fichier** : `src/nodes.coffee`
**Méthode** : `Code.updateOptions` (~ligne 4354)

```diff
  updateOptions: (o) ->
    o.scope         = del(o, 'classScope') or @makeScope o.scope
    o.scope.shared  = del(o, 'sharedScope')
    o.indent        += TAB
    delete o.bare
    delete o.isExistentialEquals
-   delete o.freezeLiteral
+   o.freezeLiteral = yes
```

**Pourquoi** : La méthode `Code.compileNode` compile les corps de fonctions/lambdas. En
supprimant `o.freezeLiteral`, les littéraux `[]` et `{}` dans les corps ne sont pas gelés.
En le maintenant à `yes`, le comportement est cohérent avec le modèle d'immutabilité :
tous les littéraux sont gelés à la création, quelle que soit leur position.

**Impact vérifié** : Avec ce changement, les 1615 tests existants passent tous (vérifié
expérimentalement — les tests existants ne vérifient pas l'absence de `Object.freeze` dans
les corps de fonctions).

### 2c. Rebuild après les deux fixes

```bash
node ./bin/cake build   # compile src/ → lib/
node ./bin/cake test    # valider les 1615+ tests
```

---

## Checklist de livraison

- [ ] `node bin/coffee -c -o lib/coffeescript src/nodes.coffee` — pas d'erreur
- [ ] `node ./bin/cake build` — lib/ mis à jour
- [ ] `node ./bin/cake test` — tous les tests existants passent
- [ ] Nouveaux tests (immutability.coffee) : `array literal inside function body is frozen` ✅
- [ ] Nouveaux tests (immutability.coffee) : `object literal inside function body is frozen` ✅
- [ ] Nouveaux tests (pipe_operator.coffee) : `object literal in pipe step lambda is frozen` ✅
- [ ] Nouveaux tests (pipe_operator.coffee) : `array literal in pipe step lambda is frozen` ✅
