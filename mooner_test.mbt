// Blackbox tests - E2E compilation tests
// Run via: bash run_e2e_tests.sh

// Note: Due to lack of subprocess support in MoonBit's standard library,
// E2E tests are run via a bash script that compares compiler output
// with the official MoonBit compiler.

// This file contains placeholder tests that verify the compiler API works.
// Actual E2E comparison is done via run_e2e_tests.sh

///|
test "compile_file returns ok for valid input" {
  let input_path = "examples/mbt_examples/001_hello.mbt"
  let output_path = "/tmp/mbtc_test_001.exe"

  let result = @mbtc.compile_file(input_path, output_path)
  assert_true(
    match result {
      Ok(_) => true
      Err(_) => false
    },
  )
}

///|
test "tokenize produces tokens" {
  let input = "fn main { println(1) }"
  let tokens = @mbtc.tokenize(input)
  assert_true(tokens.length() > 0)
}

///|
test "parse produces AST" {
  let input = "fn main { println(1) }"
  let tokens = @mbtc.tokenize(input)
  let ast = @mbtc.parse(tokens)
  assert_true(
    match ast {
      AST::Func(_) => true
      _ => false
    },
  )
}

///|
test "codegen produces bytes" {
  let input = "fn main { println(1) }"
  let tokens = @mbtc.tokenize(input)
  let ast = @mbtc.parse(tokens)
  let code = @mbtc.codegen(ast)
  assert_true(code.length() > 0)
}
