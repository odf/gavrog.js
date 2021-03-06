if typeof(require) != 'undefined'
  # for now we assume that pazy.js lives next to gavrog.js
  require.paths.unshift("#{__dirname}/../../pazy.js/lib")
  { bounce }                           = require('functional')
  { seq }                              = require('sequence')
  { IntSet, IntMap, HashSet, HashMap } = require('indexed')
  { Stack }                            = require('stack')
  { Queue }                            = require('queue')
  { Partition }                        = require('partition')
  { num }                              = require('number')
  require 'sequence_extras'
else
  {
    bounce, seq, IntSet, IntMap, HashSet, HashMap, Stack, Queue, Partition, num
  } = this.pazy


# ----

# To be used in class bodies in order to create methods with memoized results.

memo = (klass, name, f) ->
  klass::[name] = -> x = f.call(this); (@[name] = -> x)()

memox = (klass, name, f) ->
  key = "#{name}__"
  klass::[name] = (args...) ->
    val = (@[key] ||= new HashMap()).get(args)
    if val?
      val
    else
      v = f.apply(this, args)
      @[key] = @[key].plus [args, v]
      v

# ----

# Other helper methods
zip = (s,t) -> seq.zip(s, t).map (x) -> x.into []
zap = (s,t) -> zip(s,t)?.takeWhile ([a,b]) -> (a? and b?)


# ----

# The base class for Delaney symbols. All child classes need to
# implement the following four methods (see class DSymbol below for
# details):
#
#     indexSet
#     elementSet
#     s
#     m
#
# The first two methods must return an object that recognizes these methods:
#
#     toSeq
#     size
#     contains

