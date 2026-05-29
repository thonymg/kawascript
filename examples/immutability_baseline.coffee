# ═══════════════════════════════════════════════════════════════════════════════
# immutability_baseline.coffee
#
# Version BASELINE — syntaxe CoffeeScript actuelle, sans les nouvelles
# constructions. Montre ce que le compilateur produit AUJOURD'HUI.
# Comparez avec la sortie CIBLE documentée dans immutability_showcase.coffee.
#
# Usage :
#   node examples/run_showcase.js baseline
# ═══════════════════════════════════════════════════════════════════════════════

# ── 1. VARIABLES ───────────────────────────────────────────────────────────────
# Aujourd'hui : var au sommet du scope
# Cible       : const inline

author = "Wittgenstein"
square = (x) -> x * x
cube   = (x) -> square(x) * x

counter = 0
counter = counter + 1
counter = counter + 1


# ── 2. LITTÉRAUX ───────────────────────────────────────────────────────────────
# Aujourd'hui : tableaux et objets mutables
# Cible       : Object.freeze(...) ou __freeze__(...)

colors   = ["red", "green", "blue"]
origin   = {x: 0, y: 0}
matrix   = [[1, 0], [0, 1]]
settings = {db: {host: "localhost"}}


# ── 3. MUTATIONS D'INDEX ET DE PROPRIÉTÉ ───────────────────────────────────────
# Aujourd'hui : mutation directe
# Cible       : copy-on-write spread

items    = [10, 20, 30, 40, 50]
items[2] = 99

config        = {host: "localhost", port: 3000, debug: false}
config.debug  = true
config.port   = 8080

registry      = {}
key           = "userId"
registry[key] = "abc-123"


# ── 4. MÉTHODES MUTANTES ───────────────────────────────────────────────────────
# Aujourd'hui : appels JS directs, mutation en place
# Cible       : réécriture automatique copy-on-write

queue = []
queue.push "first"
queue.push "second", "third"
queue.shift()

stack = [1, 2, 3]
stack.pop()
stack.unshift 0

nums = [3, 1, 4, 1, 5, 9]
nums.sort()
nums.reverse()

data = [1, 2, 3, 4, 5]
data.splice 1, 2
data.splice 0, 0, 99

grid = [0, 0, 0, 0]
grid.fill 1


# ── 5. MÉTHODES NON-MUTANTES ───────────────────────────────────────────────────
# Aujourd'hui et demain : inchangées

source  = [1, 2, 3, 4, 5]
doubled = source.map (x) -> x * 2
evens   = source.filter (x) -> x % 2 is 0
head    = source.slice 0, 3
total   = source.reduce ((acc, x) -> acc + x), 0
merged  = source.concat [6, 7, 8]


# ── 6. delete ──────────────────────────────────────────────────────────────────
# Aujourd'hui : autorisé
# Cible       : CompileError

obj = {a: 1, b: 2, c: 3}
delete obj.b


# ── 7. BOUCLES ─────────────────────────────────────────────────────────────────
# Aujourd'hui : var _i, _len
# Cible       : let

for item in ["a", "b", "c"]
  console.log item

for i in [1..5]
  console.log i
