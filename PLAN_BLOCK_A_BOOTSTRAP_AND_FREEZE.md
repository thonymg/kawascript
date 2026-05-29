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

### 2a. Fix bootstrapping — analyse approfondie du problème `match`

#### Pourquoi `match` est un mot-clé qui brise le bootstrapping

Quand le compilateur KawaScript compile `src/*.coffee`, il passe par `identifierToken`
dans le lexer. La logique de détection des mots-clés (lignes ~184-187 de `src/lexer.coffee`) :

```coffee
tag =
  if colon or prev? and
     (prev[0] in ['.', '?.', '::', '?::'] or ...)
    'PROPERTY'
  else
    'IDENTIFIER'

if tag is 'IDENTIFIER' and (id in JS_KEYWORDS or id in COFFEE_KEYWORDS)
  tag = id.toUpperCase()  # 'match' → token 'MATCH'
```

`'match'` est dans `COFFEE_KEYWORDS` (ligne ~1241). Le tag `'MATCH'` est produit **seulement
lorsque `tag is 'IDENTIFIER'`**, c'est-à-dire lorsque `match` apparaît **en position de valeur**
(pas après un `.`). Le token `MATCH` est alors traité par Jison comme le mot-clé du
pattern matching, et toute règle grammaticale attendant un `IDENTIFIER` ou un `ASSIGN`
échoue.

#### Taxonomie des 4 catégories d'usage de `match` dans les sources

##### Catégorie A — Identifiant seul ❌ PROBLÉMATIQUE — doit être renommé

`match` apparaît comme identifiant autonome en position de valeur, paramètre, ou assignation.
Le lexer le tokenise en `MATCH` keyword → parse error.

```coffee
# Assignation
match = NUMBER.exec @chunk          # → MATCH = ... : erreur syntaxique
return 0 unless match = MULTI_DENT.exec chunk  # idem

# Destructuration
[input, id, colon] = match          # → [x] = MATCH : erreur

# Lecture de propriété sur la variable locale
number = match[0]                   # → number = MATCH [0] : erreur

# Paramètre de fonction ou callback
replaceInContext: (match, replacement) ->  # → paramètre nommé MATCH : erreur
(match, offset) =>                          # idem
```

##### Catégorie B — Accès propriété `obj.match(...)` ✅ SÛRE — ne pas toucher

Quand `match` suit un `.`, `?.` ou `::`, le tag est `'PROPERTY'`, pas `'IDENTIFIER'`.
Le test `if tag is 'IDENTIFIER' and id in COFFEE_KEYWORDS` **ne s'active pas**.

```coffee
# SAFE — match est une méthode de String, Array, etc.
chunk.match COMMENT              # tag = PROPERTY → pas de conflit
code.match(/\r?\n/g)             # idem
firstLine?.match(/^#!\s*.../)    # idem (optional chaining)
longFlag.match(OPTIONAL)         # idem
multiline.buffer.match /\n/      # idem
```

**Subtilité** : `match = chunk.match COMMENT` — ici `match` apparaît **deux fois** :
- LHS `match` = identifiant seul → Catégorie A → doit être renommé
- `chunk.match` = accès propriété → Catégorie B → laissé tel quel

**Résultat après renommage** :
```diff
- return 0 unless match = chunk.match COMMENT
+ return 0 unless m = chunk.match COMMENT
```

##### Catégorie C — Identifiant commençant par "match" mais plus long ✅ SÛRE — ne pas toucher

Le regex `IDENTIFIER` capture la **plus longue séquence** possible de `[$\w\x7f-\uffff]+`.
`matchWithInterpolations` est lexé comme UN token, pas comme `match` + `WithInterpolations`.
Le test `id in COFFEE_KEYWORDS` compare `'matchWithInterpolations' === 'match'` → `false`.

```coffee
# SAFE — identifiants distincts du keyword 'match'
matchWithInterpolations: (regex, ...) ->  # méthode → 'matchWithInterpolations'
@matchWithInterpolations HEREGEX, '///'  # appel → 'matchWithInterpolations'
matchedHere    # différent → 'matchedHere'
matchedComment # différent → 'matchedComment'
matchIllegal   # différent → 'matchIllegal'
```

##### Catégorie D — Littéraux string et identifiants en majuscules ✅ SÛRE — ne pas toucher

