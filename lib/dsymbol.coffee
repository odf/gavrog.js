if typeof(require) != 'undefined'
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  pazy = require('indexed')

Set = pazy.IntSet
Map = pazy.IntMap


class DSymbol
  # -- the constructor sets the dimension and an initial set of elements

  constructor: (dimension, elms) ->
    @_dim  = dimension
    @_elms = (new Set()).with(elms...)
    @_idcs = (new Set()).with([0..dimension]...)
    @_ops  = (new Map() for i in [0..dimension])
    @_degs = (new Map() for i in [0...dimension])

  # -- the following six methods implement the common interface for
  #    all Delaney symbol classes.

  dimension: -> @_dim
  indices:   -> @_idcs
  size:      -> @_elms.size
  elements:  -> @_elms

  s: (i)     -> (D) => @_ops[i].get(D)

  m: (i, j)  ->
    switch j
      when i + 1 then (D) => @_degs[i].get(D)
      when i - 1 then (D) => @_degs[j].get(D)
      when i     then (D) -> 1
      else            (D) -> 2

  # -- some private helper methods

  create = (dimension, elements, indices, operations, degrees) ->
    ds = new DSymbol(dimension)
    ds._elms = elements
    ds._idcs = indices
    ds._ops  = operations
    ds._degs = degrees
    ds

  arrayWith = (a, i, x) -> (if j == i then x else a[j]) for j in [0...a.length]

  # -- the following methods are used to build DSymbols incrementally

  with_elements: (args...) ->
    create(@_dim, @_elms.with(args...), @_idcs, @_ops, @_degs)

  without_elements: (args...) ->
    create(@_dim, @_elms.without(args...), @_idcs, @_ops, @_degs)

  with_gluings: (i) ->
    (args...) =>
      [elms, op] = [@_elms, @_ops[i]]
      for spec in args
        [D, E] = [spec[0], if spec.length < 2 then spec[0] else spec[1]]
        [elms, op] = [elms.with(D), op.with([D, E])] if D?
        [elms, op] = [elms.with(E), op.with([E, D])] if E?
      create(@_dim, elms, @_idcs, arrayWith(@_ops, i, op), @_degs)

  without_gluings: (i) ->
    (args...) =>
      [elms, op] = [@_elms, @_ops[i]]
      for D in args
        op = op.without(D, op.get(D))
      create(@_dim, elms, @_idcs, arrayWith(@_ops, i, op), @_degs)


## -- Test code --

puts = require('sys').puts

ds = new DSymbol(2, [1..3]).
       with_gluings(0)([1], [2]).
       with_gluings(1)([1, 2]).
       with_gluings(2)([1], [2])

puts "Size      = #{ds.size()}"
puts "Dimension = #{ds.dimension()}"
puts "Elements  = #{ds.elements().toArray()}"
puts "Indices   = #{ds.indices().toArray()}"

ds.indices().each (i) ->
  ds.elements().each (D) ->
    puts "s(#{i})(#{D}) = #{ds.s(i)(D)}"

puts ""
puts "After undefining s(1)(1) and removing element 3:"
ds = ds.without_gluings(1)(1).without_elements(3)

ds.indices().each (i) ->
  ds.elements().each (D) ->
    puts "s(#{i})(#{D}) = #{ds.s(i)(D)}"

###
puts "m(0,1)(2) = #{ds.m(0,1)(2)}"
puts "m(2,1)(1) = #{ds.m(2,1)(1)}"
puts "m(0,2)(2) = #{ds.m(0,2)(2)}"

### -- End of test code --
