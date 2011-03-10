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
    @elms__ = new Set().plus elms...
    @idcs__ = new Set().plus [0..dimension]...
    @ops__  = new Map().plus ([i, new Map()] for i in [0..dimension])...
    @degs__ = new Map().plus ([i, new Map()] for i in [0...dimension])...

  # -- the following six methods implement the common interface for
  #    all Delaney symbol classes.

  dimension: -> @dim__
  indices:   -> @idcs__
  size:      -> @elms__.size()
  elements:  -> @elms__

  s: (i)     -> (D) => @ops__.get(i).get(D)

  m: (i, j)  ->
    if j?
      switch j
        when i + 1 then (D) => @degs__.get(i).get(D)
        when i - 1 then (D) => @degs__.get(j).get(D)
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

  # -- the following methods will eventually go into a mix-in

  orbit: (i, j) ->
    partial = (D, E, k) =>
      F0 = @s([i,j][k])(E)
      F = if F0? then F0 else E
      Sequence.conj [E, k], if F != D or k == 0 then => partial D, F, 1-k

    (D) -> partial(D, D, 0).stored()

  orbitFirsts: (i, j) ->
    step = ([reps, seen], D) =>
      if seen.contains(D)
        [reps, seen]
      else
        [reps.concat([D]), seen.plusAll @orbit(i, j)(D).map ([E,k]) -> E]

    @elements().elements().reduce([new Sequence(), new Set()], step)[0]

  # -- the following methods are used to build DSymbols incrementally

  withElements: (args...) ->
    create(@dim__, @elms__.plus(args...), @idcs__, @ops__, @degs__)

  withoutElements: ->
    args = new Sequence arguments
    elms = @elms__.minusAll args
    ops  = @ops__.map ([i, a]) => [i, a.minusAll(args).minusAll args.map @s(i)]
    degs = @degs__.map ([i, d]) => [i, d.minusAll(args)]
    create @dim__, elms, @idcs__, ops, degs

  withGluings: (i) ->
    (args...) =>
      elms = @elms__.plusAll Sequence.flatten args
      op   = @ops__.get(i).plusAll Sequence.flatMap args, ([D, E]) ->
               if E? then [[D, E], [E, D]] else [[D, D]]
      create @dim__, elms, @idcs__, @ops__.plus([i, op]), @degs__

  withoutGluings: (i) ->
    (args...) =>
      op = @ops__.get(i).minusAll Sequence.flatMap args, (D) => [D, @s(i)(D)]
      create @dim__, @elms__, @idcs__, @ops__.plus([i, op]), @degs__

  withDegrees: (i) ->
    (args...) =>
      m = @degs__.get(i).plusAll Sequence.flatMap args, ([D, val]) =>
            @orbit(i, i + 1)(D).map ([E, k]) -> [E, val]
      create @dim__, @elms__, @idcs__, @ops__, @degs__.plus [i, m]

  withoutDegrees: (i) ->
    (args...) =>
      m = @degs__.get(i).minusAll Sequence.flatMap args, (D) =>
            @orbit(i, i + 1)(D).map ([E,k]) -> E
      create @dim__, @elms__, @idcs__, @ops__, @degs__.plus [i, m]

  # -- other methods specific to this class

  toString: ->
    join = (sep, seq) -> seq.into([]).join(sep) # use builtin join for efficiency
    max = (seq) ->
      Sequence.reduce seq.rest(), seq.first(), (a,b) -> if a > b then a else b

    for D in [1..max(@elements().elements()]]
      throw("Bad element list") unless @elements().contains(D)

    ops = join ",", @indices().elements().map (i) =>
      join " ", @orbitFirsts(i, i).map (D) => @s(i)(D) or 0

    degs = join ",", @indices().elements().take(@dimension()).map (i) =>
      join " ", @orbitFirsts(i, i+1).map (D) => @m(i,i+1)(D) or 0

    "<1.1:#{@size()} #{@dimension()}:#{ops}:#{degs}>"


DSymbol.fromString = (code) ->
  parts = code.trim().replace(/^</, '').replace(/>$/, '').split(":")
  data  = if parts[0].trim().match(/\d+\.\d+/) then parts[1..3] else parts[0..2]

  [size, dim] = data[0].trim().split(/\s+/)
  ds = new DSymbol((if dim? then dim else 2), [1..size])

  gluings = data[1].trim().split(/,/)
  ds.indices().elements().each (i) ->
    tmp = Sequence.map(gluings[i].trim().split(/\s+/), parseInt).
      reduce [new Sequence(), ds.elements()], ([acc, todo], E) ->
        D = todo.elements()?.first()
        [acc.concat([[D,E]]), todo.minus(D, E)]
    pairs = tmp[0]

    ds = pairs.reduce ds, (sym, [D, E]) ->
      unless 1 <= E <= size
        throw "s(#{i})(#{D}) must be between 1 and #{size} (found #{E})"
      if sym.s(i)(E)
        throw "s(#{i})(#{E}) was already set to #{s(i)(E)}"
      sym.withGluings(i)([D, E])

  degrees = data[2].trim().split(/,/)
  ds.indices().elements().take(ds.dimension()).each (i) ->
    todo = ds.elements()
    Sequence.map(degrees[i].trim().split(/\s+/), parseInt).each (m) ->
      D = todo.elements()?.first()
      if m < 0
        throw "m(#{i},#{i+1})(#{D}) must be positive (found #{m})"
      orbit = ds.orbit(i, i+1)(D)
      r = orbit.size() / 2
      if m % r > 0
        throw "m(#{i},#{i+1})(#{D}) must be a multiple of #{r} (found #{m})"
      ds = ds.withDegrees(i)([D, m])
      todo = todo.minusAll orbit.map ([E,k]) -> E

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