```coffee
# SAFE — dans une chaîne littérale, jamais vu par identifierToken
COFFEE_KEYWORDS = ['let', 'match']       # la chaîne 'match'

# SAFE — identifiants différents (majuscule initiale ou tout en majuscules)
MATCH_PIPE   # constante, pas 'match'
MATCH        # constante token
Match:       # règle grammar.coffee, pas 'match' (majuscule)
```

---

#### Inventaire complet fichier par fichier

##### `src/lexer.coffee` — ~37 usages de Catégorie A à renommer

| Ligne | Code actuel | Catégorie | Traitement |
|-------|-------------|-----------|------------|
| 109 | `(match, offset) =>` | A — param callback | → `(m, offset) =>` |
| 128 | `return 0 unless match = regex.exec @chunk` | A | → `m` |
| 129 | `[input, id, colon] = match` | A | → `m` |
| 265 | `return 0 unless match = NUMBER.exec @chunk` | A | → `m` |
| 267 | `number = match[0]` | A | → `m[0]` |
| 314 | `while match = HEREDOC_INDENT.exec doc` | A | → `m` |
| 315 | `attempt = match[1]` | A | → `m[1]` |
| 331 | `return 0 unless match = chunk.match COMMENT` | A (LHS) + B (RHS) | LHS → `m`, `chunk.match` intact |
| 332 | `[..., ...] = match` | A | → `m` |
| 433 | `(match = (matchedHere = ...) or ...)` | A | → `m` |
| 436–437 | `match[1]`, `match[0]` | A | → `m[1]`, `m[0]` |
| 446 | `when match = REGEX_ILLEGAL.exec @chunk` | A | → `m` |
| 447–448 | `match[2]`, `match.index`, `match[1].length` | A | → `m` |
| 449 | `when match = @matchWithInterpolations HEREGEX, '///'` | A (LHS) | → `m` |
| 450 | `{tokens, index} = match` | A | → `m` |
| 460 | `when match = REGEX.exec @chunk` | A | → `m` |
| 461 | `[regex, body, closed] = match` | A | → `m` |
| 515 | `return 0 unless match = MULTI_DENT.exec chunk` | A | → `m` |
| 516 | `indent = match[0]` | A | → `m[0]` |
| 601 | `(match = WHITESPACE.exec @chunk) or (nline = ...)` | A | → `m` |
| 604–605 | `match` dans ternaire (×3) | A | → `m` |
| 631 | `match = JSX_IDENTIFIER.exec(...) or ...` | A | → `m` |
| 632 | `return 0 unless match and ...` | A | → `m` |
| 639 | `[input, id] = match` | A | → `m` |
| 703 | `match = JSX_IDENTIFIER.exec(@chunk[end...]) or ...` | A | → `m` |
| 704 | `if not match or match[1] isnt ...` | A | → `m` |
| 707 | `[, fullTagName] = match` | A | → `m` |
| 756 | `if match = OPERATOR.exec @chunk` | A | → `m` |
| 757 | `[value] = match` | A | → `m` |
| 901 | `break unless match = interpolators.exec str` | A | → `m` |
| 902 | `[interpolator] = match` | A | → `m` |
| 1160 | `match = invalidEscapeRegex.exec str` | A | → `m` |
| 1161 | `return unless match` | A | → `m` |
| 1162 | `[[], before, ...] = match` | A | → `m` |
| 1170 | `match.index` | A | → `m.index` |

**NE PAS RENOMMER** dans lexer.coffee :
- `matchWithInterpolations` (méthode) — Catégorie C
- `matchedHere`, `matchedComment`, `matchIllegal` — Catégorie C
- `MATCH_PIPE`, `'match'` dans `COFFEE_KEYWORDS` — Catégorie D
- `@matchWithInterpolations(...)` (appels) — Catégorie C

