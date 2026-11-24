#!/usr/bin/env bats
#
# Verifies that file-replace applies SEARCH/REPLACE blocks read from stdin to
# several places and files in one call, and that it writes nothing unless every
# block matches exactly one place.
#
# The helper stands in for the `python3 - <<'EOF'` scripts that rewrote files
# with a literal string replace, so each test also keeps what those scripts
# got wrong: a replacement that is read as an escape or a pattern, and a
# replace that silently matches nothing or too much.
#
# Usage: bats .github/testdata/file-replace.bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  helper="${repo_root}/dot_local/bin/executable_file-replace"
  sandbox="$(mktemp -d)"
  cd "${sandbox}"
}

teardown() {
  rm -rf "${sandbox}"
}

@test "a block replaces the lines it names" {
  printf 'one\ntwo\nthree\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
two
=======
TWO
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'one\nTWO\nthree')" ]
}

@test "several blocks change several places in several files in one call" {
  printf 'a1\na2\na3\n' > a.txt
  printf 'b1\nb2\n' > b.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
a1
=======
A1
>>>>>>> REPLACE

b.txt
<<<<<<< SEARCH
b2
=======
B2
>>>>>>> REPLACE

a.txt
<<<<<<< SEARCH
a3
=======
A3
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'A1\na2\nA3')" ]
  [ "$(cat b.txt)" = "$(printf 'b1\nB2')" ]
}

@test "a block sees the result of an earlier block on the same file" {
  printf 'x\ny\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
x
=======
y2
>>>>>>> REPLACE
a.txt
<<<<<<< SEARCH
y2
=======
z
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'z\ny')" ]
}

@test "two spellings of one path edit the same content" {
  printf 'x\ny\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
x
=======
y2
>>>>>>> REPLACE
./a.txt
<<<<<<< SEARCH
y2
=======
z
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'z\ny')" ]
}

@test "an empty replacement deletes the matched lines" {
  printf 'one\ntwo\nthree\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
two
=======
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'one\nthree')" ]
}

@test "several lines are matched as one run of lines" {
  printf 'a\nb\nc\nb\nd\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
b
c
=======
BC
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'a\nBC\nb\nd')" ]
}

@test "backslashes, dollar signs and backticks are written as they are" {
  printf 'old\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
old
=======
printf '%s\n' "$&" '$1' `date` \n \\
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf '%s' "printf '%s\\n' \"\$&\" '\$1' \`date\` \\n \\\\")" ]
}

@test "text that looks like a marker inside a block is kept" {
  printf 'old\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
old
=======
a ======= b
<<<<<<< SEARCH
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(cat a.txt)" = "$(printf 'a ======= b\n<<<<<<< SEARCH')" ]
}

@test "a file without a final newline keeps none" {
  printf 'one\ntwo' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
two
=======
TWO
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(od -An -c a.txt | tr -d ' \n')" = 'one\nTWO' ]
}

@test "the file keeps its mode" {
  printf 'x\n' > a.txt
  chmod 755 a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
x
=======
y
>>>>>>> REPLACE
EOF

  [ "$status" -eq 0 ]
  [ "$(stat -f %Lp a.txt 2>/dev/null || stat -c %a a.txt)" = "755" ]
}

@test "a block that matches nothing fails and writes no file" {
  printf 'a1\n' > a.txt
  printf 'b1\n' > b.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
a1
=======
A1
>>>>>>> REPLACE
b.txt
<<<<<<< SEARCH
missing
=======
x
>>>>>>> REPLACE
EOF

  [ "$status" -eq 1 ]
  [[ "$output" == *"b.txt"* ]]
  [[ "$output" == *"block 2"* ]]
  [[ "$output" == *"not found"* ]]
  [ "$(cat a.txt)" = "a1" ]
  [ "$(cat b.txt)" = "b1" ]
}

@test "a block that matches two places fails and writes no file" {
  printf 'x\ny\nx\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
x
=======
X
>>>>>>> REPLACE
EOF

  [ "$status" -eq 1 ]
  [[ "$output" == *"a.txt"* ]]
  [[ "$output" == *"2 places"* ]]
  [ "$(cat a.txt)" = "$(printf 'x\ny\nx')" ]
}

@test "a file that does not exist fails and writes no file" {
  printf 'a1\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
a1
=======
A1
>>>>>>> REPLACE
nope.txt
<<<<<<< SEARCH
x
=======
y
>>>>>>> REPLACE
EOF

  [ "$status" -eq 1 ]
  [[ "$output" == *"nope.txt"* ]]
  [ "$(cat a.txt)" = "a1" ]
}

@test "input with no block is rejected" {
  run "${helper}" <<'EOF'
just text
EOF

  [ "$status" -eq 2 ]
  [[ "$output" == *"no block"* ]]
}

@test "a block with no end marker is rejected and writes no file" {
  printf 'x\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
x
=======
y
EOF

  [ "$status" -eq 2 ]
  [[ "$output" == *"REPLACE"* ]]
  [ "$(cat a.txt)" = "x" ]
}

@test "a block with no path before it is rejected" {
  run "${helper}" <<'EOF'
<<<<<<< SEARCH
x
=======
y
>>>>>>> REPLACE
EOF

  [ "$status" -eq 2 ]
  [[ "$output" == *"path"* ]]
}

@test "a block with an empty SEARCH is rejected" {
  printf 'x\n' > a.txt

  run "${helper}" <<'EOF'
a.txt
<<<<<<< SEARCH
=======
y
>>>>>>> REPLACE
EOF

  [ "$status" -eq 2 ]
  [[ "$output" == *"empty SEARCH"* ]]
  [ "$(cat a.txt)" = "x" ]
}

@test "--help prints the block format and writes no file" {
  run "${helper}" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"<<<<<<< SEARCH"* ]]
  [[ "$output" == *"======="* ]]
  [[ "$output" == *">>>>>>> REPLACE"* ]]
}

@test "an unknown argument is rejected" {
  run "${helper}" --nope < /dev/null

  [ "$status" -eq 2 ]
  [[ "$output" == *"--nope"* ]]
}
