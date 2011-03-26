if typeof(require) != 'undefined'
  require.paths.unshift('#{__dirname}/../lib')
  { DSymbol }  = require 'dsymbol'
  { Sequence } = require 'sequence'

describe "A dsymbol made from the string <1.1:3:1 2 3,2 3,1 3:8 4,3>", ->
  ds = DSymbol.fromString "<1.1:3:1 2 3,2 3,1 3:8 4,3>"
  elms = ds.elements().toSeq()

  it "should print as <1.1:3 2:1 2 3,2 3,1 3:8 4,3>", ->
    expect(ds.toString()).toEqual "<1.1:3 2:1 2 3,2 3,1 3:8 4,3>"

  it "should have dimension 2", ->
    expect(ds.dimension()).toBe 2

  it "should have size 3", ->
    expect(ds.size()).toBe 3

  it "should have the indices 0 to 2", ->
    expect(ds.indices().toSeq().into []).toEqual [0,1,2]

  it "should have the elements 1 to 3", ->
    expect(elms.into []).toEqual [1,2,3]

  it "should have the gluings 1<->1, 2<->2, 3<->3 for index 0", ->
    expect(elms.map(ds.s(0)).into []).toEqual [1,2,3]

  it "should have the gluings 1<->2, 2<->1, 3<->3 for index 1", ->
    expect(elms.map(ds.s(1)).into []).toEqual [2,1,3]

  it "should have the gluings 1<->1, 2<->3, 3<->2 for index 2", ->
    expect(elms.map(ds.s(2)).into []).toEqual [1,3,2]

  it "should have the degrees 1->8, 2->8, 3->4 for the index pair 0, 1", ->
    expect(elms.map(ds.m(0,1)).into []).toEqual [8,8,4]

  it "should have the degrees 1->3, 2->3, 3->3 for the index pair 1, 2", ->
    expect(elms.map(ds.m(1,2)).into []).toEqual [3,3,3]

  it "should have the degrees 1->2, 2->2, 3->2 for the index pair 0, 2", ->
    expect(elms.map(ds.m(0,2)).into []).toEqual [2,2,2]

  describe "after which the element 3 is removed", ->
    ds1 = ds.withoutElements(3)
    elms1 = ds1.elements().toSeq()

    it "should print as <1.1:2 2:1 2,2,1 0:8,3>", ->
      expect(ds1.toString()).toEqual "<1.1:2 2:1 2,2,1 0:8,3>"

    it "should have dimension 2", ->
      expect(ds1.dimension()).toBe 2

    it "should have size 2", ->
      expect(ds1.size()).toBe 2

    it "should have the indices 0 to 2", ->
      expect(ds1.indices().toSeq().into []).toEqual [0,1,2]

    it "should have the elements 1 and 2", ->
      expect(elms1.into []).toEqual [1,2]

    it "should have the gluings 1<->1, 2<->2 for index 0", ->
      expect(elms1.map(ds1.s(0)).into []).toEqual [1,2]

    it "should have the gluings 1<->2, 2<->1 for index 1", ->
      expect(elms1.map(ds1.s(1)).into []).toEqual [2,1]

    it "should have only the gluing 1<->1 for index 2", ->
      expect(elms1.map(ds1.s(2)).into []).toEqual [1,undefined]

    it "should have the degrees 1->8, 2->8 for the index pair 0, 1", ->
      expect(elms1.map(ds1.m(0,1)).into []).toEqual [8,8]

    it "should have the degrees 1->3, 2->3 for the index pair 1, 2", ->
      expect(elms1.map(ds1.m(1,2)).into []).toEqual [3,3]

    it "should have the degrees 1->2, 2->2 for the index pair 0, 2", ->
      expect(elms1.map(ds1.m(0,2)).into []).toEqual [2,2]

  describe "after which the element 2 is removed", ->
    ds1 = ds.withoutElements(2)
    elms1 = ds1.elements().toSeq()

    it "should print as <1.1:3 2:1 0 3,0 0 3,1 0 0:8 0 4,3 0 3>", ->
      expect(ds1.toString()).toEqual "<1.1:3 2:1 0 3,0 0 3,1 0 0:8 0 4,3 0 3>"

    it "should have dimension 2", ->
      expect(ds1.dimension()).toBe 2

    it "should have size 2", ->
      expect(ds1.size()).toBe 2

    it "should have the indices 0 to 2", ->
      expect(ds1.indices().toSeq().into []).toEqual [0,1,2]

    it "should have the elements 1 and 3", ->
      expect(elms1.into []).toEqual [1,3]

    it "should have the gluings 1<->1, 3<->3 for index 0", ->
      expect(elms1.map(ds1.s(0)).into []).toEqual [1,3]

    it "should have the gluing 3<->3 for index 1", ->
      expect(elms1.map((D) -> [D, ds1.s(1)(D)]).into []).
        toEqual [[1,undefined], [3,3]]

    it "should have only the gluing 1<->1 for index 2", ->
      expect(elms1.map(ds1.s(2)).into []).toEqual [1, undefined]

    it "should have the degrees 1->8, 3->4 for the index pair 0, 1", ->
      expect(elms1.map(ds1.m(0,1)).into []).toEqual [8,4]

    it "should have the degrees 1->3, 3->3 for the index pair 1, 2", ->
      expect(elms1.map(ds1.m(1,2)).into []).toEqual [3,3]

    it "should have the degrees 1->2, 3->2 for the index pair 0, 2", ->
      expect(elms1.map(ds1.m(0,2)).into []).toEqual [2,2]

  describe "which is renumbered using the function (D) -> (D * 2) % 3 + 1", ->
    ds1 = ds.renumbered (D) -> (D * 2) % 3 + 1

    it "should print as <1.1:3 2:1 2 3,1 3,2 3:4 8,3>", ->
      expect(ds1.toString()).toEqual "<1.1:3 2:1 2 3,1 3,2 3:4 8,3>"

    it "should have the indices 0 to 2", ->
      expect(ds1.indices().toSeq().into []).toEqual [0,1,2]

    it "should have the elements 1 to 3", ->
      expect(ds1.elements().toSeq().into []).toEqual [1,2,3]

  describe "which is concatenated with itself", ->
    ds1 = ds.concat(ds)

    it "should print as <1.1:6 2:1 2 3 4 5 6,2 3 5 6,1 3 4 6:8 4 8 4,3 3>", ->
      expect(ds1.toString()).
        toEqual "<1.1:6 2:1 2 3 4 5 6,2 3 5 6,1 3 4 6:8 4 8 4,3 3>"

    it "should have the indices 0 to 2", ->
      expect(ds1.indices().toSeq().into []).toEqual [0,1,2]

    it "should have the elements 1 to 6", ->
      expect(ds1.elements().toSeq().into []).toEqual [1,2,3,4,5,6]

  describe "which is collapsed with connector index 0 and removed element 3", ->
    ds1 = ds.collapsed 0, 3

    it "should print as <1.1:2 2:1 2,2,1 2:8,2>", ->
      expect(ds1.toString()).toEqual "<1.1:2 2:1 2,2,1 2:8,2>"

  describe "which is collapsed after undefining an m-value", ->
    ds1 = ds.withoutDegrees(1)(1).collapsed 0, 3

    it "should print as <1.1:2 2:1 2,2,1 2:8,0>", ->
      expect(ds1.toString()).toEqual "<1.1:2 2:1 2,2,1 2:8,0>"

  it "should not allow an invalid collapse", ->
    expect(-> ds.collapsed 1, 1, 3).
      toThrow "set of removed elements must be invariant under s(1)"

  describe "traversed with the default indices and seeds", ->
    t = ds.traversal()

    it "should have all the edges in the proper order", ->
      expect(t.into []).toEqual [[1],[1,0],[2,1],[2,0],[1,2],[3,2],[3,0],[3,1]]

  describe "traversed with 1 as the seed, using all indices", ->
    t = ds.traversal ds.indices().toSeq(), new Sequence [1]

    it "should have all the edges in the proper order", ->
      expect(t.into []).toEqual [[1],[1,0],[2,1],[2,0],[1,2],[3,2],[3,0],[3,1]]

  describe "traversed with 2 as the seed, using only the first two indices", ->
    t = ds.traversal ds.indices().toSeq().take(2), new Sequence [2]

    it "should have the elements [2], [2,0], [1,1], [1,0]", ->
      expect(t.into []).toEqual [[2], [2,0], [1,1], [1,0]]

  describe "traversed seed 1 and 3, using indices 0 and 2", ->
    t = ds.traversal new Sequence([0, 2]), new Sequence [1, 3]

    it "should have the elements [1], [1,0], [1,2], [3], [3,0], [2,2], [2,0]", ->
      expect(t.into []).toEqual [[1], [1,0], [1,2], [3], [3,0], [2,2], [2,0]]