class Delaney
  isDelaney: -> true

  indices:        -> @indexSet().toSeq()
  dimension:      -> @indexSet().size() - 1
  hasIndex:   (i) -> @indexSet().contains i

  elements:       -> @elementSet().toSeq()
  size:           -> @elementSet().size()
  hasElement: (D) -> @elementSet().contains D

  flat: -> DSymbol.flat this

  assertValidity: ->
    report = (msgs) ->
      if msgs?.find((x) -> x?)
        throw new Error(msgs?.select((x) -> x?)?.into([]).join("\n"))

    report @indices()?.flatMap (i) =>
      @elements()?.map (D) =>
        Di = @s(i)(D)
        if not @hasElement Di
          "not an element: s(#{i}) #{D} = #{Di}"
        else if Di > 0 and @s(i)(Di) != D
          "inconsistent: s(#{i}) s(#{i}) #{D} = #{s(i) s(i) D}"

    report @indices()?.flatMap (i) =>
      @indices()?.flatMap (j) =>
        @elements()?.map (D) =>
          if @m(i, j)(D) < 0
            "illegal: m(#{i}, #{j}) #{D} = #{m(i, j) D}"
          else if @m(i, j)(D) != @m(i, j) @s(i) D
            "inconsistent: m(#{i}, #{j}) #{D} = #{@m(i, j) D}, " +
            "but m(#{i}, #{j}) s(#{i}) #{D} = #{@m(i, j) @s(i) D}"

    report @indices()?.flatMap (i) =>
      @indices()?.flatMap (j) =>
        @orbitFirsts(i, j)?.map (D) =>
          complete = @orbit(i, j)(D)?.forall (E) => @s(i)(E)? and @s(j)(E)?
          m = @m(i,j)(D)
          r = @r(i,j)(D)
          if m % r > 0 and complete
            "inconsistent: m(#{i}, #{j})(#{D}) = #{m} " +
            "should be a multiple of #{r}"
          else if m < r
            "inconsistent: m(#{i}, #{j})(#{D}) = #{m} should be at least #{r}"

  r: (i, j) -> (D) =>
    step = (n, E0) =>
      E1 = @s(i)(E0) or E0
      E2 = @s(j)(E1) or E1
      if E2 == D then n + 1 else -> step n + 1, E2

    bounce step 0, D

  v: (i, j) -> (D) => @m(i, j)(D) / @r(i, j)(D)

  drop = (s, f) ->
    if s.first()? and f s.first() then -> drop s.rest(), f else s

  traversal: (idcs, seed_elms) ->
    collect = (seeds_left, next, seen) =>
      tmp = next.map ([k, d]) -> [k, bounce drop d, (x) -> seen.contains [x, k]]
      if r = tmp.find(([k, x]) -> x.first()?)
        [i, d] = r
        [D, s] = [d.first(), d.rest()]
        newNext = tmp.map ([k, x]) => [k, if k == i then s else x.push @s(k)(D)]
        newSeen = seen.plus [D], [D, i], [@s(i)(D), i]
        seq.conj [D, i], -> collect seeds_left, newNext, newSeen
      else if D = seeds_left?.find((x) -> not seen.contains [x])
        newNext = tmp.map ([k, x]) => [k, x.push @s(k)(D)]
        newSeen = seen.plus [D]
        seq.conj [D], -> collect seeds_left.rest(), newNext, newSeen
      else
        null

    indices = seq(idcs) or @indices()
    seeds = seq(seed_elms) or @elements()

    stacks = seq.take(indices, 2)?.map (i) -> [i, new Stack()]
    queues = seq.drop(indices, 2)?.map (i) -> [i, new Queue()]
    initialNext = seq.concat(stacks, queues).forced()

    collect seeds, initialNext, new HashSet()

  orbit: (indices...) -> (D) =>
    @traversal(indices, [D])?.map(([E, k]) -> E)?.uniq()

  orbitFirsts: (indices...) ->
    @traversal(indices)?.select(([D, k]) -> not k?)?.map ([D]) -> D

  orbits: (indices...) ->
    @orbitFirsts(indices...).map @orbit(indices...)

  memo @, 'isComplete', ->
    @elements()?.forall (D) =>
      @indices()?.forall (i) => @s(i)(D)? and
        @indices()?.forall (j) => @m(i, j)(D)?

  memo @,'isConnected', -> not @orbitFirsts()?.rest()

  traversalPartialOrientation: (traversal) ->
    seq.reduce traversal, new HashMap(), (hash, [D,i]) =>
      hash.plus [D, if i? then -hash.get(@s(i)(D)) else 1]

  orbitPartialOrientation: (idcs, seeds) ->
    @traversalPartialOrientation @traversal idcs, seeds

  orbitIsLoopless: (idcs, seeds) ->
    not @traversal(idcs, seeds)?.find ([D, i]) => i? and @s(i)(D) == D

  orbitIsOriented: (idcs, seeds) ->
    traversal = @traversal idcs, seeds
    ori = @traversalPartialOrientation traversal
    not traversal?.find ([D, i]) => i? and ori.get(@s(i)(D)) == ori.get(D)

  orbitIsWeaklyOriented: (idcs, seeds) ->
    traversal = @traversal idcs, seeds
    ori = @traversalPartialOrientation traversal
    not traversal?.find ([D, i]) =>
      i? and @s(i)(D) != D and ori.get(@s(i)(D)) == ori.get(D)

  memo @,'isLoopless', -> @orbitIsLoopless()
  memo @,'isOriented', -> @orbitIsOriented()
  memo @,'isWeaklyOriented', -> @orbitIsWeaklyOriented()
  memo @,'partialOrientation', -> @orbitPartialOrientation()

  protocol: (indices, traversal) ->
    imap = new HashMap().plusAll zap indices, seq.from 0
    indexPairs = zap indices, indices.drop 1

    tmp = traversal?.accumulate [new HashMap(), 1], ([hash, n, s], [D,i]) =>
      [E, isNew] = if hash.get(D)? then [hash.get(D), false] else [n, true]
      head = if i? then [imap.get(i), hash.get(@s(i)(D)), E] else [-1, E]
      if isNew
        [hash.plus([D,n]), n+1,
         seq.concat head, indexPairs?.map ([i,j]) => @m(i,j)(D)]
      else
        [hash, n, head]

    [tmp?.flatMap(([h, n, s]) -> s), tmp?.map ([h, n, s]) -> h]

  lesser = (s1, s2) ->
    if not s1? or s1[0].sub(s2[0]).find((a) -> a) > 0 then s2 else s1

  memo @,'invariant', ->
    unless @isConnected()
      throw new Error "Not yet implemented for non-connected symbols"

    tmp = @elements().reduce null, (best, D) =>
      lesser best, @protocol @indices(), @traversal null, [D]
    [tmp[0].forced(), tmp[1].last()] if tmp?

  memo @,'hashCode', ->
    seq.reduce @invariant(), 0, (code, n) -> (code * 37 + n) & 0xffffffff

  equals: (other) ->
    other.isDelaney and this.invariant()[0].equals other.invariant()[0]

  memox @, 'type', (D) ->
    (@indices()?.flatMap (i) =>
      @indices()?.select((j) -> j > i)?.map (j) =>
        @m(i, j)(D)
    ).forced()

  typePartition: ->
    unless @isConnected()
      throw new Error "Not yet implemented for non-connected symbols"

    step = (p, q) =>
      if not q?.first()?
        p
      else
        [[D, E], qn] = [q.first(), q.rest()]
        if p.find(D) == p.find(E)
          -> step p, qn
        else if @type(D).equals(@type(E))
          pn = p.union(D, E)
          qx = seq.reduce @indices(), qn, (t, i) =>
            t.push [@s(i)(D), @s(i)(E)]
          -> step pn, qx

    D0 = @elements().first()
    seq.reduce @elements(), new Partition(), (p, D) ->
      pn = bounce step p, (new Queue()).push [D0, D]
      if pn? then pn else p

  memo @,'isMinimal', ->
    p = @typePartition()
    seq.forall @elements(), (D) -> p.find(D) == D

  memo @,'curvature2D', ->
    throw new Error "Symbol must be two-dimensional" unless @dimension() == 2

    inv = (x) -> num.div 1, x
    term = (i, j) => @elements().map(@m(i, j)).map(inv).fold (a, b) -> a.plus b

    [i, j, k] = @indices().into []
    term(i, j).plus(term(i, k)).plus(term(j, k)).minus @size()

  memo @,'isSpherical2D', ->
    throw new Error "Symbol must be two-dimensional" unless @dimension() == 2
    throw new Error "Symbol must be connected"       unless @isConnected()

    if @curvature2D().cmp(0) > 0
      sym = @flat().orientedCover()
      [r, s, t] = sym.indices().into []
      deg = seq.flatMap [[r, s], [r, t], [s, t]], ([i, j]) ->
        sym.orbitFirsts(i, j).map(sym.v(i, j)).select (v) -> v > 1
      not (deg?.size() == 1 or (deg?.size() == 2 and deg.get(0) != deg.get(1)))
    else
      false

  memo @,'sphericalGroupSize2D', ->
    if @isSpherical2D()
      @curvature2D().div(4).inv().toNative()
    else
      throw new Error "Symbol must be spherical"

  memo @,'isLocallyEuclidean3D', ->
    throw new Error "Symbol must be three-dimensional" unless @dimension() == 3

    seq.forall @indices(), (i) =>
      idcs = seq.select(@indices(), (j) -> j != i).into []
      seq.forall @orbitFirsts(idcs...), (D) =>
        new Subsymbol(this, idcs, D).isSpherical2D()

  memo @,'orbifoldSymbol2D', ->
    throw new Error "Symbol must be two-dimensional" unless @dimension() == 2
    throw new Error "Symbol must be connected"       unless @isConnected()

    [r, s, t] = @indices().into []
    tmp = seq.flatMap [[r, s], [r, t], [s, t]], ([i, j]) =>
      @orbitFirsts(i, j).map((D) => [@v(i, j)(D), @orbitIsLoopless([i, j], [D])])
    cones = tmp.select(([v, b]) ->     b and v > 1)?.map(([v, b]) -> v)
    crnrs = tmp.select(([v, b]) -> not b and v > 1)?.map(([v, b]) -> v)

    c0 = @curvature2D().div(2)
    c1 = seq.reduce cones, c0, (s, v) -> s.plus num.div v-1, v
    c2 = seq.reduce crnrs, c1, (s, v) -> s.plus num.div v-1, 2*v
    c3 = if @isLoopless() then c2 else c2.plus 1
    c = 2 - c3.toNative()

    series = (n, c) -> seq.join seq.constant(c).take(n), ''

    tmp = seq.into(cones, []).sort().join('') +
          (if @isLoopless() then '' else '*') +
          seq.into(crnrs, []).sort().join('') +
          if @isWeaklyOriented() then series(c / 2, 'o') else series(c, 'x')

    if tmp.length > 0 then tmp else '1'


