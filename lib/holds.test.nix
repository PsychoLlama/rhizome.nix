{ lib, ... }:

let
  inherit (import ./holds.nix { inherit lib; }) one many as;

  entry = from: value: { inherit from value; };

  failure = msg: {
    type = "ThrownError";
    inherit msg;
  };
in

{
  testListKeepsValuesInOrder = {
    expr = as.list [
      (entry "a" 1)
      (entry "b" 2)
    ];

    expected = [
      1
      2
    ];
  };

  testEntriesKeepsProvenance = {
    expr = as.entries [ (entry "a" 1) ];
    expected = [ (entry "a" 1) ];
  };

  testUniqueDropsDuplicates = {
    expr = as.unique [
      (entry "a" 1)
      (entry "b" 1)
      (entry "c" 2)
    ];

    expected = [
      1
      2
    ];
  };

  # What a fact holds is plain data, so a tool can read it.
  testOneIsData = {
    expr = {
      inherit (one) count default;
      fallback = { inherit (one.with-default 3) count default; };
    };

    expected = {
      count = "one";
      default = null;
      fallback = {
        count = "one";
        default.value = 3;
      };
    };
  };

  testManyNamesHowItIsRead = {
    expr = [
      (many as.list).as
      (many as.attrs).as
      (many (entries: entries)).as
    ];

    expected = [
      "list"
      "attrs"
      null
    ];
  };

  testManyTakesAFunction = {
    expr = many "list";
    expectedError = failure "`many` takes a function of the entries stated, such as `as.list`";
  };

  testAttrsRecursiveUnitesNestedAttrs = {
    expr = as.attrs [
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
    expr = as.attrs [ ];
    expected = { };
  };

  testAttrsRecursiveAllowsAgreement = {
    expr = as.attrs [
      (entry "a" { core.pager = "delta"; })
      (entry "b" { core.pager = "delta"; })
    ];

    expected.core.pager = "delta";
  };

  testAttrsRecursiveNamesBothEmitters = {
    expr = as.attrs [
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
      expr = as.attrs [
        (entry "a" { tool = package "one"; })
        (entry "b" { tool = package "two"; })
      ];

      expectedError = failure "`tool` is set by both a and b";
    };
}
