set indentation := "  "
set default-list

# Format the codebase.
fmt:
  treefmt

# Check formatting without applying changes.
fmt-check:
  treefmt --fail-on-change

# Run the `*.test.nix` unit tests, or only those in a specific file.
test-unit file="":
  nix-unit --quiet --flake '.#libTests{{ if file == "" { "" } else { "." + '"' + file + '"' } }}'

# Run all checks.
check:
  just fmt-check
  just test-unit
