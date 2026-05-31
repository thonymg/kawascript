# Pattern Matching — exemples pratiques KawaScript
# ==================================================
# Lancer : coffee examples/pattern_matching.coffee

# ─────────────────────────────────────────────────────────────────────────────
# 1. Patterns littéraux — brancher sur une valeur exacte
# ─────────────────────────────────────────────────────────────────────────────

greet = (lang) ->
  match lang
    | "fr" -> "Bonjour"
    | "en" -> "Hello"
    | "es" -> "Hola"
    | "ja" -> "こんにちは"
    | _    -> "?"

console.log greet("fr")   # Bonjour
console.log greet("en")   # Hello
console.log greet("de")   # ?

# ─────────────────────────────────────────────────────────────────────────────
# 2. Liaison de variable — capturer la valeur matchée
# ─────────────────────────────────────────────────────────────────────────────

describe = (n) ->
  match n
    | 0 -> "zéro"
    | 1 -> "un"
    | n -> "valeur : #{n}"   # n est lié à la valeur

console.log describe(0)    # zéro
console.log describe(1)    # un
console.log describe(42)   # valeur : 42

# ─────────────────────────────────────────────────────────────────────────────
# 3. Guards — conditions supplémentaires sur la branche
# ─────────────────────────────────────────────────────────────────────────────

sign = (n) ->
  match n
    | 0          -> "nul"
    | n if n > 0 -> "positif (#{n})"
    | n          -> "négatif (#{n})"

console.log sign(0)    # nul
console.log sign(7)    # positif (7)
console.log sign(-3)   # négatif (-3)

classify = (score) ->
  match score
    | s if s >= 90 -> "A"
    | s if s >= 80 -> "B"
    | s if s >= 70 -> "C"
    | s if s >= 60 -> "D"
    | _            -> "F"

console.log classify(95)   # A
console.log classify(82)   # B
console.log classify(55)   # F

# ─────────────────────────────────────────────────────────────────────────────
# 4. Or-patterns — plusieurs valeurs pour une même branche
# ─────────────────────────────────────────────────────────────────────────────

isWeekend = (day) ->
  match day
    | "Saturday", "Sunday" -> true
    | _                    -> false

console.log isWeekend("Saturday")   # true
console.log isWeekend("Monday")     # false

httpStatus = (code) ->
  match code
    | 200, 201, 204       -> "succès"
    | 400, 422            -> "erreur client"
    | 401, 403            -> "non autorisé"
    | 404                 -> "introuvable"
    | 500, 502, 503       -> "erreur serveur"
    | _                   -> "code inconnu"

console.log httpStatus(200)   # succès
console.log httpStatus(404)   # introuvable
console.log httpStatus(503)   # erreur serveur

# ─────────────────────────────────────────────────────────────────────────────
# 5. match comme expression — assigner le résultat
# ─────────────────────────────────────────────────────────────────────────────

role = "admin"
label =
  match role
    | "admin"  -> "Administrateur"
    | "editor" -> "Éditeur"
    | "viewer" -> "Lecteur"
    | _        -> "Invité"

console.log label   # Administrateur

# ─────────────────────────────────────────────────────────────────────────────
# 6. Null / undefined — valeurs optionnelles
# ─────────────────────────────────────────────────────────────────────────────

display = (value) ->
  match value
    | null      -> "(null)"
    | undefined -> "(undefined)"
    | ""        -> "(vide)"
    | s         -> s

console.log display(null)        # (null)
console.log display(undefined)   # (undefined)
console.log display("")          # (vide)
console.log display("hello")     # hello

# ─────────────────────────────────────────────────────────────────────────────
# 7. Booléens — remplacer if/else verbeux
# ─────────────────────────────────────────────────────────────────────────────

toggle = (enabled) ->
  match enabled
    | true  -> "activé"
    | false -> "désactivé"

console.log toggle(true)    # activé
console.log toggle(false)   # désactivé

# ─────────────────────────────────────────────────────────────────────────────
# 8. Cas pratique — machine à états
# ─────────────────────────────────────────────────────────────────────────────

transition = (state, event) ->
  match state
    | "idle"    ->
      match event
        | "start"  -> "running"
        | _        -> state
    | "running" ->
      match event
        | "pause"  -> "paused"
        | "stop"   -> "idle"
        | _        -> state
    | "paused"  ->
      match event
        | "resume" -> "running"
        | "stop"   -> "idle"
        | _        -> state
    | _         -> "idle"

s = "idle"
s = transition s, "start"    # running
s = transition s, "pause"    # paused
s = transition s, "resume"   # running
s = transition s, "stop"     # idle
console.log s   # idle

# ─────────────────────────────────────────────────────────────────────────────
# 9. Cas pratique — parser de commande CLI
# ─────────────────────────────────────────────────────────────────────────────

run = (cmd) ->
  match cmd
    | "help", "h"    -> console.log "Usage : app <commande>"
    | "version", "v" -> console.log "v2.0.0"
    | "quit", "exit" -> console.log "Au revoir"
    | c              -> console.log "Commande inconnue : #{c}"

run "help"      # Usage : app <commande>
run "v"         # v2.0.0
run "unknown"   # Commande inconnue : unknown
