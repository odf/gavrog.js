if typeof(require) != 'undefined'
  # for now we assume that pazy.js lives next to gavrog.js
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  { suspend, recur, resolve } = require('functional')
  { Sequence }                = require('sequence')
  { IntSet, IntMap }          = require('indexed')
else
  { suspend, recur, resolve, IntSet, IntMap, Sequence } = this.pazy

Set = IntSet
Map = IntMap


class DSymbol
  # -- the constructor receives the dimension and an initial set of elements

  constructor: (dimension, elms) ->
    @dim__  = dimension
    @elms__ = (new Set()).plus(elms...)
    @idcs__ = (new Set()).plus([0..dimension]...)
    @ops__  = (new Map() for i in [0..dimension])
    @degs__ = (new Map() for i in [0...dimension])

  # -- the following six methods implement the common interface for
  #    all Delaney symbol classes.

  dimension: -> @dim__
  indices:   -> @idcs__
  size:      -> @elms__.size()
  elements:  -> @elms__

  s: (i)     -> (D) => @ops__[i].get(D)

  m: (i, j)  ->
    if j?
      switch j
        when i + 1 then (D) => @degs__[i].get(D)
        when i - 1 then (D) => @degs__[j].get(D)
        when i     then (D) -> 1
        else            (D) -> 2
    else
      (D) -> 1

  # -- some private helper methods

  create = (dimension, elements, indices, operations, degrees) ->
    ds = new DSymbol(dimension)
    ds.elms__ = elements
    ds.idcs__ = indices
    ds.ops__  = operations
    ds.degs__ = degrees
    ds

  arrayWith = (a, i, x) -> (if j == i then x else a[j]) for j in [0...a.length]

  # -- the following methods will eventually go into a mix-in

  orbit: (i, j, D) ->
    partial = (E, k) =>
      F = if @s(k)(E)? then @s(k)(E) else E
      Sequence.conj [E, k], if F != D or k == i then => partial F, i+j-k
    partial(D, i).stored()

  # -- the following methods are used to build DSymbols incrementally

  withElements: (args...) ->
    create(@dim__, @elms__.plus(args...), @idcs__, @ops__, @degs__)

  withoutElements: ->
    args = new Sequence arguments
    idcs = @indices().toArray()
    ops  = (@ops__[i].minusAll(args).minusAll args.map @s(i) for i in idcs)
    degs = (s.minusAll(args) for s in @degs__)
    elms = @elms__.minusAll args
    create(@dim__, elms, @idcs__, ops, degs)

  withGluings: (i) -> () =>
    args = new Sequence arguments
    elms = args.reduce @elms__, (e, p) -> e.plus(p...)
    op   = args.reduce @ops__[i], (o, [D, E]) ->
             if E? then o.plus([D, E], [E, D]) else o.plus([D, D])
    create(@dim__, elms, @idcs__, arrayWith(@ops__, i, op), @degs__)

  withoutGluings: (i) ->
    (args...) =>
      op = Sequence.reduce args, @ops__[i], (a, D) -> a.minus(D, a.get(D))
      create(@dim__, @elms__, @idcs__, arrayWith(@ops__, i, op), @degs__)

  withDegrees: (i) ->
    (args...) =>
      m = Sequence.reduce args, @degs__[i], (x, [D, val]) =>
            @orbit(i, i + 1, D).reduce x, (y, [E, j]) -> y.plus([E, val])
      create(@dim__, @elms__, @idcs__, @ops__, arrayWith(@degs__, i, m))

  withoutDegrees: (i) ->
    (args...) =>
      m = Sequence.reduce args, @degs__[i], (x, D) =>
            @orbit(i, i + 1, D).reduce x, (y, [E, j]) -> y.minus(E)
      create(@dim__, @elms__, @idcs__, @ops__, arrayWith(@degs__, i, m))

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
    @indices().minus(@dimension()).each (i) =>
      buf.push(",") if i > 0
      seen = new Set()
      @elements().each (D) =>
        unless seen.contains(D)
          buf.push(" ") if D > 1
          val = @m(i,i+1)(D) or 0
          buf.push("#{val}")
          @orbit(i, i + 1, D).each (edge) -> seen = seen.plus(edge[0])
    buf.push(">")
    buf.join("")


DSymbol.fromString = (code) ->
  parts = code.trim().replace(/^</, '').replace(/>$/, '').split(":")
  data  = if parts[0].trim().match(/\d+\.\d+/) then parts[1..3] else parts[0..2]

  [size, dim] = data[0].trim().split(/\s+/)
  ds = new DSymbol((if dim? then dim else 2), [1..size])

  gluings = data[1].trim().split(/,/)
  for i in [0..ds.dimension()]
    D = 1
    seen = new Set()
    for E in (parseInt(s) for s in gluings[i].trim().split(/\s+/))
      unless 1 <= E <= size
        throw "s(#{i})(#{D}) must be between 1 and #{size} (found #{E})"
      if ds.s(i)(E)
        throw "s(#{i})(#{E}) was already set to #{s(i)(E)}"
      ds = ds.withGluings(i)([D, E])
      seen = seen.plus(D, E)
      D += 1 while seen.contains(D)

  degrees = data[2].trim().split(/,/)
  for i in [0...ds.dimension()]
    D = 1
    seen = new Set()
    for m in (parseInt(s) for s in degrees[i].trim().split(/\s+/))
      if m < 0
        throw "m(#{i},#{i+1})(#{D}) must be positive (found #{m})"
      orbit = ds.orbit(i, i+1, D)
      r = orbit.size() / 2
      if m % r > 0
        throw "m(#{i},#{i+1})(#{D}) must be a multiple of #{r} (found #{m})"
      ds = ds.withDegrees(i)([D, m])
      orbit.each (edge) -> seen = seen.plus(edge[0])
      D += 1 while seen.contains(D)

  ds


## -- Test code --

do ->
  puts = console.log

  ds = new DSymbol(2, [1..3]).
         withGluings(0)([1], [2], [3]).
         withGluings(1)([1,2], [3]).
         withGluings(2)([1], [2,3]).
         withDegrees(0)([1,8], [3,4]).
         withDegrees(1)([1,3])

  puts "Symbol    = #{ds}"
  puts "Size      = #{ds.size()}"
  puts "Dimension = #{ds.dimension()}"
  puts "Elements  = #{ds.elements().toArray()}"
  puts "Indices   = #{ds.indices().toArray()}"

  puts ""
  ds.indices().each (i) ->
    ds.elements().each (D) ->
      puts "s(#{i})(#{D})   = #{ds.s(i)(D)}"

  ds.indices().minus(ds.dimension()).each (i) ->
    ds.elements().each (D) ->
      puts "m(#{i},#{i+1})(#{D}) = #{ds.m(i,i+1)(D)}"

  puts ""
  puts "After undefining m(0)(1) and s(1)(1) and removing element 3:"
  ds1 = ds.withoutDegrees(0)(1).withoutGluings(1)(1).withoutElements(3)

  puts "Symbol    = #{ds1}"
  ds1.indices().each (i) ->
    ds1.elements().each (D) ->
      puts "s(#{i})(#{D})   = #{ds1.s(i)(D)}"

  ds1.indices().minus(ds1.dimension()).each (i) ->
    ds1.elements().each (D) ->
      puts "m(#{i},#{i+1})(#{D}) = #{ds1.m(i,i+1)(D)}"

  puts ""
  code = "<1.1:3:1 2 3,2 3,1 3:8 4,3>"
  puts "input string = #{code}"
  ds = DSymbol.fromString(code)
  puts "symbol built = #{ds}"

### -- End of test code --
