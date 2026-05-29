# ═══════════════════════════════════════════════════════════════════════════════
# immutability_showcase.coffee
#
# Fichier de démonstration du modèle d'immutabilité totale.
# Compilez ce fichier pour observer la sortie du compilateur :
#
#   node -e "
#     const cs = require('./lib/coffeescript');
#     const fs = require('fs');
#     const src = fs.readFileSync('./examples/immutability_showcase.coffee', 'utf8');
#     console.log(cs.compile(src, {bare: true}));
#   "
#
# ═══════════════════════════════════════════════════════════════════════════════



# ───────────────────────────────────────────────────────────────────────────────
# 1. VARIABLES
#    x = v   → const x = v
#    let x = v → let x = v
# ───────────────────────────────────────────────────────────────────────────────

author  = "Wittgenstein"
square  = (x) -> x * x
cube    = (x) -> square(x) * x

let counter = 0
counter = counter + 1
counter = counter + 1

# Attendu :
#   const author  = "Wittgenstein";
#   const square  = function(x) { return x * x; };
#   const cube    = function(x) { return square(x) * x; };
#   let counter = 0;
#   counter = counter + 1;
#   counter = counter + 1;



# ───────────────────────────────────────────────────────────────────────────────
# 2. BLOCK SCOPE
#    let dans un if → reste dans le if
#    let au niveau fonction → accessible dans tout le corps
# ───────────────────────────────────────────────────────────────────────────────

classify = (n) ->
  if n > 0
    let label = "positif"      # block-scoped au if
    console.log label
  else if n < 0
    let label = "négatif"      # block-scoped au else if (variable indépendante)
    console.log label
  else
    console.log "zéro"

accumulate = (items) ->
  let total = 0                # déclaré au niveau fonction → accessible partout
  for item in items
    total = total + item
  total

# Attendu :
#   const classify = function(n) {
#     if (n > 0) {
#       let label = "positif";
#       console.log(label);
#     } else if (n < 0) {
#       let label = "négatif";
#       console.log(label);
#     } else {
#       console.log("zéro");
#     }
#   };
#   const accumulate = function(items) {
#     let total = 0;
#     for (let item of items) {
#       total = total + item;
#     }
#     return total;
#   };



# ───────────────────────────────────────────────────────────────────────────────
# 3. LITTÉRAUX GELÉS
#    [] → Object.freeze([])
#    {} → Object.freeze({})
#    structures imbriquées → __freeze__(...)
# ───────────────────────────────────────────────────────────────────────────────

colors   = ["red", "green", "blue"]
origin   = {x: 0, y: 0}
matrix   = [[1, 0], [0, 1]]             # imbriqué → deep freeze
settings = {db: {host: "localhost"}}    # imbriqué → deep freeze

# Attendu :
#   const __freeze__ = (v) => { ... };   ← injecté une fois automatiquement
#   const colors   = Object.freeze(["red", "green", "blue"]);
#   const origin   = Object.freeze({x: 0, y: 0});
#   const matrix   = __freeze__([[1, 0], [0, 1]]);
#   const settings = __freeze__({db: {host: "localhost"}});



# ───────────────────────────────────────────────────────────────────────────────
# 4. MUTATIONS D'INDEX ET DE PROPRIÉTÉ → copy-on-write
# ───────────────────────────────────────────────────────────────────────────────

let items = [10, 20, 30, 40, 50]
items[2] = 99                     # remplace l'index 2

let config = {host: "localhost", port: 3000, debug: false}
config.debug = true               # spread copy
config.port  = 8080               # spread copy

let registry = {}
key = "userId"
registry[key] = "abc-123"         # clé dynamique → computed property

# Attendu :
#   let items = Object.freeze([10, 20, 30, 40, 50]);
#   items = Object.freeze([...items.slice(0, 2), 99, ...items.slice(3)]);
#
#   let config = Object.freeze({host: "localhost", port: 3000, debug: false});
#   config = Object.freeze({...config, debug: true});
#   config = Object.freeze({...config, port: 8080});
#
#   let registry = Object.freeze({});
#   const key = "userId";
#   registry = Object.freeze({...registry, [key]: "abc-123"});



