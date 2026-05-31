words = (s) -> s.trim().split /\s+/

lines = (s) -> s.split /\r?\n/

truncate = (s, len, ellipsis = '…') ->
  if s.length <= len then s else s.slice(0, len - ellipsis.length) + ellipsis

underscore = (s) ->
  s.replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
   .replace(/([a-z\d])([A-Z])/g, '$1_$2')
   .toLowerCase()

camelize = (s) -> s.replace /[-_](.)/g, (_, c) -> c.toUpperCase()

dasherize = (s) -> underscore(s).replace /_/g, '-'

capitalize = (s) -> s.charAt(0).toUpperCase() + s.slice 1

module.exports = {words, lines, truncate, underscore, camelize, dasherize, capitalize}
