///|
pub enum AST {
  Unit
  Int(Int)
  Float(Double)
  String(String)
  Char(Char)
  Bool(Bool)
  Ident(String)
  Block(Array[AST])
  Func(String, Array[(String, AST?)], AST?, AST)
  LetBind(String, AST?, AST, AST)
  LetTuple(Array[String], AST, AST) // names, value, body
  IfExpr(AST, AST, AST?)
  MatchExpr(AST, Array[(AST, AST)])
  WhileLoop(AST, AST)
  ForLoop(AST?, AST?, AST?, AST)
  ForInLoop(String, AST, AST) // for x in arr { body }
  ReturnExpr(AST)
  Break
  Continue
  Binary(String, AST, AST)
  Unary(String, AST)
  CallExpr(AST, Array[AST])
  IndexExpr(AST, AST)
  FieldExpr(AST, String)
  Tuple(Array[AST])
  ArrayLit(Array[AST])
  MapLit(Array[(AST, AST)]) // map[key] = value
  Assign(AST, AST)
  AssignOp(String, AST, AST)
  TypeDecl(String, Array[(String, String)])
  EnumDef(String, Array[String])
  StructLit(String, Array[(String, AST)])
  StructUpdate(AST, Array[(String, AST)])
  StringConcat(Array[AST])
  Spread(AST)
  TestBlock(String?, AST) // optional name, body
} derive(Show)

///|
pub struct Parser {
  tokens : Array[Token]
  pos : Int
}

///|
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0 }
}

///|
fn Parser::current(self : Parser) -> Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    Eof
  }
}

///|
fn Parser::_peek(self : Parser, offset : Int) -> Token {
  let idx = self.pos + offset
  if idx < self.tokens.length() {
    self.tokens[idx]
  } else {
    Eof
  }
}

///|
fn Parser::advance(self : Parser) -> Parser {
  if self.pos < self.tokens.length() - 1 {
    { ..self, pos: self.pos + 1 }
  } else {
    self
  }
}

///|
fn Parser::skip(self : Parser, n : Int) -> Parser {
  let new_pos = self.pos + n
  if new_pos < self.tokens.length() - 1 {
    { ..self, pos: new_pos }
  } else {
    { ..self, pos: self.tokens.length() - 1 }
  }
}

///|
fn self_token_eq(a : Token, b : Token) -> Bool {
  token_eq(a, b)
}

///|
fn Parser::parse_ident(self : Parser) -> (String, Parser) {
  match self.current() {
    Ident(name) => (name, self.advance())
    _ => ("", self)
  }
}

///|
fn Parser::parse_literal(self : Parser) -> (AST, Parser) {
  match self.current() {
    Unit => (Unit, self.advance())
    True => (Bool(true), self.advance())
    False => (Bool(false), self.advance())
    Int(i) => (Int(i), self.advance())
    Float(f) => (Float(f), self.advance())
    String(s) => {
      // Check if string has interpolation \{expr}
      let ast = parse_string_interpolation(s)
      (ast, self.advance())
    }
    Char(c) => (Char(c), self.advance())
    Ident(name) => (Ident(name), self.advance())
    LParen => self.parse_tuple_or_parens()
    LBracket => self.parse_array()
    Eof => (Unit, self.advance())
    RBrace => (Unit, self)
    _ => (Unit, self.advance())
  }
}

///|
fn Parser::parse_tuple_or_parens(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  if self_token_eq(p.current(), RParen) {
    (Tuple([]), p.advance())
  } else {
    let (first, p2) = p.parse_expr()
    if self_token_eq(p2.current(), RParen) {
      (first, p2.advance())
    } else if self_token_eq(p2.current(), Comma) {
      let p3 = p2.skip(1)
      let mut elems = [first]
      let mut parser = p3
      let mut done = false
      while not(done) {
        let (expr, p2) = parser.parse_expr()
        elems = elems + [expr]
        if self_token_eq(p2.current(), Comma) {
          parser = p2.skip(1)
        } else if self_token_eq(p2.current(), RParen) {
          parser = p2.advance()
          done = true
        } else {
          done = true
        }
      }
      (Tuple(elems), parser)
    } else {
      (first, p2)
    }
  }
}

///|
fn Parser::parse_array(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  if self_token_eq(p.current(), RBracket) {
    (ArrayLit([]), p.advance())
  } else {
    let (first, p2) = if self_token_eq(p.current(), DotDot) {
      let p_skip = p.skip(1)
      let (inner, p_after) = p_skip.parse_expr()
      (Spread(inner), p_after)
    } else {
      p.parse_expr()
    }
    if self_token_eq(p2.current(), RBracket) {
      (ArrayLit([first]), p2.advance())
    } else if self_token_eq(p2.current(), Comma) {
      let p3 = p2.skip(1)
      let mut elems = [first]
      let mut parser = p3
      let mut done = false
      while not(done) {
        let (expr, p2) = if self_token_eq(parser.current(), DotDot) {
          let p_skip = parser.skip(1)
          let (inner, p_after) = p_skip.parse_expr()
          (Spread(inner), p_after)
        } else {
          parser.parse_expr()
        }
        elems = elems + [expr]
        if self_token_eq(p2.current(), Comma) {
          parser = p2.skip(1)
        } else if self_token_eq(p2.current(), RBracket) {
          parser = p2.advance()
          done = true
        } else {
          done = true
        }
      }
      (ArrayLit(elems), parser)
    } else {
      (ArrayLit([first]), p2)
    }
  }
}

