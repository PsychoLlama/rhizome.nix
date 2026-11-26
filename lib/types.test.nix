{ rhizome, ... }:

let
  t = rhizome.types;

  check = type: value: (t.from type).check value;

  failure = msg: {
    type = "ThrownError";
    inherit msg;
  };
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
      (check t.null null)
      (check (t.either t.str t.null) 1)
    ];

    expected = [
      true
      false
      true
      true
      true
      true
      true
      false
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

  # A record names the field at fault, however deep.
  testRecordErrorsNameAWrongField = {
    expr = t.validate "here" (t.from { point.x = t.int; }) { point.x = "one"; };
    expectedError = failure "rhizome: here: point: x: expected int, got a string";
  };

  testRecordErrorsNameAnUnknownField = {
    expr = t.validate "here" (t.from { x = t.int; }) {
      x = 1;
      y = 2;
    };
    expectedError = failure "rhizome: here: unknown field `y`; expected one of: x";
  };

  testRecordErrorsNameAMissingField = {
    expr = t.validate "here" (t.from {
      x = t.int;
      y = t.default t.int 0;
    }) { };
    expectedError = failure "rhizome: here: missing field `x`";
  };
}
