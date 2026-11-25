{ rhizome, ... }:

let
  inherit (rhizome) merge;

  entry = from: value: { inherit from value; };

  failure = msg: {
    type = "ThrownError";
    inherit msg;
  };
in

{
  testListKeepsValuesInOrder = {
    expr = merge.list [
      (entry "a" 1)
      (entry "b" 2)
    ];

    expected = [
      1
      2
    ];
  };

  testEntriesKeepsProvenance = {
    expr = merge.entries [ (entry "a" 1) ];
    expected = [ (entry "a" 1) ];
  };

  testUniqueDropsDuplicates = {
    expr = merge.unique [
      (entry "a" 1)
      (entry "b" 1)
      (entry "c" 2)
    ];

    expected = [
      1
      2
    ];
  };

  testOneTakesTheOnlyValue = {
    expr = merge.one [ (entry "a" 1) ];
    expected = 1;
  };

  testOneRejectsNone = {
    expr = merge.one [ ];
    expectedError = failure "merge.one: expected exactly one value, got 0";
  };

  testOneRejectsSeveralAndNamesThem = {
    expr = merge.one [
      (entry "a" 1)
      (entry "b" 2)
    ];

    expectedError = failure "expected exactly one value, got 2 .a b.";
  };

  testOneOrNoneIsNullWhenEmpty = {
    expr = merge.one-or-none [ ];
    expected = null;
  };

  testAttrsRecursiveUnitesNestedAttrs = {
    expr = merge.attrs.recursive [
      (entry "a" { core.pager = "delta"; })
      (entry "b" {
        core.editor = "nvim";
        user.name = "ada";
      })
    ];

    expected = {
      core = {
        pager = "delta";
        editor = "nvim";
      };
      user.name = "ada";
    };
  };

  testAttrsRecursiveOfNothingIsEmpty = {
    expr = merge.attrs.recursive [ ];
    expected = { };
  };

  testAttrsRecursiveAllowsAgreement = {
    expr = merge.attrs.recursive [
      (entry "a" { core.pager = "delta"; })
      (entry "b" { core.pager = "delta"; })
    ];

    expected.core.pager = "delta";
  };

  testAttrsRecursiveNamesBothEmitters = {
    expr = merge.attrs.recursive [
      (entry "a" { core.pager = "delta"; })
      (entry "b" { core.pager = "less"; })
    ];

    expectedError = failure "`core.pager` is set by both a and b";
  };

  # A package is a value, not a branch to descend into.
  testAttrsRecursiveTreatsDerivationsAsLeaves =
    let
      package = name: {
        type = "derivation";
        outPath = "/nix/store/${name}";
        inherit name;
      };
    in
    {
      expr = merge.attrs.recursive [
        (entry "a" { tool = package "one"; })
        (entry "b" { tool = package "two"; })
      ];

      expectedError = failure "`tool` is set by both a and b";
    };
}