///|
fn Parser::parse_primary(self : Parser) -> (AST, Parser) {
  let tok = self.current()
  match tok {
    Ident(_) | Int(_) | Float(_) | String(_) | Char(_) | True | False | Unit =>
      self.parse_literal()
    LParen => self.parse_tuple_or_parens()
    LBracket => self.parse_array()
    If => self.parse_if()
    Match => self.parse_match()
    While => self.parse_while()
    For => self.parse_for()
    Let => self.parse_let()
    Fn => self.parse_function()
    Type => self.parse_type_decl()
    Struct => self.parse_type_decl()
    Enum => self.parse_enum()
    Test => self.parse_test()
    LBrace => self.parse_struct_or_block()
    Return => {
      let p = self.advance()
      let (expr, p2) = p.parse_expr()
      (ReturnExpr(expr), p2)
    }
    Break => (Break, self.advance())
    Continue => (Continue, self.advance())
    Underscore => (Ident("_".to_string()), self.advance())
    Equal => (Unit, self.advance())
    Eof => (Unit, self.advance())
    RBrace => (Unit, self)
    RParen => (Unit, self)
    Comma => (Unit, self.advance())
    Semicolon => (Unit, self.advance())
    _ => (Unit, self.advance())
  }
}

///|
fn Parser::parse_block(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let mut stmts : Array[AST] = []
  let mut parser = p
  let mut done = false
  while not(done) {
    if self_token_eq(parser.current(), RBrace) {
      parser = parser.advance()
      // Skip optional derive annotation
      if self_token_eq(parser.current(), Ident("derive")) {
        parser = parser.skip(1)
        if self_token_eq(parser.current(), LParen) {
          parser = parser.skip(1)
          while not(self_token_eq(parser.current(), RParen)) &&
                not(self_token_eq(parser.current(), Eof)) {
            parser = parser.advance()
          }
          if self_token_eq(parser.current(), RParen) {
            parser = parser.skip(1)
          }
        }
      }
      done = true
    } else if self_token_eq(parser.current(), Eof) {
      done = true
    } else {
      let (stmt, p2) = parser.parse_expr()
      stmts = stmts + [stmt]
      parser = p2
    }
  }
  (Block(stmts), parser)
}

///|
fn Parser::parse_struct_or_block(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  // Try to detect struct literal: { field: value, ... }
  // Struct literals have identifiers followed by colons
  // Blocks have expressions (not field: value pairs)
  // Map literals have string keys: { "key": value, ... }
  match p.current() {
    String(key_str) => {
      // This is a map literal: { "key": value, ... }
      let p2 = p.advance()
      if self_token_eq(p2.current(), Colon) {
        // This is a map literal: { "key": value, ... }
        let p3 = p2.skip(1)
        let (field_val, p4) = p3.parse_expr()
        let mut entries : Array[(AST, AST)] = [(String(key_str), field_val)]
        let mut parser = p4
        let mut done = false
        while not(done) {
          if self_token_eq(parser.current(), Comma) {
            let p5 = parser.skip(1)
            if self_token_eq(p5.current(), RBrace) {
              parser = p5.advance()
              done = true
            } else {
              match p5.current() {
                String(key) => {
                  let p6 = p5.advance()
                  if self_token_eq(p6.current(), Colon) {
                    let p7 = p6.skip(1)
                    let (v, p8) = p7.parse_expr()
                    entries = entries + [(String(key), v)]
                    parser = p8
                  } else {
                    // Not a map literal, fallback to block
                    return p.parse_block()
                  }
                }
                _ => parser = p5
              }
            }
          } else if self_token_eq(parser.current(), RBrace) {
            parser = parser.advance()
            done = true
          } else {
            done = true
          }
        }
        (MapLit(entries), parser)
      } else {
        // Not a map literal, parse as block
        p.parse_block()
      }
    }
    Ident(field_name) => {
      // Look ahead to check if this is field: value
      let p2 = p.advance()
      if self_token_eq(p2.current(), Colon) {
        // This is a struct literal: { field: value, ... }
        let p3 = p2.skip(1)
        let (field_val, p4) = p3.parse_expr()
        let mut fields : Array[(String, AST)] = [(field_name, field_val)]
        let mut parser = p4
        let mut done = false
        while not(done) {
          if self_token_eq(parser.current(), Comma) {
            let p5 = parser.skip(1)
            if self_token_eq(p5.current(), RBrace) {
              parser = p5.advance()
              done = true
            } else {
              match p5.current() {
                Ident(fname) => {
                  let p6 = p5.advance()
                  if self_token_eq(p6.current(), Colon) {
                    let p7 = p6.skip(1)
                    let (v, p8) = p7.parse_expr()
                    fields = fields + [(fname, v)]
                    parser = p8
                  } else {
                    // Not a struct literal, fallback to block
                    return p.parse_block()
                  }
                }
                _ => parser = p5
              }
            }
          } else if self_token_eq(parser.current(), RBrace) {
            parser = parser.advance()
            done = true
          } else {
            done = true
          }
        }
        (StructLit("", fields), parser)
      } else {
        // Not a struct literal, parse as block
        p.parse_block()
      }
    }
    DotDot => {
      // Functional update syntax: { ..point, x: 20 }
      let p2 = p.skip(1)
      let (base, p3) = p2.parse_expr()
      let mut fields : Array[(String, AST)] = []
      let mut parser = p3
      if self_token_eq(parser.current(), Comma) {
        parser = parser.skip(1)
        let mut done = false
        while not(done) {
          if self_token_eq(parser.current(), RBrace) {
            parser = parser.advance()
            done = true
          } else {
            match parser.current() {
              Token::Ident(fname) => {
                let p4 = parser.advance()
                if self_token_eq(p4.current(), Colon) {
                  let p5 = p4.skip(1)
                  let (v, p6) = p5.parse_expr()
                  fields = fields + [(fname, v)]
                  if self_token_eq(p6.current(), Comma) {
                    parser = p6.skip(1)
                  } else {
                    parser = p6
                  }
                } else {
                  parser = p4
                }
              }
              _ => parser = parser.advance()
            }
          }
        }
      } else if self_token_eq(parser.current(), RBrace) {
        parser = parser.advance()
      }
      (StructUpdate(base, fields), parser)
    }
    RBrace => {
      // Empty struct literal or empty block
      let p2 = p.advance()
      (StructLit("", []), p2)
    }
    _ =>
      // Not a struct literal, parse as block
      p.parse_block()
  }
}

