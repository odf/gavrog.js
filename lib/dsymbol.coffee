if typeof(require) != 'undefined'
  # for now we assume that pazy.js lives next to gavrog.js
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  pazy = require('indexed')

Set = pazy.IntSet
Map = pazy.IntMap


class DSymbol
  # -- the constructor receives the dimension and an initial set of elements

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
    if j?
      switch j
        when i + 1 then (D) => @_degs[i].get(D)
        when i - 1 then (D) => @_degs[j].get(D)
        when i     then (D) -> 1
        else            (D) -> 2
    else
      (D) -> 1

  # -- some private helper methods

  create = (dimension, elements, indices, operations, degrees) ->
    ds = new DSymbol(dimension)
    ds._elms = elements
    ds._idcs = indices
    ds._ops  = operations
    ds._degs = degrees
    ds

  arrayWith = (a, i, x) -> (if j == i then x else a[j]) for j in [0...a.length]

  # -- the following methods will eventually go into a mix-in

  orbit: (i, j, D) ->
    symbol = this
    fixed = (x, fallback) -> if x? then x else fallback
    {
      each: (func) ->
        E = D
        loop
          for k in [i, j]
            func(E)
            E = fixed(symbol.s(k)(E), E)
          break if E == D
    }

  # -- the following methods are used to build DSymbols incrementally

  with_elements: (args...) ->
    create(@_dim, @_elms.with(args...), @_idcs, @_ops, @_degs)

  without_elements: (args...) ->
    ops  = for i in @indices().toArray()
      @_ops[i].without(args...).without((@s(i)(D) for D in args)...)
    degs = (s.without(args...) for s in @_degs)
    elms = @_elms.without(args...)
    create(@_dim, elms, @_idcs, ops, degs)

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
      op = @_ops[i]
      for D in args
        op = op.without(D, op.get(D))
      create(@_dim, @_elms, @_idcs, arrayWith(@_ops, i, op), @_degs)

  with_degrees: (i) ->
    (args...) =>
      m = @_degs[i]
      for [D, val] in args when D? and @_elms.contains(D)
        @orbit(i, i + 1, D).each (E) -> m = m.with([E, val])
      create(@_dim, @_elms, @_idcs, @_ops, arrayWith(@_degs, i, m))

  without_degrees: (i) ->
    (args...) =>
      m = @_degs[i]
      for D in args when D? and @_elms.contains(D)
        @orbit(i, i + 1, D).each (E) -> m = m.without(E)
      create(@_dim, @_elms, @_idcs, @_ops, arrayWith(@_degs, i, m))

  # -- other methods specific to this class

  toString: ->
    elms = @elements().toArray()
    for D in [1..elms[elms.length-1]]
      throw("Bad element list") unless @elements().contains(D)

    buf = ["<1.1:#{@size()} #{@dimension()}:"]
    @indices().each (i) =>
      buf.push(",") if i > 0
      @elements().each (D) =>
        E = @s(i)(D) or 0
        if E == 0 or E >= D
          buf.push(" ") if D > 1
          buf.push("#{E}")
    buf.push(":")
    @indices().without(@dimension()).each (i) =>
      buf.push(",") if i > 0
      seen = new Set()
      @elements().each (D) =>
        unless seen.contains(D)
          buf.push(" ") if D > 1
          val = @m(i,i+1)(D) or 0
          buf.push("#{val}")
          @orbit(i, i + 1, D).each (E) -> seen = seen.with(E)
    buf.push(">")
    buf.join("")


## -- Test code --

puts = require('sys').puts

ds = new DSymbol(2, [1..3]).
       with_gluings(0)([1], [2], [3]).
       with_gluings(1)([1,2], [3]).
       with_gluings(2)([1], [2,3]).
       with_degrees(0)([1,8], [3,4]).
       with_degrees(1)([1,3])

puts "Symbol    = #{ds}"
puts "Size      = #{ds.size()}"
puts "Dimension = #{ds.dimension()}"
puts "Elements  = #{ds.elements().toArray()}"
puts "Indices   = #{ds.indices().toArray()}"

puts ""
ds.indices().each (i) ->
  ds.elements().each (D) ->
    puts "s(#{i})(#{D})   = #{ds.s(i)(D)}"

ds.indices().without(ds.dimension()).each (i) ->
  ds.elements().each (D) ->
    puts "m(#{i},#{i+1})(#{D}) = #{ds.m(i,i+1)(D)}"

puts ""
puts "After undefining m(0)(1) and s(1)(1) and removing element 3:"
ds1 = ds.without_degrees(0)(1).without_gluings(1)(1).without_elements(3)

puts "Symbol    = #{ds1}"
ds1.indices().each (i) ->
  ds1.elements().each (D) ->
    puts "s(#{i})(#{D})   = #{ds1.s(i)(D)}"

ds1.indices().without(ds1.dimension()).each (i) ->
  ds1.elements().each (D) ->
    puts "m(#{i},#{i+1})(#{D}) = #{ds1.m(i,i+1)(D)}"

### -- End of test code --