class DSymbol extends Delaney
  # -- the constructor receives the dimension and an initial set of elements

  constructor: (dimension, elms) ->
    @dim__  = dimension
    @elms__ = new IntSet().plus elms...
    @ops__  = new IntMap().plus ([i, new IntMap()] for i in [0..dimension])...
    @degs__ = new IntMap().plus ([i, new IntMap()] for i in [0...dimension])...

  # -- the following four methods implement the common interface for
  #    all Delaney symbol classes.

  memo @, 'indexSet', -> new IntSet().plusAll seq.range 0, @dim__
  elementSet: -> @elms__

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

  create = (dimension, elements, operations, degrees) ->
    ds = new DSymbol(dimension)
    ds.elms__ = elements
    ds.ops__  = operations
    ds.degs__ = degrees
    ds

  # -- the following methods manipulate and incrementally build DSymbols

  withElements: (args...) ->
    create(@dim__, @elms__.plus(args...), @ops__, @degs__)

  withoutElements: ->
    args = seq arguments
    elms = @elms__.minusAll args
    ops  = @ops__.map ([i, a]) => [i, a.minusAll(args).minusAll args.map @s(i)]
    degs = @degs__.map ([i, d]) => [i, d.minusAll(args)]
    create @dim__, elms, ops, degs

  withGluings: (i) ->
    (args...) =>
      elms = @elms__.plusAll seq.flatten args
      op   = @ops__.get(i).plusAll seq.flatMap args, ([D, E]) ->
               if E? then [[D, E], [E, D]] else [[D, D]]
      create @dim__, elms, @ops__.plus([i, op]), @degs__

  withoutGluings: (i) ->
    (args...) =>
      op = @ops__.get(i).minusAll seq.flatMap args, (D) => [D, @s(i)(D)]
      create @dim__, @elms__, @ops__.plus([i, op]), @degs__

  withDegrees: (i) ->
    (args...) =>
      m = @degs__.get(i).plusAll seq.flatMap args, ([D, val]) =>
            @orbit(i, i + 1)(D).map (E) -> [E, val]
      create @dim__, @elms__, @ops__, @degs__.plus [i, m]

  withoutDegrees: (i) ->
    (args...) =>
      m = @degs__.get(i).minusAll seq.flatMap args, @orbit(i, i + 1)
      create @dim__, @elms__, @ops__, @degs__.plus [i, m]

  dual: ->
    dim  = @dim__
    ops  = @ops__.map ([i, m])  -> [dim-i, m]
    degs = @degs__.map ([i, m]) -> [dim-1-i, m]
    create(dim, @elms__, ops, degs)

  filledIn: ->
    elms = new IntSet().plusAll seq.range 1, seq.max @elms__
    create(@dim__, elms, @ops__, @degs__)

  renumbered: (f) ->
    elms = @elms__.map f
    ops  = @ops__.map  ([i, a]) -> [i, a.map ([D, E]) -> [f(D), f(E)]]
    degs = @degs__.map ([i, a]) -> [i, a.map ([D, m]) -> [f(D), m]]
    create @dim__, elms, ops, degs

  concat: (sym) ->
    offset = seq.max @elms__
    tmp = sym.renumbered (D) -> D + offset

    elms = @elms__.plusAll tmp.elms__
    ops  = @ops__.map  ([i, a]) -> [i, a.plusAll tmp.ops__.get(i)]
    degs = @degs__.map ([i, a]) -> [i, a.plusAll tmp.degs__.get(i)]
    create @dim__, elms, ops, degs

  collapsed: (connector, args...) ->
    trash = new IntSet().plus args...

    unless seq.forall(trash, (D) => trash.contains @s(connector)(D))
      throw new Error "removed set must be invariant under s(#{connector})"

    end = (E, i) =>
      if trash.contains(E)
        edge = @traversal([connector, i], [E]).find ([E1, k]) ->
          k == i and not trash.contains E1
        edge[0]
      else
        E

    elms = @elms__.minus args...
    ops  = @ops__.map ([i, a]) =>
      kept = seq.select a, ([D, E]) => not trash.contains D
      [i, new IntMap().plusAll kept.map ([D, E]) => [D, end E, i]]
    tmp = create @dim__, elms, ops, @degs__

    degs = @degs__.map ([i, a]) =>
      [i, a.map ([D, m]) => [D, if m? then @v(i, i+1)(D) * tmp.r(i, i+1)(D)]]
    create @dim__, elms, ops, degs

  memo @,'canonical', ->
    map = @invariant()[1]
    @renumbered (D) -> map.get(D)

  memo @,'minimal', ->
    p = @typePartition()
    reps = seq.select @elements(), (D) -> p.find(D) == D
    if reps.equals @elements()
      this
    else
      n = reps.size()
      map = new HashMap().plusAll zap reps, seq.from 1

      ops = new IntMap().plusAll seq.range(0, @dimension()).map (i) =>
        pairs = reps.map (D) => [map.get(D), map.get p.find @s(i)(D)]
        [i, new IntMap().plusAll pairs]

      degs = new IntMap().plusAll seq.range(0, @dimension()-1).map (i) =>
        pairs = reps.map (D) => [map.get(D), @m(i, i+1)(D)]
        [i, new IntMap().plusAll pairs]

      create @dimension(), new IntSet().plus([1..n]...), ops, degs

  orientedCover: ->
    if @isOriented()
      this
    else
      ori = @partialOrientation()
      dim = @dimension()
      n = @size()

      ops = new IntMap().plusAll seq.range(0, dim).map (i) =>
        pairs = @elements().flatMap (D) =>
          E = @s(i)(D)
          if E == D
            [ [D    , D + n], [D + n, D    ] ]
          else if ori.get(D) == ori.get(E)
            [ [D    , E + n], [D + n, E    ], [E    , D + n], [E + n, D    ] ]
          else
            [ [D    , E    ], [D + n, E + n], [E    , D    ], [E + n, D + n] ]
        [i, new IntMap().plusAll pairs]

      degs = new IntMap().plusAll seq.range(0, dim-1).map (i) =>
        pairs = @elements().flatMap (D) =>
          m = @m(i, i+1)(D)
          [[D, m], [D+n, m]]
        [i, new IntMap().plusAll pairs]

      create dim, new IntSet().plus([1..(2 * n)]...), ops, degs

  # -- other methods specific to this class

  toString: ->
    join = (sep, s) -> seq.join s, sep
    sym = @filledIn()

    ops = join ",", sym.indices().map (i) ->
      join " ", sym.orbitFirsts(i, i).map (D) -> sym.s(i)(D) or 0

    degs = join ",", sym.indices().take(sym.dimension()).map (i) ->
      join " ", sym.orbitFirsts(i, i+1).map (D) -> sym.m(i,i+1)(D) or 0

    "<1.1:#{sym.size()} #{sym.dimension()}:#{ops}:#{degs}>"


