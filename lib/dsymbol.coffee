if typeof(require) != 'undefined'
  # for now we assume that pazy.js lives next to gavrog.js
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  { Sequence }                = require('sequence')
  { HashSet, IntSet, IntMap } = require('indexed')
  { Dequeue }                 = require('dequeue')
else
  { HashSet, IntSet, IntMap, Sequence, Dequeue } = this.pazy


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
    collect = (elms, seen) =>
      if Sequence.empty elms
        null
      else
        D = elms.first()
        if seen.contains D
          collect elms.rest(), seen
        else
          Sequence.conj D, => collect elms.rest(), seen.plusAll @orbit(i, j)(D)

    collect(@elements().toSeq(), new IntSet()).stored()

  r: (i, j) => (D) => @orbitEdges(i, j)(D).size() / 2

  v: (i, j) => (D) => @m(i, j)(D) / @r(i, j)(D)

  traversal: (indices = @indices(), seeds = @elements()) ->
    collect = (seeds_left, next, seen) =>
      r = Sequence.find next, ([k, x]) -> x.size() > 0
      if r?
        [i, d] = r
        [D, s] = if special.contains i
          [d.last(), d.init()]
        else
          [d.first(), d.rest()]
        if seen.contains [D, i]
          newNext = next.map ([k, x]) -> if k == i then [k, s] else [k, x]
          collect seeds_left, newNext, seen
        else
          newNext = next.map ([k, x]) =>
            if k == i then [k, s] else [k, x.before @s(k)(D)]
          newSeen = seen.plus [D], [D, i], [@s(i)(D), i]
          Sequence.conj [D, i], -> collect seeds_left, newNext, newSeen
      else if seeds_left?
        D = seeds_left.first()
        if seen.contains [D]
          collect seeds_left.rest(), next, seen
        else
          newNext = next.map ([k, x]) => [k, x.before @s(k)(D)]
          newSeen = seen.plus [D]
          Sequence.conj [D], -> collect seeds_left.rest(), newNext, newSeen
      else
        null

    special = new IntSet().plusAll Sequence.take indices, 2
    initialNext = Sequence.map indices, (i) -> [i, new Dequeue()]
    collect(new Sequence(seeds), initialNext, new HashSet()).stored()

  # -- the following methods manipulate and incrementally build DSymbols

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

  dual: ->
    dim  = @dim__
    ops  = @ops__.map ([i, m])  -> [dim-i, m]
    degs = @degs__.map ([i, m]) -> [dim-1-i, m]
    create(dim, @elms__, @idcs__, ops, degs)

  filledIn: ->
    elms = new IntSet().plusAll Sequence.range 1, Sequence.max @elms__
    create(@dim__, elms, @idcs__, @ops__, @degs__)

  renumbered: (f) ->
    elms = @elms__.map f
    ops  = @ops__.map  ([i, a]) -> [i, a.map ([D, E]) -> [f(D), f(E)]]
    degs = @degs__.map ([i, a]) -> [i, a.map ([D, m]) -> [f(D), m]]
    create @dim__, elms, @idcs__, ops, degs

  concat: (sym) ->
    offset = Sequence.max @elms__
    tmp = sym.renumbered (D) -> D + offset

    elms = @elms__.plusAll tmp.elms__
    ops  = @ops__.map  ([i, a]) -> [i, a.plusAll tmp.ops__.get(i)]
    degs = @degs__.map ([i, a]) -> [i, a.plusAll tmp.degs__.get(i)]
    create @dim__, elms, @idcs__, ops, degs

  collapsed: (connector, args...) ->
    trash = new IntSet().plus args...

    unless Sequence.forall(trash, (D) => trash.contains @s(connector)(D))
      throw "set of removed elements must be invariant under s(#{connector})"

    end = (E, i) =>
      if trash.contains(E)
        edge = @orbitEdges(connector, i)(E).find ([E1, k]) ->
          k == i and not trash.contains E1
        edge[0]
      else
        E

    elms = @elms__.minus args...
    ops  = @ops__.map ([i, a]) =>
      kept = Sequence.select a, ([D, E]) => not trash.contains D
      [i, new IntMap().plusAll kept.map ([D, E]) => [D, end E, i]]
    tmp = create @dim__, elms, @idcs__, ops, @degs__

    degs = @degs__.map ([i, a]) =>
      [i, a.map ([D, m]) => [D, if m? then @v(i, i+1)(D) * tmp.r(i, i+1)(D)]]
    create @dim__, elms, @idcs__, ops, degs

  # -- other methods specific to this class

  assertValidity: ->
    size = @size()
    dim  = @dimension()

    throw "the dimension is negative" if dim < 0
    throw "the size is negative"      if size < 0

    unless Sequence.forall(@elements(), (D) -> D > 0)
      throw "there are non-positive elements"

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
          r = @r(i,j)(D)
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

  toString: ->
    join = (sep, seq) -> seq.into([]).join(sep) # use builtin join for efficiency
    sym = @filledIn()

    ops = join ",", sym.indices().toSeq().map (i) ->
      join " ", sym.orbitFirsts(i, i).map (D) -> sym.s(i)(D) or 0

    degs = join ",", sym.indices().toSeq().take(sym.dimension()).map (i) ->
      join " ", sym.orbitFirsts(i, i+1).map (D) -> sym.m(i,i+1)(D) or 0

    "<1.1:#{sym.size()} #{sym.dimension()}:#{ops}:#{degs}>"


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


# --------------------------------------------------------------------
# Exporting.
# --------------------------------------------------------------------

exports ?= this.pazy ?= {}
exports.DSymbol = DSymbol


# --------------------------------------------------------------------
# Test code --
# --------------------------------------------------------------------

test = ->
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

  puts ""
  puts "Collapsed after undefining an m-value:"
  puts "#{ds.withoutDegrees(1)(1).collapsed 0, 3}"

  puts ""
  puts "Traversed:"
  puts "#{ds.traversal()}"

#test()

### -- End of test code --
