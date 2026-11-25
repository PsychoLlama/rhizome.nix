{ rhizome, ... }:

let
  t = rhizome.types;

  check = type: value: (t.from type).check value;

  failure = msg: {
    type = "ThrownError";
    inherit msg;
  };

  point = rhizome.data "point" (input: {
    type.input = {
      x = t.int;
      y = t.default t.int 0;
    };
    type.output = {
      x = t.int;
      y = t.int;
    };
    value = input;
  });
in

{
  testPrimitives = {
    expr = [
      (check t.str "a")
      (check t.str 1)
      (check t.int 1)
      (check t.bool true)
      (check t.function (x: x))
      (check t.any null)
    ];

    expected = [
      true
      false
      true
      true
      true
      true
    ];
  };

  testContainers = {
    expr = [
      (check (t.list t.str) [ "a" ])
      (check (t.list t.str) [ 1 ])
      (check (t.attrs-of t.int) { a = 1; })
      (check (t.attrs-of t.int) { a = "1"; })
      (check (t.either t.str t.int) 1)
      (check (t.either t.str t.int) true)
    ];

    expected = [
      true
      false
      true
      false
      true
      false
    ];
  };

  # A plain attrset of types stands in for a record.
  testRecordsAreClosed = {
    expr = [
      (check { name = t.str; } { name = "a"; })
      (check { name = t.str; } { })
      (check { name = t.str; } {
        name = "a";
        extra = 1;
      })
    ];

    expected = [
      true
      false
      false
    ];
  };

  testDefaultsFillMissingFields = {
    expr = t.validate "here" (t.from {
      name = t.str;
      port = t.default t.int 80;
    }) { name = "web"; };

    expected = {
      name = "web";
      port = 80;
    };
  };

  testValidateNamesWhereAndWhat = {
    expr = t.validate "here" t.str 1;
    expectedError = failure "rhizome: here: expected str, got a int";
  };

  testDataBuildsAValueAndFillsDefaults = {
    expr = removeAttrs (point { x = 1; }) [ "__data" ];
    expected = {
      x = 1;
      y = 0;
    };
  };

  # Nominal: a record shaped like a point is not a point.
  testDataTypesAreNominal = {
    expr = [
      (point.type.output.check (point {
        x = 1;
      }))
      (point.type.output.check {
        x = 1;
        y = 0;
      })
    ];

    expected = [
      true
      false
    ];
  };

  # Strict: a built point is not a valid input to `point`.
  testDataRejectsItsOwnOutputAsInput = {
    expr = point (point {
      x = 1;
    });
    expectedError = failure "data `point`: input: expected record . x y ., got data `point`";
  };

  testDataChecksItsOutput = {
    expr =
      (rhizome.data "broken" (_: {
        type.output.x = t.int;
        value.x = "one";
      }) null).x;

    expectedError = failure "data `broken`: output: expected record";
  };

  testLibChecksInputAndOutput = {
    expr =
      (rhizome.lib "shout" (input: {
        type.input.suffix = t.str;
        type.output.apply = t.function;
        value.apply = text: "${text}${input.suffix}";
      }) { suffix = "!"; }).apply
        "hi";

    expected = "hi!";
  };
}
