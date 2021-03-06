if typeof(require) != 'undefined'
  require.paths.unshift('#{__dirname}/../lib')
  { DSymbol, Subsymbol } = require 'dsymbol'
  { seq }                = require 'sequence'


describe "A DSymbol", ->
  describe "A made from the string <1.1:3:1 2 3,2 3,1 3:8 4,3>", ->
    ds = DSymbol.fromString "<1.1:3:1 2 3,2 3,1 3:8 4,3>"
    elms = ds.elements()

    it "should print as <1.1:3 2:1 2 3,2 3,1 3:8 4,3>", ->
      expect(ds.toString()).toEqual "<1.1:3 2:1 2 3,2 3,1 3:8 4,3>"

    it "should have dimension 2", ->
      expect(ds.dimension()).toBe 2

    it "should have size 3", ->
      expect(ds.size()).toBe 3

    it "should have the indices 0 to 2", ->
      expect(ds.indices().into []).toEqual [0,1,2]

    it "should have the elements 1 to 3", ->
      expect(elms.into []).toEqual [1,2,3]

    it "should respond true if asked whether 1 is an element", ->
      expect(ds.hasElement 1).toBe true

    it "should respond false if asked whether 4 is an element", ->
      expect(ds.hasElement 4).toBe false

    it "should respond true if asked whether 0 is an index", ->
      expect(ds.hasIndex 0).toBe true

    it "should respond false if asked whether 'a' is an index", ->
      expect(ds.hasIndex 'a').toBe false

    it "should respond false if asked whether 3 is an index", ->
      expect(ds.hasIndex 3).toBe false

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

    it "should be complete", ->
      expect(ds.isComplete()).toBe true

    it "should be connected", ->
      expect(ds.isConnected()).toBe true

    it "should have the orbits 1,2 and 3 under indices 0 and 1", ->
      expect(ds.orbits(0,1).map((o) -> o.into []).into []).toEqual [[1,2],[3]]

    it "should have the orbit 1,2,3 under the full index set", ->
      expect(ds.orbits().map((o) -> o.into []).into []).toEqual [[1,2,3]]

    it "should have the partial orientation 1 -> 1, 2 -> -1, 3 -> 1", ->
      ori = ds.partialOrientation()
      expect(ds.elements().map((D) -> [D, ori.get(D)]).into []).
        toEqual [[1,1], [2,-1], [3,1]]

    it "should not be loopless", ->
      expect(ds.isLoopless()).toBe false

    it "should have a loopless 1 orbit at 1", ->
      expect(ds.orbitIsLoopless([1],[1])).toBe true

    it "should not be oriented", ->
      expect(ds.isOriented()).toBe false

    it "should have an oriented 1 orbit at 1", ->
      expect(ds.orbitIsOriented([1],[1])).toBe true

    it "should be weakly oriented", ->
      expect(ds.isWeaklyOriented()).toBe true

    it "should have a weakly oriented 1 orbit at 1", ->
      expect(ds.isWeaklyOriented([1],[1])).toBe true

    it "should have the type 8, 2, 3 for the element 1", ->
      expect(ds.type(1).into []).toEqual [8,2,3]

    it "should have the type 8, 2, 3 for the element 2", ->
      expect(ds.type(2).into []).toEqual [8,2,3]

    it "should have the type 4, 2, 3 for the element 3", ->
      expect(ds.type(3).into []).toEqual [4,2,3]

    it "should be minimal", ->
      expect(ds.isMinimal()).toBe true

    it "should be identical to its minimal image", ->
      expect(ds.minimal()).toBe ds

    it "should have curvature zero", ->
      expect(ds.curvature2D().toString()).toEqual '0'

    it "should not be spherical", ->
      expect(ds.isSpherical2D()).toBe false

    it "should have the orbifold symbol *244", ->
      expect(ds.orbifoldSymbol2D()).toEqual '*244'

    it "should have negative curvature if one m-value is increased", ->
      expect(ds.withDegrees(0,1)([3,6]).curvature2D().toString()).toEqual '-1/12'

    it "should have positive curvature if one m-value is decreased", ->
      expect(ds.withDegrees(0,1)([3,3]).curvature2D().toString()).toEqual '1/12'

    it "should be equal to itself flattened", ->
      expect(ds.flat().toString()).toEqual ds.toString()

    it "should have the right list of elements when flattened", ->
      expect(ds.flat().elements().into []).toEqual [1,2,3]

    it "should have the correct oriented cover", ->
      expect(ds.orientedCover().toString()).
        toEqual "<1.1:6 2:4 5 6,2 6 5,4 3 6:8 4,3>"

    it "should have an oriented cover that's oriented", ->
      expect(ds.orientedCover().isOriented()).toBe true

    it "should be the minimal image of its oriented cover", ->
      expect(ds.orientedCover().minimal().toString()).toEqual ds.toString()

    describe "after which the element 3 is removed", ->
      ds1 = ds.withoutElements(3)
      elms1 = ds1.elements()

      it "should print as <1.1:2 2:1 2,2,1 0:8,3>", ->
        expect(ds1.toString()).toEqual "<1.1:2 2:1 2,2,1 0:8,3>"

      it "should have dimension 2", ->
        expect(ds1.dimension()).toBe 2

      it "should have size 2", ->
        expect(ds1.size()).toBe 2

      it "should have the indices 0 to 2", ->
        expect(ds1.indices().into []).toEqual [0,1,2]

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

      it "should not be complete", ->
        expect(ds1.isComplete()).toBe false

      it "should be connected", ->
        expect(ds1.isConnected()).toBe true


    describe "after which the element 2 is removed", ->
      ds1 = ds.withoutElements(2)
      elms1 = ds1.elements()

      it "should print as <1.1:3 2:1 0 3,0 0 3,1 0 0:8 0 4,3 0 3>", ->
        expect(ds1.toString()).toEqual "<1.1:3 2:1 0 3,0 0 3,1 0 0:8 0 4,3 0 3>"

      it "should have dimension 2", ->
        expect(ds1.dimension()).toBe 2

      it "should have size 2", ->
        expect(ds1.size()).toBe 2

      it "should have the indices 0 to 2", ->
        expect(ds1.indices().into []).toEqual [0,1,2]

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

      it "should not be complete", ->
        expect(ds1.isComplete()).toBe false

      it "should not be connected", ->
        expect(ds1.isConnected()).toBe false

      it "should print as <1.1:2 2:1 2,0 2,1 0:8 4,3 3> when flattened", ->
        expect(ds1.flat().toString()).
          toEqual "<1.1:2 2:1 2,0 2,1 0:8 4,3 3>"

    describe "which is renumbered using the function (D) -> (D * 2) % 3 + 1", ->
      ds1 = ds.renumbered (D) -> (D * 2) % 3 + 1

      it "should print as <1.1:3 2:1 2 3,1 3,2 3:4 8,3>", ->
        expect(ds1.toString()).toEqual "<1.1:3 2:1 2 3,1 3,2 3:4 8,3>"

      it "should have the indices 0 to 2", ->
        expect(ds1.indices().into []).toEqual [0,1,2]

      it "should have the elements 1 to 3", ->
        expect(ds1.elements().into []).toEqual [1,2,3]

    describe "which is concatenated with itself", ->
      ds1 = ds.concat(ds)

      it "should print as <1.1:6 2:1 2 3 4 5 6,2 3 5 6,1 3 4 6:8 4 8 4,3 3>", ->
        expect(ds1.toString()).
          toEqual "<1.1:6 2:1 2 3 4 5 6,2 3 5 6,1 3 4 6:8 4 8 4,3 3>"

      it "should have the indices 0 to 2", ->
        expect(ds1.indices().into []).toEqual [0,1,2]

      it "should have the elements 1 to 6", ->
        expect(ds1.elements().into []).toEqual [1,2,3,4,5,6]

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
        toThrow "removed set must be invariant under s(1)"

    describe "traversed with the default indices and seeds", ->
      t = ds.traversal()

      it "should have all the edges in the proper order", ->
        expect(t.into []).toEqual [[1],[1,0],[2,1],[2,0],[1,2],[3,2],[3,0],[3,1]]

    describe "traversed with 1 as the seed, using all indices", ->
      t = ds.traversal ds.indices(), [1]

      it "should have all the edges in the proper order", ->
        expect(t.into []).toEqual [[1],[1,0],[2,1],[2,0],[1,2],[3,2],[3,0],[3,1]]

    describe "traversed with 2 as the seed, using only the first two indices", ->
      t = ds.traversal seq.take(ds.indices(), 2), [2]

      it "should have the elements [2], [2,0], [1,1], [1,0]", ->
        expect(t.into []).toEqual [[2], [2,0], [1,1], [1,0]]

    describe "traversed seed 1 and 3, using indices 0 and 2", ->
      t = ds.traversal [0, 2], [1, 3]

      it "should have the elements [1], [1,0], [1,2], [3], [3,0], [2,2], [2,0]", ->
        expect(t.into []).toEqual [[1], [1,0], [1,2], [3], [3,0], [2,2], [2,0]]

    describe "of which the 0,1-subsymbol at element 1 is taken", ->
      sub = new Subsymbol(ds, [0,1], 1)

      it "should print as <1.1:2 1:1 2,2:8> after flattening", ->
        expect(sub.flat().toString()).toEqual "<1.1:2 1:1 2,2:8>"

      it "should have size 2", ->
        expect(sub.size()).toBe 2

      it "should have the elements 1 and 2", ->
        expect(sub.elements().into []).toEqual [1,2]

      it "should have the element 2", ->
        expect(sub.hasElement(2)).toBe true

      it "should not have the element 3", ->
        expect(sub.hasElement(3)).toBe false

      it "should have dimension 1", ->
        expect(sub.dimension()).toBe 1

      it "should have the indices 0 and 1", ->
        expect(sub.indices().into []).toEqual [0,1]

      it "should have the index 1", ->
        expect(sub.hasIndex(1)).toBe true

      it "should not have the index 2", ->
        expect(sub.hasIndex(2)).toBe false

      it "should fulfill s(1)(1) = 2", ->
        expect(sub.s(1)(1)).toBe 2

      it "should not define s(1)(3)", ->
        expect(sub.s(1)(3)).toBe undefined

      it "should not define s(2)(1)", ->
        expect(sub.s(2)(1)).toBe undefined

      it "should fulfill m(0,1)(1) = 8", ->
        expect(sub.m(0,1)(1)).toBe 8

      it "should fulfill m(0)(1) = 1", ->
        expect(sub.m(0)(1)).toBe 1

      it "should not define m(0,1)(3)", ->
        expect(sub.m(0,1)(3)).toBe undefined

      it "should not define m(0,2)(1)", ->
        expect(sub.m(0,2)(1)).toBe undefined


  describe "of a square tiling with translational symmetry", ->
    ds = DSymbol.fromString "<1.1:8:2 4 6 8,8 3 5 7,6 5 8 7:4,4>"

    it "should have the expected partial orientation", ->
      ori = ds.partialOrientation()
      expect(ds.elements().map((D) -> [D, ori.get(D)]).into []).
        toEqual [[1,1], [2,-1], [3,1], [4,-1], [5,1], [6,-1], [7,1], [8,-1]]

    it "should be loopless", ->
      expect(ds.isLoopless()).toBe true

    it "should have a loopless 0,1 orbit", ->
      expect(ds.isLoopless([0,1],[1])).toBe true

    it "should be oriented", ->
      expect(ds.isOriented()).toBe true

    it "should have a oriented 0,1 orbit", ->
      expect(ds.isOriented([0,1],[1])).toBe true

    it "should be weakly oriented", ->
      expect(ds.isWeaklyOriented()).toBe true

    it "should have a weakly oriented 0,1 orbit", ->
      expect(ds.isWeaklyOriented([0,1],[1])).toBe true

    it "should be equal to itself after renumbering", ->
      expect(ds.equals ds.renumbered (D) -> (D + 3) % 8 + 1).toBe true

    it "should be in canonical form", ->
      expect(ds.canonical().toString()).toEqual ds.toString()

    it "should not be minimal", ->
      expect(ds.isMinimal()).toBe false

    it "should have a minimal image with one element", ->
      expect(ds.minimal().equals DSymbol.fromString "<1.1:1:1,1,1:4,4>").toBe true

    it "should be equal to itself flattened", ->
      expect(ds.flat().toString()).toEqual ds.toString()

    it "should be identical to its oriented cover", ->
      expect(ds.orientedCover().toString()).toEqual ds.toString()

    it "should have an oriented cover that's oriented", ->
      expect(ds.orientedCover().isOriented()).toBe true

    it "should not be spherical", ->
      expect(ds.isSpherical2D()).toBe false

    it "should have the orbifold symbol o", ->
      expect(ds.orbifoldSymbol2D()).toEqual 'o'

    describe "traversed with the default indices and seeds", ->
      t = ds.traversal()

      it "should have all the edges in the proper order", ->
        expect(t.into []).toEqual [[1],[2,0],[3,1],[4,0],[5,1],[6,0],[7,1],[8,0],
          [1,1],[6,2],[5,2],[8,2],[7,2]]

    describe "traversed with reversed indices and default seeds", ->
      t = ds.traversal([2,1,0])

      it "should have all the edges in the proper order", ->
        expect(t.into []).toEqual [[1],[6,2],[7,1],[4,2],[5,1],[2,2],[3,1],[8,2],
          [1,1],[2,0],[5,0],[8,0],[3,0]]

  describe "of a square tiling with two glide reflections", ->
    ds = DSymbol.fromString "<1.1:8:2 4 6 8,8 3 5 7,3 4 7 8:4,4>"

    it "should have curvature zero", ->
      expect(ds.curvature2D().toString()).toBe '0'

    it "should have the orbifold symbol xx", ->
      expect(ds.orbifoldSymbol2D()).toEqual 'xx'

  describe "made from the string <1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 8>", ->
    ds = DSymbol.fromString "<1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 8>"

    it "should be spherical", ->
      expect(ds.isSpherical2D()).toBe true

    it "should have a fundamental group of size 48", ->
      expect(ds.sphericalGroupSize2D()).toBe 48

    it "should have the orbifold symbol *234", ->
      expect(ds.orbifoldSymbol2D()).toEqual '*234'

  describe "made from the string <1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 10>", ->
    ds = DSymbol.fromString "<1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 10>"

    it "should be spherical", ->
      expect(ds.isSpherical2D()).toBe true

    it "should have a fundamental group of size 120", ->
      expect(ds.sphericalGroupSize2D()).toBe 120

    it "should have the orbifold symbol *235", ->
      expect(ds.orbifoldSymbol2D()).toEqual '*235'

  describe "made from the string <1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 12>", ->
    ds = DSymbol.fromString "<1.1:6:2 4 6,6 3 5,1 2 3 4 5 6:3,4 6 12>"

    it "should not be spherical", ->
      expect(ds.isSpherical2D()).toBe false

    it "should have the orbifold symbol *236", ->
      expect(ds.orbifoldSymbol2D()).toEqual '*236'

  describe "made from the string <1.1:4:2 4,4 3,4 3:2,5 5>", ->
    ds = DSymbol.fromString "<1.1:4:2 4,4 3,4 3:2,5 5>"

    it "should be spherical", ->
      expect(ds.isSpherical2D()).toBe true

    it "should have the orbifold symbol 55", ->
      expect(ds.orbifoldSymbol2D()).toEqual '55'

    it "should have a fundamental group of size 5", ->
      expect(ds.sphericalGroupSize2D()).toBe 5

    describe "after which m(1,2)(1) is changed to 4", ->
      ds1 = ds.withDegrees(1,2)([1,4])

      it "should not be spherical", ->
        expect(ds1.isSpherical2D()).toBe false

      it "should have the orbifold symbol 45", ->
        expect(ds1.orbifoldSymbol2D()).toEqual '45'

    describe "after which m(1,2)(1) is changed to 1", ->
      ds1 = ds.withDegrees(1,2)([1,1])

      it "should not be spherical", ->
        expect(ds1.isSpherical2D()).toBe false

      it "should have the orbifold symbol 5", ->
        expect(ds1.orbifoldSymbol2D()).toEqual '5'

    describe "after which m(1,2)(1) and m(1,2)(2) are changed to 1", ->
      ds1 = ds.withDegrees(1,2)([1,1], [2,1])

      it "should be spherical", ->
        expect(ds1.isSpherical2D()).toBe true

      it "should have the orbifold symbol 1", ->
        expect(ds1.orbifoldSymbol2D()).toEqual '1'

  describe "made from the string <1.1:4:2 4,4 3,3 4:2,6>", ->
    ds = DSymbol.fromString "<1.1:4:2 4,4 3,3 4:2,6>"

    it "should be spherical", ->
      expect(ds.isSpherical2D()).toBe true

    it "should have the orbifold symbol 3x", ->
      expect(ds.orbifoldSymbol2D()).toEqual '3x'


  describe "made from the string <1.1:3 3:1 2 3,1 2 3,1 3,2 3:3 3 4,4 4,3>", ->
    ds = DSymbol.fromString "<1.1:3 3:1 2 3,1 2 3,1 3,2 3:3 3 4,4 4,3>"

    it "should have dimension 3", ->
      expect(ds.dimension()).toBe 3

    it "should have size 3", ->
      expect(ds.size()).toBe 3

    it "should have two 0,1,2-orbits", ->
      expect(ds.orbitFirsts(0,1,2).size()).toBe 2

    it "should be locally euclidean", ->
      expect(ds.isLocallyEuclidean3D()).toBe true