DSymbol.flat = (sym) ->
  raise new Error "must have a definite size" unless sym.size()?

  dim  = sym.dimension()
  elms = seq.range 1, sym.size()

  ds = new DSymbol dim
  ds.elms__ = new HashSet().plusAll elms

  emap = new HashMap().plusAll zip sym.elements(), elms
  irev = new IntMap().plusAll zip seq.range(0, dim), sym.indices()

  ds.ops__ = new IntMap().plusAll seq.range(0, dim).map (i) =>
    j = irev.get i
    pairs = sym.elements().map (D) => [emap.get(D), emap.get sym.s(j)(D)]
    [i, new IntMap().plusAll pairs]

  ds.degs__ = new IntMap().plusAll seq.range(0, dim-1).map (i) =>
    [j, k] = [irev.get(i), irev.get(i+1)]
    pairs = sym.elements().map (D) => [emap.get(D), sym.m(j, k)(D)]
    [i, new IntMap().plusAll pairs]

  ds


DSymbol.fromString = (code) ->
  extract = (sym, str, fun) -> (
    seq.map(str.trim().split(/\s+/), parseInt).
      reduce [seq(), new IntSet().plusAll sym.elements()],
        ([acc, todo], val) ->
          D = todo.toSeq()?.first()
          [seq.concat(acc, [[D, val]]), todo.minusAll fun(D, val)]
    )[0]

  parts = code.trim().replace(/^</, '').replace(/>$/, '').split(":")
  data  = if parts[0].trim().match(/\d+\.\d+/) then parts[1..3] else parts[0..2]

  [size, dim] = seq.map(data[0].trim().split(/\s+/), parseInt).into []
  dimension   = if dim? then dim else 2
  throw new Error "the dimension is negative" if dimension < 0
  throw new Error "the size is negative"      if size < 0

  gluings     = data[1].trim().split(/,/)
  degrees     = data[2].trim().split(/,/)

  ds0 = new DSymbol(dimension, [1..size])

  ds1 = seq.range(0, dimension).reduce ds0, (sym, i) ->
    pairs = extract sym, gluings[i], (D, E) -> seq([D, E])

    pairs.reduce new IntMap(), (seen, [D, E]) ->
      if seen.get(E)
        throw new Error "s(#{i})(#{E}) was already set to #{seen.get(E)}"
      seen.plus [D, E], [E, D]

    sym.withGluings(i) pairs.into([])...

  ds2 = seq.range(0, dimension-1).reduce ds1, (sym, i) ->
    pairs = extract sym, degrees[i], (D, m) -> sym.orbit(i, i+1)(D)
    sym.withDegrees(i) pairs.into([])...

  ds2.assertValidity()

  ds2