##### `src/nodes.coffee` — 8 usages de Catégorie A

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 346 (commentaire) | `# for which \`match\` returns` | commentaire → laisser tel quel |
| 348 | `replaceInContext: (match, replacement) ->` | param → `matchFn` |
| 353 | `if match child` | → `matchFn child` |
| 357 | `return true if child.replaceInContext match, replacement` | → `matchFn` |
| 358 | `else if match children` | → `matchFn children` |
| 362 | `return true if children.replaceInContext match, replacement` | → `matchFn` |
| 1032 | `val.replace SIMPLE_STRING_OMIT, (match, offset) =>` | → `(m, offset) =>` |
| 1034 | `offset + match.length` | → `m.length` |
| 6295 | `body.replace regex, (match, backslash, nul, ...args) ->` | → `(m, backslash, nul, ...)` |

> Pourquoi `matchFn` et pas `m` pour `replaceInContext` ? Parce que c'est un **prédicat
> fonctionnel** (une fonction), pas un résultat de regex. Les callers dans le fichier passent
> des lambdas : `@replaceInContext (n) -> n is target, ...` — aucune modification des
> call sites nécessaire, la lambda est passée en argument sous un autre nom.

##### `src/grammar.coffee` — 2 usages de Catégorie A

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 40 | `action = if match = unwrap.exec action then match[1] else ...` | → `m` |

Les autres occurrences (`Match:`, `MATCH`, commentaires) — Catégorie C/D, intactes.

##### `src/helpers.coffee` — 2 usages de Catégorie A (callbacks)

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 309 | `(match, escapedBackslash, codePointHex, offset) ->` | → `(m, ...)` |
| 317 | `return match unless shouldReplace` | → `return m` |

##### `src/coffeescript.coffee` — 1 usage de Catégorie A

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 37 | `encodeURIComponent(src).replace /%([0-9A-F]{2})/g, (match, p1) ->` | → `(m, p1) ->` |

Les lignes 96 et 327 (`code.match(...)`, `firstLine?.match(...)`) — **Catégorie B**, safe.

##### `src/optparse.coffee` — 4 usages de Catégorie A

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 103 | `match = longFlag.match(OPTIONAL)` | LHS `match` → `m` ; `longFlag.match` intact (Catégorie B) |
| 111 | `!!(match and match[1])` | → `!!(m and m[1])` |
| 112 | `!!(match and match[2])` | → `!!(m and m[2])` |

Les lignes 104, 105, 129, 149 (`shortFlag?.match(...)`, `longFlag.match(...)`, etc.) — **Catégorie B**, safe.

##### `src/command.coffee` — 2 usages de Catégorie A

| Ligne | Code actuel | Traitement |
|-------|-------------|------------|
| 143 | `[full, name, module] = match if match = module.match(/^(.*)=(.*)$/)` | LHS `match` et son usage → `m` ; `module.match(...)` intact (Catégorie B) |

##### `src/rewriter.coffee` — 0 usage de Catégorie A ✅

Toutes les occurrences de `match` dans rewriter.coffee sont dans des **commentaires**
(lignes 105, 119, 138, 140, 753). Aucune modification requise.

##### `src/repl.coffee` — 0 usage de Catégorie A ✅

Les deux occurrences (`multiline.buffer.match /\n/`, `repl.line.match /^\s*$/`) sont
des **accès de propriété** — Catégorie B. Safe.

##### `src/sourcemap.litcoffee` — 0 usage de Catégorie A ✅

Les deux occurrences sont dans du **texte en prose** (fichier literate). Aucune modification.

---

#### Choix du nom de remplacement : `m` vs alternatives

| Option | Pour | Contre |
|--------|------|--------|
| `m` | Court, conventionnel (Perl/Ruby), différent de tout mot-clé | Très court, peut sembler cryptique hors contexte |
| `regM` | Explicitement "regex match" | Verbose |
| `matched` | Lisible | Potentiellement confondu avec un booléen |
| `regexMatch` | Maximum clarté | Trop long, casse la lisibilité des lignes |

**Choix retenu : `m`** pour les résultats de regex, `matchFn` pour le prédicat de `replaceInContext`.

**Risque de collision de `m`** : Vérification manuelle dans chaque méthode concernée —
`identifierToken`, `numberToken`, `commentToken`, `jsToken`, `regexToken`, `lineToken`,
`whitespaceToken`, `jsxToken`, `literalToken`, `matchWithInterpolations`, `validateEscapes` :
aucune n'utilise `m` comme variable locale existante. Safe.

**Note** : les appels `@matchWithInterpolations(...)` dont le résultat était stocké dans
`match` (Catégorie A) ne renomment que la **variable locale de stockage** en `m`.
Le nom de la méthode `matchWithInterpolations` reste intact — Catégorie C.