///|
fn Parser::parse_if(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let (cond, p2) = p.parse_expr()
  let (then, p3) = p2.parse_block_or_expr()
  if self_token_eq(p3.current(), Else) {
    let p4 = p3.skip(1)
    if self_token_eq(p4.current(), If) {
      p4.parse_if()
    } else {
      let (else_branch, p5) = p4.parse_block_or_expr()
      (IfExpr(cond, then, Some(else_branch)), p5)
    }
  } else {
    (IfExpr(cond, then, None), p3)
  }
}

///|
fn Parser::parse_match(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let (expr, p2) = p.parse_expr()
  if self_token_eq(p2.current(), LBrace) {
    let p3 = p2.skip(1)
    let mut cases : Array[(AST, AST)] = []
    let mut parser = p3
    let mut done = false
    while not(done) {
      if self_token_eq(parser.current(), RBrace) {
        parser = parser.advance()
        done = true
      } else if self_token_eq(parser.current(), Case) {
        let p2 = parser.skip(1)
        let (pattern, p3) = p2.parse_expr()
        if self_token_eq(p3.current(), Arrow) {
          let p4 = p3.skip(1)
          let (body, p5) = p4.parse_block_or_expr()
          cases = cases + [(pattern, body)]
          parser = p5
        } else {
          parser = p3
        }
      } else if self_token_eq(parser.current(), Underscore) {
        let (pattern, p2) = parser.parse_expr()
        if self_token_eq(p2.current(), Arrow) {
          let p3 = p2.skip(1)
          let (body, p4) = p3.parse_block_or_expr()
          cases = cases + [(pattern, body)]
          parser = p4
        } else {
          parser = p2
        }
      } else {
        match parser.current() {
          Token::Ident(_) | Token::Int(_) => {
            let (pattern, p2) = parser.parse_expr()
            if self_token_eq(p2.current(), Arrow) {
              let p3 = p2.skip(1)
              let (body, p4) = p3.parse_block_or_expr()
              cases = cases + [(pattern, body)]
              parser = p4
            } else {
              parser = p2
            }
          }
          _ => parser = parser.advance()
        }
      }
    }
    (MatchExpr(expr, cases), parser)
  } else {
    (MatchExpr(expr, []), p2)
  }
}

///|
fn Parser::parse_while(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let (cond, p2) = p.parse_expr()
  let (body, p3) = p2.parse_block_or_expr()
  (WhileLoop(cond, body), p3)
}

///|
fn Parser::parse_for(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)

  // Check for "for-in" syntax: for x in arr { ... }
  // This is when we have: for identifier in expression
  // We need to peek without consuming
  match p.current() {
    Ident(name) => {
      // Look ahead to see if next token is 'in'
      let p_ahead = p.advance()
      if self_token_eq(p_ahead.current(), In) {
        let p3 = p_ahead.skip(1)
        let (iter_expr, p4) = p3.parse_expr()
        let (body, p5) = p4.parse_block_or_expr()
        return (ForInLoop(name, iter_expr, body), p5)
      }
      // Not for-in, continue with C-style
    }
    _ => ()
  }

  // Otherwise, parse as C-style for loop: for (init; cond; step) { body }
  // Check if there's a '(' or if it's a simple identifier (for i = ...)
  let has_paren = self_token_eq(p.current(), LParen)
  let p_after_paren = if has_paren { p.skip(1) } else { p }

  // Parse init (can be let-binding, assignment, or empty)
  let (init, p2) = if self_token_eq(p_after_paren.current(), Semicolon) {
    (None, p_after_paren.skip(1))
  } else if self_token_eq(p_after_paren.current(), Let) {
    // let binding
    let (expr, p4) = p_after_paren.parse_let()
    if self_token_eq(p4.current(), Semicolon) {
      (Some(expr), p4.skip(1))
    } else {
      (Some(expr), p4)
    }
  } else {
    // Could be an identifier = value (for loop variable) or other expression
    let (expr, p4) = p_after_paren.parse_expr()
    // Check if this is an assignment to an undeclared variable (for loop init)
    let init_expr = match expr {
      Assign(Ident(name), value) =>
        // Convert to LetBind for the loop scope
        // We'll use Unit as the body since it's just initialization
        LetBind(name, None, value, Unit)
      _ => expr
    }
    if self_token_eq(p4.current(), Semicolon) {
      (Some(init_expr), p4.skip(1))
    } else {
      (Some(init_expr), p4)
    }
  }

  // Parse condition
  let (cond, p3) = if self_token_eq(p2.current(), Semicolon) {
    (None, p2.skip(1))
  } else {
    let (expr, p4) = p2.parse_expr()
    if self_token_eq(p4.current(), Semicolon) {
      (Some(expr), p4.skip(1))
    } else {
      (Some(expr), p4)
    }
  }

  // Parse step (either until ')' or until '{')
  let (step, p4) = if has_paren {
    if self_token_eq(p3.current(), RParen) {
      (None, p3.advance())
    } else {
      let (expr, p5) = p3.parse_expr()
      if self_token_eq(p5.current(), RParen) {
        (Some(expr), p5.advance())
      } else {
        (Some(expr), p5)
      }
    }
    // No parentheses - step goes until '{'
  } else if self_token_eq(p3.current(), LBrace) {
    (None, p3)
  } else {
    let (expr, p5) = p3.parse_expr()
    (Some(expr), p5)
  }

  let (body, p5) = p4.parse_block_or_expr()
  (ForLoop(init, cond, step, body), p5)
}

