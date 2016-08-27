#! /usr/bin/env bats
#
# For now, this a placeholder so the './go test' command will recurse into the
# 'env' directory.
#
# We have to have at least one test case here because of this block from
# bats/libexec/bats-exec-suite:
#
#   count=0
#   for filename in "$@"; do
#     let count+="$(bats-exec-test -c "$filename")"
#   done
#
# Per the bash man page:
#
#   If the last arg evaluates to 0, let returns 1; 0 is returned otherwise.
#
# Since bats runs with the errexit option, any .bats file without any actual
# test cases will cause bats to fail with no output.

@test "env: placeholder for recursion into env directory" {
  :
}