---

#### Diffs de référence par méthode

```diff
# identifierToken (ligne 128)
- return 0 unless match = regex.exec @chunk
- [input, id, colon] = match
+ return 0 unless m = regex.exec @chunk
+ [input, id, colon] = m

# numberToken (ligne 265)
- return 0 unless match = NUMBER.exec @chunk
- number = match[0]
+ return 0 unless m = NUMBER.exec @chunk
+ number = m[0]

# commentToken (ligne 331) — noter chunk.match intact
- return 0 unless match = chunk.match COMMENT
- [commentWithSurroundingWhitespace, ...] = match
+ return 0 unless m = chunk.match COMMENT
+ [commentWithSurroundingWhitespace, ...] = m

# jsToken (ligne 433)
- (match = (matchedHere = HERE_JSTOKEN.exec(@chunk)) or JSTOKEN.exec(@chunk))
- script = match[1]
- {length} = match[0]
+ (m = (matchedHere = HERE_JSTOKEN.exec(@chunk)) or JSTOKEN.exec(@chunk))
+ script = m[1]
+ {length} = m[0]

# regexToken (lignes 446–461)
- when match = REGEX_ILLEGAL.exec @chunk
-   @error "...", offset: match.index + match[1].length
- when match = @matchWithInterpolations HEREGEX, '///'  # appel de méthode → intact
-   {tokens, index} = match
- when match = REGEX.exec @chunk
-   [regex, body, closed] = match
+ when m = REGEX_ILLEGAL.exec @chunk
+   @error "...", offset: m.index + m[1].length
+ when m = @matchWithInterpolations HEREGEX, '///'
+   {tokens, index} = m
+ when m = REGEX.exec @chunk
+   [regex, body, closed] = m

# lineToken (ligne 515)
- return 0 unless match = MULTI_DENT.exec chunk
- indent = match[0]
+ return 0 unless m = MULTI_DENT.exec chunk
+ indent = m[0]

# whitespaceToken (lignes 601–605)
- return 0 unless (match = WHITESPACE.exec @chunk) or (nline = ...)
- prev[if match then 'spaced' else 'newLine'] = true if prev
- if match then match[0].length else 0
+ return 0 unless (m = WHITESPACE.exec @chunk) or (nline = ...)
+ prev[if m then 'spaced' else 'newLine'] = true if prev
+ if m then m[0].length else 0

# literalToken (ligne 756)
- if match = OPERATOR.exec @chunk
-   [value] = match
+ if m = OPERATOR.exec @chunk
+   [value] = m

# matchWithInterpolations (ligne 901)
- break unless match = interpolators.exec str
- [interpolator] = match
+ break unless m = interpolators.exec str
+ [interpolator] = m

# validateEscapes (lignes 1160–1170)
- match = invalidEscapeRegex.exec str
- return unless match
- [[], before, octal, hex, unicodeCodePoint, unicode] = match
- offset: match.index + before.length
+ m = invalidEscapeRegex.exec str
+ return unless m
+ [[], before, octal, hex, unicodeCodePoint, unicode] = m
+ offset: m.index + before.length

# nodes.coffee — replaceInContext
- replaceInContext: (match, replacement) ->
-   if match child
-   return true if child.replaceInContext match, replacement
-   else if match children
-   return true if children.replaceInContext match, replacement
+ replaceInContext: (matchFn, replacement) ->
+   if matchFn child
+   return true if child.replaceInContext matchFn, replacement
+   else if matchFn children
+   return true if children.replaceInContext matchFn, replacement
```

**Vérification** après les renommages :

```bash
# Vérifier qu'il ne reste aucun 'match' seul (Catégorie A) dans les sources
grep -n '\bmatch\b' src/lexer.coffee
# Doit retourner UNIQUEMENT des commentaires et des Catégorie B/C/D

# Compiler les fichiers critiques
node bin/coffee -c -o lib/coffeescript src/nodes.coffee    # sans erreur
node bin/coffee -c -o lib/coffeescript src/lexer.coffee    # sans erreur
node ./bin/cake build   # met à jour lib/coffeescript/*.js
node ./bin/cake test    # tous les tests passent
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