# ───────────────────────────────────────────────────────────────────────────────
# 5. MÉTHODES MUTANTES → réécriture automatique
# ───────────────────────────────────────────────────────────────────────────────

let queue = []
queue.push "first"
queue.push "second", "third"
queue.shift()

let stack = [1, 2, 3]
stack.pop()
stack.unshift 0

let nums = [3, 1, 4, 1, 5, 9]
nums.sort()
nums.sort (a, b) -> b - a
nums.reverse()

let data = [1, 2, 3, 4, 5]
data.splice 1, 2
data.splice 0, 0, 99

let grid = [0, 0, 0, 0]
grid.fill 1

# Attendu :
#   const __toFilled__ = (arr, value, ...) => { ... };  ← injecté automatiquement
#
#   let queue = Object.freeze([]);
#   queue = Object.freeze([...queue, "first"]);
#   queue = Object.freeze([...queue, "second", "third"]);
#   queue = Object.freeze(queue.slice(1));
#
#   let stack = Object.freeze([1, 2, 3]);
#   stack = Object.freeze(stack.slice(0, -1));
#   stack = Object.freeze([0, ...stack]);
#
#   let nums = Object.freeze([3, 1, 4, 1, 5, 9]);
#   nums = Object.freeze(nums.toSorted());
#   nums = Object.freeze(nums.toSorted(function(a, b) { return b - a; }));
#   nums = Object.freeze(nums.toReversed());
#
#   let data = Object.freeze([1, 2, 3, 4, 5]);
#   data = Object.freeze([...data.slice(0, 1), ...data.slice(1 + 2)]);
#   data = Object.freeze([...data.slice(0, 0), 99, ...data.slice(0 + 0)]);
#
#   let grid = Object.freeze([0, 0, 0, 0]);
#   grid = __toFilled__(grid, 1);



# ───────────────────────────────────────────────────────────────────────────────
# 6. MÉTHODES NON-MUTANTES → inchangées
# ───────────────────────────────────────────────────────────────────────────────

source  = [1, 2, 3, 4, 5]
doubled = source.map (x) -> x * 2
evens   = source.filter (x) -> x % 2 is 0
head    = source.slice 0, 3
total   = source.reduce ((acc, x) -> acc + x), 0
merged  = source.concat [6, 7, 8]
found   = source.find (x) -> x > 3
exists  = source.some (x) -> x > 4
all     = source.every (x) -> x > 0
idx     = source.indexOf 3

# Attendu : ces méthodes sont émises telles quelles, sans réécriture.
#   const doubled = source.map(function(x) { return x * 2; });
#   const evens   = source.filter(function(x) { return x % 2 === 0; });
#   const head    = source.slice(0, 3);
#   const total   = source.reduce(function(acc, x) { return acc + x; }, 0);
#   const merged  = source.concat([6, 7, 8]);
#   ...



# ───────────────────────────────────────────────────────────────────────────────
# 7. CAS RÉALISTE — gestion d'une todo-list immutable
# ───────────────────────────────────────────────────────────────────────────────

let todos = []

addTodo = (list, text) ->
  [...list, {id: Date.now(), text: text, done: false}]

toggleTodo = (list, id) ->
  list.map (todo) ->
    if todo.id is id
      {...todo, done: not todo.done}
    else
      todo

removeTodo = (list, id) ->
  list.filter (todo) -> todo.id isnt id

todos = addTodo todos, "Apprendre CoffeeScript"
todos = addTodo todos, "Implémenter l'immutabilité"
todos = toggleTodo todos, todos[0].id
todos = removeTodo todos, todos[1].id

# Attendu : aucune mutation, chaque opération retourne un nouveau tableau.
# addTodo et toggleTodo utilisent des méthodes non-mutantes (spread, map, filter)
# → aucune réécriture nécessaire, code déjà immutable.