///|
fn Parser::parse_let(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let is_mut = self_token_eq(p.current(), Mut)
  let p_after_mut = if is_mut { p.skip(1) } else { p }
  // Check for tuple destructuring: let (a, b, c) = value
  if self_token_eq(p_after_mut.current(), LParen) {
    // Parse tuple destructuring
    let p2 = p_after_mut.skip(1) // skip (
    let mut names : Array[String] = []
    let mut parser = p2
    let mut done = false
    while not(done) {
      match parser.current() {
        Ident(name) => {
          names = names + [name]
          parser = parser.advance()
          if self_token_eq(parser.current(), Comma) {
            parser = parser.skip(1)
          } else if self_token_eq(parser.current(), RParen) {
            parser = parser.skip(1)
            done = true
          } else {
            done = true
          }
        }
        RParen => {
          parser = parser.skip(1)
          done = true
        }
        _ => done = true
      }
    }
    // Now expect =
    if self_token_eq(parser.current(), Equal) {
      let p3 = parser.skip(1)
      let (value, p4) = p3.parse_expr()
      let (body, p5) = p4.parse_expr()
      (LetTuple(names, value, body), p5)
    } else {
      // Not a destructuring, treat as error - fallback
      (LetBind("", None, Unit, Unit), parser)
    }
  } else {
    // Original let binding
    let (name, p2) = p_after_mut.parse_ident()
    let (annot, p3) = if self_token_eq(p2.current(), Colon) {
      let p4 = p2.skip(1)
      let (t, p5) = p4.parse_type()
      (Some(t), p5)
    } else {
      (None, p2)
    }
    if self_token_eq(p3.current(), Equal) {
      let p4 = p3.skip(1)
      let (value, p5) = p4.parse_expr()
      let (body, p6) = p5.parse_expr()
      (LetBind(name, annot, value, body), p6)
    } else {
      (LetBind(name, annot, Unit, Unit), p3)
    }
  }
}

///|
fn Parser::parse_function(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let (name, p2) = p.parse_ident()
  if self_token_eq(p2.current(), LParen) {
    let (params, p3) = p2.parse_params()
    let (ret_type, p4) = if self_token_eq(p3.current(), Arrow) {
      let p5 = p3.skip(1)
      let (t, p6) = p5.parse_type()
      (Some(t), p6)
    } else {
      (None, p3)
    }
    let (body, p5) = p4.parse_block_or_expr()
    (Func(name, params, ret_type, body), p5)
  } else {
    let p3 = p2
    if self_token_eq(p3.current(), LBrace) {
      let (body, p4) = p3.parse_block()
      (Func(name, [], None, body), p4)
    } else {
      (Func(name, [], None, Unit), p3)
    }
  }
}

///|
fn Parser::parse_test(self : Parser) -> (AST, Parser) {
  // test { ... } or test "name" { ... }
  let p = self.skip(1)
  let test_name : String? = match p.current() {
    String(s) => Some(s)
    _ => None
  }
  let p2 = if test_name != None { p.advance() } else { p }
  if self_token_eq(p2.current(), LBrace) {
    let (body, p3) = p2.parse_block()
    (TestBlock(test_name, body), p3)
  } else {
    (TestBlock(test_name, Unit), p2)
  }
}

///|
fn Parser::parse_type_decl(self : Parser) -> (AST, Parser) {
  // type Name { field1: Type1, field2: Type2 }
  let p = self.skip(1)
  let (name, p2) = p.parse_ident()
  if self_token_eq(p2.current(), LBrace) {
    let p3 = p2.skip(1)
    let mut fields : Array[(String, String)] = []
    let mut parser = p3
    let mut done = false
    while not(done) {
      if self_token_eq(parser.current(), RBrace) {
        parser = parser.advance()
        // Skip optional derive annotation
        if self_token_eq(parser.current(), Ident("derive")) {
          parser = parser.skip(1)
          if self_token_eq(parser.current(), LParen) {
            parser = parser.skip(1)
            while not(self_token_eq(parser.current(), RParen)) &&
                  not(self_token_eq(parser.current(), Eof)) {
              parser = parser.advance()
            }
            if self_token_eq(parser.current(), RParen) {
              parser = parser.skip(1)
            }
          }
        }
        done = true
      } else if self_token_eq(parser.current(), Eof) {
        done = true
      } else if self_token_eq(parser.current(), Mut) {
        parser = parser.advance()
      } else {
        let (field_name, p4) = parser.parse_ident()
        let (field_type, p5) = if self_token_eq(p4.current(), Colon) {
          let p6 = p4.skip(1)
          let (t, p7) = p6.parse_type_name()
          (t, p7)
        } else {
          ("Int", p4)
        }
        fields = fields + [(field_name, field_type)]
        if self_token_eq(p5.current(), Comma) {
          parser = p5.skip(1)
        } else if self_token_eq(p5.current(), RBrace) {
          parser = p5.advance()
          // Skip optional derive annotation
          if self_token_eq(parser.current(), Ident("derive")) {
            parser = parser.skip(1)
            if self_token_eq(parser.current(), LParen) {
              parser = parser.skip(1)
              while not(self_token_eq(parser.current(), RParen)) &&
                    not(self_token_eq(parser.current(), Eof)) {
                parser = parser.advance()
              }
              if self_token_eq(parser.current(), RParen) {
                parser = parser.skip(1)
              }
            }
          }
          done = true
        } else if self_token_eq(p5.current(), Mut) {
          parser = p5.advance()
        } else {
          parser = p5
        }
      }
    }
    (TypeDecl(name, fields), parser)
  } else {
    (TypeDecl(name, []), p2)
  }
}

