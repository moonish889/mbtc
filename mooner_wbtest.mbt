// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "lexer produces correct tokens for hello" {
  let input = "fn main { println(\"hello\") }"
  let tokens = tokenize(input)

  // Check we have the expected token types
  assert_true(tokens[0] is Token::Fn)
  assert_true(tokens[1] is Token::Ident(_))
}

///|
test "lexer handles integers" {
  let tokens = tokenize("let x = 42")
  assert_true(tokens[1] is Token::Ident("x"))
  assert_true(tokens[3] is Token::Int(42))
}

///|
test "lexer handles floats" {
  let tokens = tokenize("let x = 3.14")
  assert_true(tokens[3] is Token::Float(_))
}

///|
test "lexer handles strings" {
  let tokens = tokenize("\"hello world\"")
  match tokens[0] {
    Token::String(s) => assert_eq(s, "hello world")
    _ => assert_true(false)
  }
}

///|
test "lexer handles keywords" {
  let keywords = ["fn", "let", "if", "else", "while", "for", "match", "return"]
  let code = keywords.join(" ")
  let tokens = tokenize(code)

  assert_true(tokens[0] is Token::Fn)
  assert_true(tokens[1] is Token::Let)
  assert_true(tokens[2] is Token::If)
  assert_true(tokens[3] is Token::Else)
}

///|
test "parser produces func AST" {
  let tokens = tokenize("fn main { 1 }")
  let ast = parse(tokens)

  assert_true(ast is AST::Func(_, _, _, _))
}

///|
test "parser handles let binding" {
  let tokens = tokenize("let x = 1")
  let ast = parse(tokens)

  match ast {
    AST::LetBind(name, _, _, _) => assert_eq(name, "x")
    _ => assert_true(false)
  }
}

///|
test "parser handles arithmetic" {
  let tokens = tokenize("1 + 2")
  let ast = parse(tokens)

  match ast {
    AST::Binary("+", _, _) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "parser handles function call" {
  let tokens = tokenize("println(1)")
  let ast = parse(tokens)

  match ast {
    AST::CallExpr(AST::Ident("println"), args) => assert_eq(args.length(), 1)
    _ => assert_true(false)
  }
}

///|
test "parser handles if expression" {
  let tokens = tokenize("if true { 1 } else { 2 }")
  let ast = parse(tokens)

  match ast {
    AST::IfExpr(_, _, _) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "parser handles array literal" {
  let tokens = tokenize("[1, 2, 3]")
  let ast = parse(tokens)

  match ast {
    AST::ArrayLit(arr) => assert_eq(arr.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "parser handles tuple literal" {
  let tokens = tokenize("(1, 2)")
  let ast = parse(tokens)

  match ast {
    AST::Tuple(arr) => assert_eq(arr.length(), 2)
    _ => assert_true(false)
  }
}
