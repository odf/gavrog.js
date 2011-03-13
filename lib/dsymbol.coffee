if typeof(require) != 'undefined'
  # for now we assume that pazy.js lives next to gavrog.js
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  { Sequence }                = require('sequence')
  { IntSet, IntMap }          = require('indexed')
else
  { IntSet, IntMap, Sequence } = this.pazy


class DSymbol
  # -- the constructor receives the dimension and an initial set of elements

  constructor: (dimension, elms) ->
    @dim__  = dimension
    @elms__ = new IntSet().plus elms...
    @idcs__ = new IntSet().plus [0..dimension]...
    @ops__  = new IntMap().plus ([i, new IntMap()] for i in [0..dimension])...
    @degs__ = new IntMap().plus ([i, new IntMap()] for i in [0...dimension])...

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

  orbitEdges: (i, j) ->
    partial = (D, E, k) =>
      index = [i,j][k]
      F = if @s(index)(E) then @s(index)(E) else E
      Sequence.conj [E, index], if F != D or k == 0 then => partial D, F, 1-k

    (D) -> partial(D, D, 0).stored()

  orbit: (i, j) -> (D) =>
    new IntSet().plusAll(@orbitEdges(i, j)(D).map ([E, k]) -> E).toSeq()

  orbitFirsts: (i, j) ->
    step = ([reps, seen], D) =>
      if seen.contains(D)
        [reps, seen]
      else
        [reps.concat([D]), seen.plusAll @orbit(i, j)(D)]

    @elements().toSeq().reduce([new Sequence(), new IntSet()], step)[0]

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
            @orbit(i, i + 1)(D).map (E) -> [E, val]
      create @dim__, @elms__, @idcs__, @ops__, @degs__.plus [i, m]

  withoutDegrees: (i) ->
    (args...) =>
      m = @degs__.get(i).minusAll Sequence.flatMap args, @orbit(i, i + 1)
      create @dim__, @elms__, @idcs__, @ops__, @degs__.plus [i, m]

  # -- other methods specific to this class

  assertValidity: ->
    size = @size()
    dim  = @dimension()

    throw "the dimension is negative" if dim < 0
    throw "the size is negative"      if size < 0

    tmp1 = @elements().toSeq().flatMap (D) =>
      @indices().toSeq().map (i) =>
        j = i + 1
        Di = @s(i)(D)
        Dj = @s(j)(D) if j < dim
        if not (0 <= Di <= size)
          "out of range: s(#{i}) #{D} = #{Di}"
        else if Di > 0 and @s(i)(Di) != D
          "inconsistent: s(i) s(i) #{D} = #{s(i) s(i) D}"
        else if i < dim and @m(i, j)(D) < 0
          "illegal: m(#{i}, #{j}) #{D} = #{m(i, j) D}"
        else if i < dim and @m(i, j)(D) != @m(i, j)(Di)
          "inconsistent: m(#{i}, #{j}) #{D} = #{@m(i, j) D}, " +
          "but m(#{i}, #{j}) s(#{i}) #{D} = #{@m(i, j) Di}"
        else if i < dim and @m(i, j)(D) != @m(i, j)(@s(j)(D))
          "inconsistent: m(#{i}, #{j}) #{D} = #{@m(i, j) D}, " +
          "but m(#{i}, #{j}) s(#{j}) #{D} = #{@m(i, j) @s(j) Di}"
        else
          null
    bad1 = tmp1.select (x) -> x?
    throw bad1.into([]).join("\n") if bad1?

    tmp2 = @elements().toSeq().flatMap (D) =>
      Sequence.range(0, dim-1).flatMap (i) =>
        Sequence.range(i+1, dim).map (j) =>
          edges = @orbitEdges(i,j)(D)
          m = @m(i,j)(D)
          r = edges.size() / 2
          if m % r > 0 and edges.forall(([E, k]) => @s(k)(E))
            "inconsistent: m(#{i}, #{j})(#{D}) = #{m} " +
            "should be a multiple of #{r}"
          else if m < r
            "inconsistent: m(#{i}, #{j})(#{D}) = #{m} " +
            "should be at least #{r}"
          else
            null
    bad2 = tmp2.select (x) -> x?
    throw bad2.into([]).join("\n") if bad2?

  dual: ->
    dim  = @dim__
    ops  = @ops__.map ([i, m])  -> [dim-i, m]
    degs = @degs__.map ([i, m]) -> [dim-1-i, m]
    create(dim, @elms__, @idcs__, ops, degs)

  toString: ->
    join = (sep, seq) -> seq.into([]).join(sep) # use builtin join for efficiency
    high = @elements().toSeq().max()

    unless Sequence.range(1, high).forall((D) => @elements().contains(D))
      raise "there are gaps in the element list"

    ops = join ",", @indices().toSeq().map (i) =>
      join " ", @orbitFirsts(i, i).map (D) => @s(i)(D) or 0

    degs = join ",", @indices().toSeq().take(@dimension()).map (i) =>
      join " ", @orbitFirsts(i, i+1).map (D) => @m(i,i+1)(D) or 0

    "<1.1:#{@size()} #{@dimension()}:#{ops}:#{degs}>"


DSymbol.fromString = (code) ->
  extract = (sym, str, fun) -> (
    Sequence.map(str.trim().split(/\s+/), parseInt).
      reduce [new Sequence(), sym.elements()], ([acc, todo], val) ->
        D = todo.toSeq()?.first()
        [acc.concat([[D, val]]), todo.minusAll fun(D, val)]
    )[0]

  parts = code.trim().replace(/^</, '').replace(/>$/, '').split(":")
  data  = if parts[0].trim().match(/\d+\.\d+/) then parts[1..3] else parts[0..2]

  [size, dim] = data[0].trim().split(/\s+/)
  dimension   = if dim? then dim else 2
  gluings     = data[1].trim().split(/,/)
  degrees     = data[2].trim().split(/,/)

  ds0 = new DSymbol(dimension, [1..size])

  ds1 = Sequence.range(0, dimension).reduce ds0, (sym, i) ->
    pairs = extract sym, gluings[i], (D, E) -> new Sequence([D, E])

    pairs.reduce new IntMap(), (seen, [D, E]) ->
      throw "s(#{i})(#{E}) was already set to #{seen.get(E)}" if seen.get(E)
      seen.plus [D, E], [E, D]

    sym.withGluings(i) pairs.into([])...

  ds2 = Sequence.range(0, dimension-1).reduce ds1, (sym, i) ->
    pairs = extract sym, degrees[i], (D, m) -> sym.orbit(i, i+1)(D)
    sym.withDegrees(i) pairs.into([])...

  ds2.assertValidity()

  ds2


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
  puts "dual         = #{ds.dual()}"

  puts ""
  code = "<1.1:3:1 2 3,2 3,1 3:7 4,3>"
  puts "input string = #{code}"
  try
    DSymbol.fromString(code)
  catch ex
    console.log ex

### -- End of test code --