///|
fn Parser::parse_enum(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  let (name, p2) = p.parse_ident()
  if self_token_eq(p2.current(), LBrace) {
    let p3 = p2.skip(1)
    let mut variants : Array[String] = []
    let mut parser = p3
    let mut done = false
    while not(done) {
      if self_token_eq(parser.current(), RBrace) {
        parser = parser.advance()
        done = true
      } else if self_token_eq(parser.current(), Eof) {
        done = true
      } else {
        match parser.current() {
          Token::Ident(variant_name) => {
            variants = variants + [variant_name]
            parser = parser.advance()
            if self_token_eq(parser.current(), Comma) {
              parser = parser.skip(1)
            }
          }
          _ => parser = parser.advance()
        }
      }
    }
    (EnumDef(name, variants), parser)
  } else {
    (EnumDef(name, []), p2)
  }
}

///|
fn Parser::parse_type_name(self : Parser) -> (String, Parser) {
  match self.current() {
    Ident(name) => {
      let p = self.advance()
      if self_token_eq(p.current(), LBracket) {
        let p2 = p.skip(1)
        let (inner, p3) = p2.parse_type_name()
        if self_token_eq(p3.current(), RBracket) {
          ("\{name}[\{inner}]", p3.advance())
        } else {
          ("\{name}[\{inner}]", p3)
        }
      } else if self_token_eq(p.current(), LtLt) {
        let p2 = p.skip(1)
        let (inner, p3) = p2.parse_type_name()
        ("\{name}<\{inner}>", p3)
      } else {
        (name, p)
      }
    }
    _ => ("Int", self)
  }
}

///|
fn Parser::parse_params(self : Parser) -> (Array[(String, AST?)], Parser) {
  let p = self.skip(1)
  if self_token_eq(p.current(), RParen) {
    ([], p.advance())
  } else {
    let (first_name, p2) = p.parse_ident()
    let (first_annot, p3) = if self_token_eq(p2.current(), Colon) {
      let p4 = p2.skip(1)
      let (t, p5) = p4.parse_type()
      (Some(t), p5)
    } else {
      (None, p2)
    }
    let first = (first_name, first_annot)
    let mut params = [first]
    let mut parser = p3
    let mut done = false
    while not(done) {
      if self_token_eq(parser.current(), Comma) {
        let p2 = parser.skip(1)
        let (n, p3) = p2.parse_ident()
        let (a, p4) = if self_token_eq(p3.current(), Colon) {
          let p5 = p3.skip(1)
          let (t, p6) = p5.parse_type()
          (Some(t), p6)
        } else {
          (None, p3)
        }
        params = params + [(n, a)]
        parser = p4
      } else if self_token_eq(parser.current(), RParen) {
        parser = parser.advance()
        done = true
      } else {
        done = true
      }
    }
    (params, parser)
  }
}

///|
fn Parser::parse_type(self : Parser) -> (AST, Parser) {
  match self.current() {
    Ident(name) => {
      let p = self.advance()
      if self_token_eq(p.current(), LBracket) {
        let p2 = p.skip(1)
        let (inner, p3) = p2.parse_type()
        let inner_name = match inner {
          Ident(n) => n
          _ => "Unknown"
        }
        if self_token_eq(p3.current(), RBracket) {
          (Ident("\{name}[\{inner_name}]"), p3.advance())
        } else {
          (Ident("\{name}[\{inner_name}]"), p3)
        }
      } else {
        (Ident(name), p)
      }
    }
    LParen => self.parse_type_tuple()
    _ => (Ident("Unknown"), self)
  }
}

///|
fn Parser::parse_type_tuple(self : Parser) -> (AST, Parser) {
  let p = self.skip(1)
  if self_token_eq(p.current(), RParen) {
    (Ident("Unit"), p.advance())
  } else {
    let (first, p2) = p.parse_type()
    if self_token_eq(p2.current(), RParen) {
      (first, p2.advance())
    } else if self_token_eq(p2.current(), Comma) {
      let p3 = p2.skip(1)
      let mut types = [first]
      let mut parser = p3
      let mut done = false
      while not(done) {
        let (t, p2) = parser.parse_type()
        types = types + [t]
        if self_token_eq(p2.current(), Comma) {
          parser = p2.skip(1)
        } else if self_token_eq(p2.current(), RParen) {
          parser = p2.advance()
          done = true
        } else if self_token_eq(p2.current(), Arrow) {
          done = true
        } else {
          done = true
        }
      }
      (Tuple(types), parser)
    } else if self_token_eq(p2.current(), Arrow) {
      let p3 = p2.skip(1)
      let (ret, p4) = p3.parse_type()
      (Ident("(\{first})->\{ret}"), p4)
    } else {
      (first, p2)
    }
  }
}

