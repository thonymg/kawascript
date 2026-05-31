{compact, zip, sum, partition, chunk, windows, uniq, uniqBy, minBy, maxBy, tally, groupBy} = require './array'
{words, lines, truncate, underscore, camelize, dasherize, capitalize} = require './string'

def = (proto, name, fn) ->
  Object.defineProperty proto, name,
    value: fn
    enumerable: no
    writable: yes
    configurable: yes

# Array prototype augmentations
def Array.prototype, 'compact', ->
  compact @

def Array.prototype, 'sum', (fn) ->
  sum @, fn

def Array.prototype, 'zip', (others...) ->
  zip @, others...

def Array.prototype, 'partition', (fn) ->
  partition @, fn

def Array.prototype, 'chunk', (n) ->
  chunk @, n

def Array.prototype, 'windows', (n) ->
  windows @, n

def Array.prototype, 'uniq', ->
  uniq @

def Array.prototype, 'uniqBy', (fn) ->
  uniqBy @, fn

def Array.prototype, 'minBy', (fn) ->
  minBy @, fn

def Array.prototype, 'maxBy', (fn) ->
  maxBy @, fn

def Array.prototype, 'tally', ->
  tally @

def Array.prototype, 'groupBy', (fn) ->
  groupBy @, fn

# String prototype augmentations
def String.prototype, 'words', ->
  words @toString()

def String.prototype, 'lines', ->
  lines @toString()

def String.prototype, 'truncate', (len, ellipsis) ->
  if ellipsis?
    truncate @toString(), len, ellipsis
  else
    truncate @toString(), len

def String.prototype, 'underscore', ->
  underscore @toString()

def String.prototype, 'camelize', ->
  camelize @toString()

def String.prototype, 'dasherize', ->
  dasherize @toString()

def String.prototype, 'capitalize', ->
  capitalize @toString()