class Subsymbol extends Delaney
  constructor: (@base, @idcs, @seed) ->

  # -- the following eight methods implement the common interface for
  #    all Delaney symbol classes.

  memo @,'indexSet',   -> new IntSet().plusAll seq @idcs
  memo @,'elementSet', ->
    elms = @base.traversal(@idcs, [@seed])?.map(([E, k]) -> E)?.uniq()
    new HashSet().plusAll elms

  s: (i) ->
    if @hasIndex(i)
      (D) => @base.s(i)(D) if @hasElement(D)
    else
      (D) ->

  m: (i, j) ->
    if @hasIndex(i) and not j? or @hasIndex(j)
      (D) => @base.m(i,j)(D) if @hasElement(D)
    else
      (D) ->


# --------------------------------------------------------------------
# Exporting.
# --------------------------------------------------------------------

exports ?= this.pazy ?= {}
exports.Delaney   = Delaney
exports.DSymbol   = DSymbol
exports.Subsymbol = Subsymbol


# --------------------------------------------------------------------
# Test code --
# --------------------------------------------------------------------

test = ->
  { show } = require 'testing'

  puts = console.log

  ds = new DSymbol(2, [1..3]).
         withGluings(0)([1], [2], [3]).
         withGluings(1)([1,2], [3]).
         withGluings(2)([1], [2,3]).
         withDegrees(0)([1,8], [3,4]).
         withDegrees(1)([1,3])

  show -> ds
  show -> ds.size()
  show -> ds.dimension()
  show -> ds.elements()
  show -> ds.indices()
  show -> ds.s(1)(1)
  show -> ds.m(0,1)(2)

  puts ""
  show -> ds.withoutDegrees(0)(1).withoutGluings(1)(1).withoutElements(3)

  puts ""
  show -> ds = DSymbol.fromString "<1.1:3:1 2 3,2 3,1 3:8 4,3>"
  show -> ds.dual()

  puts ""
  puts "The following should throw an error:"
  show -> DSymbol.fromString "<1.1:3:1 2 3,2 3,1 3:7 4,3>"

  puts ""
  show -> ds.withoutDegrees(1)(1).collapsed 0, 3

  puts ""
  show -> ds.traversal()
  show -> ds.protocol(ds.indices(), ds.traversal(ds.indices(), [1]))[0].into []

  puts ""
  show -> ds.invariant()[0].into []
  show -> ds.invariant()[1].toSeq()
  show -> ds.canonical()

  puts ""
  p = null
  show -> p = ds.typePartition()
  show -> p.find 1

  puts ""
  show -> ds.minimal()
  show -> DSymbol.fromString('<1.1:8:2 4 6 8,8 3 5 7,6 5 8 7:4,4>').minimal()

  puts ""
  show -> DSymbol.fromString('<1.1:4:2 4,4 3,4 3:2,5 5>').isSpherical2D()
  show (-> DSymbol.fromString('<1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 10>')
    .orbifoldSymbol2D()), false
  show -> DSymbol.fromString('<1.1:3 3:1 2 3,1 2 3,1 3,2 3:3 3 4,4 4,3>')
    .isLocallyEuclidean3D()

if module? and not module.parent
  args = seq.map(process.argv[2..], parseInt)?.into []
  test args...

# -- End of test code --