///|
fn Parser::parse_block_or_expr(self : Parser) -> (AST, Parser) {
  if self_token_eq(self.current(), LBrace) {
    self.parse_block()
  } else {
    self.parse_expr()
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> (AST, Parser) {
  let (base, p2) = self.parse_primary()
  let mut expr = base
  let mut parser = p2
  let mut done = false
  while not(done) {
    if self_token_eq(parser.current(), LParen) {
      let (args, p3) = parser.parse_args()
      expr = CallExpr(expr, args)
      parser = p3
    } else if self_token_eq(parser.current(), ColonColon) {
      let type_name = match expr {
        Ident(name) => name
        _ => ""
      }
      let p3 = parser.skip(1)
      if self_token_eq(p3.current(), LBrace) {
        let p4 = p3.skip(1)
        let mut fields : Array[(String, AST)] = []
        let mut p5 = p4
        let mut done2 = false
        while not(done2) {
          if self_token_eq(p5.current(), RBrace) {
            p5 = p5.advance()
            done2 = true
          } else if self_token_eq(p5.current(), Eof) {
            done2 = true
          } else {
            let (field_name, p6) = p5.parse_ident()
            let (field_val, p7) = if self_token_eq(p6.current(), Colon) {
              let p8 = p6.skip(1)
              let (v, p9) = p8.parse_expr()
              (v, p9)
            } else {
              (Unit, p6)
            }
            fields = fields + [(field_name, field_val)]
            if self_token_eq(p7.current(), Comma) {
              p5 = p7.skip(1)
            } else if self_token_eq(p7.current(), RBrace) {
              p5 = p7.advance()
              done2 = true
            } else {
              p5 = p7
            }
          }
        }
        expr = StructLit(type_name, fields)
        parser = p5
      } else {
        match p3.current() {
          Token::Ident(variant_name) => {
            expr = Ident("\{type_name}::\{variant_name}")
            parser = p3.advance()
          }
          _ => parser = p3
        }
      }
    } else if self_token_eq(parser.current(), Dot) {
      let p3 = parser.skip(1)
      // Check for numeric field (tuple index) or identifier
      match p3.current() {
        Int(i) => {
          expr = FieldExpr(expr, i.to_string())
          parser = p3.advance()
        }
        _ => {
          let (field, p4) = p3.parse_ident()
          expr = FieldExpr(expr, field)
          parser = p4
        }
      }
    } else if self_token_eq(parser.current(), LBracket) {
      let p3 = parser.skip(1)
      let (index, p4) = p3.parse_expr()
      if self_token_eq(p4.current(), RBracket) {
        expr = IndexExpr(expr, index)
        parser = p4.advance()
      } else {
        parser = p4
      }
    } else {
      done = true
    }
  }
  (expr, parser)
}

///|
fn Parser::parse_args(self : Parser) -> (Array[AST], Parser) {
  let p = self.skip(1)
  if self_token_eq(p.current(), RParen) {
    ([], p.advance())
  } else {
    let (first, p2) = p.parse_expr()
    let mut args = [first]
    let mut parser = p2
    let mut done = false
    while not(done) {
      if self_token_eq(parser.current(), Comma) {
        let p2 = parser.skip(1)
        let (arg, p3) = p2.parse_expr()
        args = args + [arg]
        parser = p3
      } else if self_token_eq(parser.current(), RParen) {
        parser = parser.advance()
        done = true
      } else {
        done = true
      }
    }
    (args, parser)
  }
}

///|
fn Parser::parse_unary(self : Parser) -> (AST, Parser) {
  let tok = self.current()
  if self_token_eq(tok, Bang) {
    let p = self.skip(1)
    let (expr, p2) = p.parse_unary()
    (Unary("!", expr), p2)
  } else if self_token_eq(tok, Minus) {
    let p = self.skip(1)
    let (expr, p2) = p.parse_unary()
    (Unary("-", expr), p2)
  } else if self_token_eq(tok, Tilde) {
    let p = self.skip(1)
    let (expr, p2) = p.parse_unary()
    (Unary("~", expr), p2)
  } else if self_token_eq(tok, Ampersand) {
    let p = self.skip(1)
    let (expr, p2) = p.parse_unary()
    (Unary("&", expr), p2)
  } else {
    self.parse_postfix()
  }
}

///|
fn parse_bin_prec(op : String) -> Int {
  match op {
    "||" => 1
    "&&" => 2
    "|" => 3
    "^" => 4
    "&" => 5
    "==" | "!=" => 6
    "<" | ">" | "<=" | ">=" => 7
    "<<" | ">>" => 8
    "+" | "-" => 9
    "*" | "/" | "%" => 10
    _ => 0
  }
}

///|
fn is_binop(tok : Token) -> Bool {
  match tok {
    Plus
    | Minus
    | Star
    | Slash
    | Percent
    | Ampersand
    | Pipe
    | Caret
    | Lt
    | Gt
    | LtEqual
    | GtEqual
    | EqEq
    | BangEqual
    | AmpersandAmpersand
    | PipePipe
    | LtLt
    | GtGt => true
    _ => false
  }
}

///|
fn binop_to_str(tok : Token) -> String {
  match tok {
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Percent => "%"
    Ampersand => "&"
    Pipe => "|"
    Caret => "^"
    Lt => "<"
    Gt => ">"
    LtEqual => "<="
    GtEqual => ">="
    EqEq => "=="
    BangEqual => "!="
    AmpersandAmpersand => "&&"
    PipePipe => "||"
    LtLt => "<<"
    GtGt => ">>"
    _ => ""
  }
}

///|
fn Parser::parse_binary(self : Parser, min_prec : Int) -> (AST, Parser) {
  let (left, p2) = self.parse_unary()
  let mut parser = p2
  let mut left_expr = left
  let mut done = false
  while not(done) {
    let tok = parser.current()
    if is_binop(tok) {
      let op = binop_to_str(tok)
      let prec = parse_bin_prec(op)
      if prec >= min_prec {
        let p3 = parser.skip(1)
        let (right, p4) = p3.parse_binary(prec + 1)
        left_expr = Binary(op, left_expr, right)
        parser = p4
      } else {
        done = true
      }
    } else {
      done = true
    }
  }
  (left_expr, parser)
}

///|
fn parse_string_interpolation(s : String) -> AST {
  // Check if string has interpolation \{expr}
  let mut has_interpolation = false
  let mut i = 0
  while i < s.length() {
    // Use to_char() to compare characters properly
    if i + 1 < s.length() {
      match (s[i].to_char(), s[i + 1].to_char()) {
        (Some(c1), Some(c2)) =>
          if c1 == '\\' && c2 == '{' {
            has_interpolation = true
            break
          }
        _ => ()
      }
    }
    i = i + 1
  }
  if not(has_interpolation) {
    return String(s)
  }
  // Parse interpolation: "text \{expr} text \{expr2} text"
  let mut parts : Array[AST] = []
  let mut current_text = ""
  let mut i = 0
  while i < s.length() {
    // Check for \{ interpolation marker with bounds check
    let is_interpolation = if i + 1 < s.length() {
      match (s[i].to_char(), s[i + 1].to_char()) {
        (Some(c1), Some(c2)) => c1 == '\\' && c2 == '{'
        _ => false
      }
    } else {
      false
    }
    if is_interpolation {
      // Save current text part
      if current_text.length() > 0 {
        parts = parts + [String(current_text)]
        current_text = ""
      }
      // Skip '\{
      i = i + 2
      // Parse expression until }
      let mut expr_str = ""
      while i < s.length() {
        match s[i].to_char() {
          Some(c) =>
            if c == '}' {
              i = i + 1
              break
            } else {
              expr_str = expr_str + c.to_string()
              i = i + 1
            }
          None => break
        }
      }
      // Parse the expression
      let expr = parse_interpolation_expr(expr_str)
      parts = parts + [expr]
    } else {
      // Regular character
      match s[i].to_char() {
        Some(c) => {
          current_text = current_text + c.to_string()
          i = i + 1
        }
        None => break
      }
    }
  }
  // Add remaining text
  if current_text.length() > 0 {
    parts = parts + [String(current_text)]
  }
  // Build StringConcat from parts
  if parts.length() == 1 {
    parts[0]
  } else {
    StringConcat(parts)
  }
}

///|
fn parse_interpolation_expr(expr_str : String) -> AST {
  // Simple expression parser for interpolation
  // Handle: binary expressions, float literal, int literal, ident, expr.field
  let expr_str = expr_str.trim().to_string()

  // Check for binary operators (+, -, *, /)
  let mut found_op_pos = -1
  let mut found_op_char = '+'
  let mut found_op_prec = 1
  let mut paren_depth = 0
  let mut i = 0

  // Scan for binary operators (respecting parentheses)
  while i < expr_str.length() {
    match expr_str[i].to_char() {
      Some(c) =>
        if c == '(' {
          paren_depth = paren_depth + 1
        } else if c == ')' {
          paren_depth = paren_depth - 1
        } else if paren_depth == 0 {
          // Check for binary operators
          let is_op = c == '+' || c == '-' || c == '*' || c == '/'
          if is_op {
            let prec = if c == '*' || c == '/' { 2 } else { 1 }

            // For '-', make sure it's not unary
            let is_unary = if c == '-' {
              if i == 0 {
                true // At start
              } else {
                // Check if previous char is an operator
                match expr_str[i - 1].to_char() {
                  Some(prev) =>
                    prev == '+' ||
                    prev == '-' ||
                    prev == '*' ||
                    prev == '/' ||
                    prev == '('
                  None => false
                }
              }
            } else {
              false
            }

            if not(is_unary) {
              // Binary operator found
              if found_op_pos < 0 || prec <= found_op_prec {
                found_op_pos = i
                found_op_char = c
                found_op_prec = prec
              }
            }
          }
        }
      None => ()
    }
    i = i + 1
  }

  // If we found a binary operator, parse as binary expression
  if found_op_pos >= 0 {
    let left_str = expr_str
      .substring(start=0, end=found_op_pos)
      .trim()
      .to_string()
    let right_str = expr_str
      .substring(start=found_op_pos + 1)
      .trim()
      .to_string()
    let left = parse_interpolation_expr(left_str)
    let right = parse_interpolation_expr(right_str)
    return Binary(found_op_char.to_string(), left, right)
  }

  // Check for field access (e.g., "pos.x", "tuple.0")
  let has_dot = {
    let mut i = 0
    let mut found = false
    while i < expr_str.length() {
      if expr_str[i] == '.' {
        found = true
        break
      }
      i = i + 1
    }
    found
  }

  if has_dot {
    // Check if it's a numeric literal with decimal (e.g., "3.14") 
    // vs field access (e.g., "tuple.0" or "pos.x")
    let parts = expr_str.split(".").to_array()

    if parts.length() == 2 {
      let first_part = parts[0].trim()
      let second_part = parts[1].trim()

      // Check if both parts are numeric (e.g., "3.14", "-1.5")
      let first_is_numeric = {
        let mut all_digits = true
        let mut i = 0
        while i < first_part.length() {
          let c = first_part[i]
          if not((c >= '0' && c <= '9') || (c == '-' && i == 0)) {
            all_digits = false
            break
          }
          i = i + 1
        }
        all_digits && first_part.length() > 0
      }

      let second_is_numeric = {
        let mut all_digits = true
        let mut i = 0
        while i < second_part.length() {
          let c = second_part[i]
          if not(c >= '0' && c <= '9') {
            all_digits = false
            break
          }
          i = i + 1
        }
        all_digits && second_part.length() > 0
      }

      if first_is_numeric && second_is_numeric {
        // It's a float literal like "3.14"
        // Parse manually to avoid errors
        let mut result = 0.0
        let mut is_negative = false
        let mut i = 0

        // Handle negative
        if first_part.length() > 0 && first_part[0] == '-' {
          is_negative = true
          i = 1
        }

        // Parse integer part
        let mut int_part = 0
        while i < first_part.length() {
          let c = first_part[i]
          if c >= '0' && c <= '9' {
            int_part = int_part * 10 + (c - '0').to_int()
          }
          i = i + 1
        }

        // Parse fractional part
        let mut frac_part = 0.0
        let mut frac_divisor = 1.0
        let mut j = 0
        while j < second_part.length() {
          let c = second_part[j]
          if c >= '0' && c <= '9' {
            frac_part = frac_part * 10.0 + (c - '0').to_int().to_double()
            frac_divisor = frac_divisor * 10.0
          }
          j = j + 1
        }

        result = int_part.to_double() + frac_part / frac_divisor
        if is_negative {
          result = -result
        }

        Float(result)
      } else {
        // It's field access like "tuple.0" or "pos.x"
        FieldExpr(Ident(first_part.to_string()), second_part.to_string())
      }
    } else if parts.length() == 3 {
      // Double field access like "obj.field.subfield"
      let base = parts[0].trim().to_string()
      let field1 = parts[1].trim().to_string()
      let field2 = parts[2].trim().to_string()
      FieldExpr(FieldExpr(Ident(base), field1), field2)
    } else {
      Ident(expr_str.to_string())
    }
  } else {
    // No dot - could be integer literal or identifier
    // Check if it's all digits (integer literal)
    let is_integer = {
      let mut all_digits = true
      let mut i = 0
      while i < expr_str.length() {
        let c = expr_str[i]
        if not((c >= '0' && c <= '9') || (c == '-' && i == 0)) {
          all_digits = false
          break
        }
        i = i + 1
      }
      all_digits &&
      expr_str.length() > 0 &&
      (expr_str.length() > 1 || (expr_str[0] >= '0' && expr_str[0] <= '9'))
    }

    if is_integer {
      // Parse integer
      let mut result = 0
      let mut is_negative = false
      let mut i = 0

      if expr_str.length() > 0 && expr_str[0] == '-' {
        is_negative = true
        i = 1
      }

      while i < expr_str.length() {
        let c = expr_str[i]
        if c >= '0' && c <= '9' {
          result = result * 10 + (c - '0').to_int()
        }
        i = i + 1
      }

      if is_negative {
        result = -result
      }

      Int(result)
    } else {
      // Simple identifier
      Ident(expr_str.to_string())
    }
  }
}

///|
fn Parser::parse_expr(self : Parser) -> (AST, Parser) {
  let (left, p2) = self.parse_binary(1)
  // Check for assignment
  if self_token_eq(p2.current(), Equal) {
    let p3 = p2.skip(1)
    let (value, p4) = p3.parse_expr()
    (Assign(left, value), p4)
  } else {
    // Check for compound assignment operators
    let op = match p2.current() {
      PlusEqual => Some("+")
      MinusEqual => Some("-")
      StarEqual => Some("*")
      SlashEqual => Some("/")
      PercentEqual => Some("%")
      AmpersandEqual => Some("&")
      PipeEqual => Some("|")
      CaretEqual => Some("^")
      LtLt => Some("<<")
      GtGt => Some(">>")
      _ => None
    }
    match op {
      Some(op_str) => {
        let p3 = p2.skip(1)
        let (value, p4) = p3.parse_expr()
        (AssignOp(op_str, left, value), p4)
      }
      None => (left, p2)
    }
  }
}

///|
pub fn Parser::parse(self : Parser) -> AST {
  let mut stmts : Array[AST] = []
  let mut parser = self
  let mut done = false
  while not(done) {
    if self_token_eq(parser.current(), Eof) {
      done = true
    } else {
      let (expr, p2) = parser.parse_expr()
      // If parser didn't advance, skip current token to avoid infinite loop
      if p2.pos == parser.pos {
        parser = parser.advance()
      } else {
        stmts = stmts + [expr]
        parser = p2
      }
    }
  }
  if stmts.length() == 1 {
    stmts[0]
  } else {
    Block(stmts)
  }
}

///|
pub fn parse(tokens : Array[Token]) -> AST {
  let parser = Parser::new(tokens)
  parser.parse()
}

///|
pub enum Operand {
  Imm(Int)
  Reg(String)
  Stack(Int)
  Label(String)
  LabelAddr(String)
} derive(Show)

///|
pub enum X86Inst {
  Mov(X86Operand, X86Operand)
  Movzx(X86Operand, X86Operand)
  Push(X86Operand)
  Pop(X86Operand)
  Add(X86Operand, X86Operand)
  Sub(X86Operand, X86Operand)
  Imul(X86Operand, X86Operand)
  Idiv(X86Operand)
  Cmp(X86Operand, X86Operand)
  Test(X86Operand, X86Operand)
  And(X86Operand, X86Operand)
  Or(X86Operand, X86Operand)
  Xor(X86Operand, X86Operand)
  Not(X86Operand)
  Neg(X86Operand)
  Inc(X86Operand)
  Dec(X86Operand)
  Cqo
  Shl(X86Operand, X86Operand)
  Shr(X86Operand, X86Operand)
  Sar(X86Operand, X86Operand)
  Jmp(String)
  Je(String)
  Jne(String)
  Jg(String)
  Jge(String)
  Jl(String)
  Jle(String)
  Ja(String)
  Jae(String)
  Jb(String)
  Jbe(String)
  Jz(String)
  Jnz(String)
  Jp(String)
  Setz(X86Operand)
  Setnz(X86Operand)
  Setg(X86Operand)
  Setge(X86Operand)
  Setl(X86Operand)
  Setle(X86Operand)
  Seta(X86Operand)
  Setae(X86Operand)
  Setb(X86Operand)
  Setbe(X86Operand)
  PushXmm(String)
  PopXmm(String)
  Call(String)
  Ret
  Nop
  Syscall
  Lea(X86Operand, X86Operand)
  Movsd(X86Operand, X86Operand)
  Addsd(X86Operand, X86Operand)
  Subsd(X86Operand, X86Operand)
  Mulsd(X86Operand, X86Operand)
  Divsd(X86Operand, X86Operand)
  Ucomisd(X86Operand, X86Operand)
  Cvtsi2sd(X86Operand, X86Operand)
  Cvttsd2si(X86Operand, X86Operand)
  RepMovsq
} derive(Show)

///|
pub enum X86Operand {
  Imm8(Int)
  Imm32(Int)
  Imm64(Int)
  Reg8(String)
  Reg32(String)
  Reg64(String)
  Xmm(String)
  Stack8(Int)
  Stack32(Int)
  Stack64(Int)
  StackBP64(Int)
  RipRel32(String)
  Label(String)
  MemIndirect(String)
  MemOffset(String, Int) // base register, offset
} derive(Show)

///|
