# ─────────────────────────────────────────────────────────────────────────────
# STDLIB — kawa/string
# ─────────────────────────────────────────────────────────────────────────────

{words, lines, truncate, underscore, camelize, dasherize, capitalize} = require '../src/stdlib/string'

test "words — splits on whitespace", ->
  arrayEq words("hello world  foo"), ['hello','world','foo']

test "lines — splits on newline", ->
  arrayEq lines("a\nb\nc"), ['a','b','c']

test "truncate — short string unchanged", ->
  eq truncate("hello", 10), "hello"

test "truncate — long string truncated with ellipsis", ->
  eq truncate("hello world", 8), "hello w…"

test "underscore — camelCase to snake_case", ->
  eq underscore("helloWorld"),   "hello_world"
  eq underscore("HTMLParser"),   "html_parser"

test "camelize — snake_case to camelCase", ->
  eq camelize("hello_world"),   "helloWorld"
  eq camelize("foo-bar-baz"),   "fooBarBaz"

test "dasherize — to kebab-case", ->
  eq dasherize("helloWorld"),   "hello-world"

test "capitalize — first letter uppercase", ->
  eq capitalize("hello"), "Hello"
