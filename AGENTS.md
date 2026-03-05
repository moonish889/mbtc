# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

## Building and Running

This project is a compiler that compiles a simple language to x86_64 ELF
executables.

### Build the project

```bash
moon build
```

### Run the compiler

```bash
# Single file:
moon run cmd/main <input_file> [output_file]
```

- `input_file`: Source file to compile
- `output_file`: Output executable path (optional, default: `<input_name>.exe`)

Example:
```bash
moon run cmd/main examples/simple.mbt
chmod +x examples/simple.exe
./examples/simple.exe
```

The output file is created in the same directory as the source file with `.exe` extension. Execute permission must be set manually with `chmod +x`.

### Run tests

```bash
moon test
```

### Verify Output Against Official Compiler

When working on compiler features, always compare output from our compiler to the official MoonBit compiler:

```bash
# Compile with our compiler
moon run cmd/main examples/mbt_examples/001_hello.mbt
chmod +x examples/mbt_examples/001_hello.exe

# Compare outputs
moon run examples/mbt_examples/001_hello.mbt > /tmp/moon_output.txt
./examples/mbt_examples/001_hello.exe > /tmp/our_output.txt
diff /tmp/moon_output.txt /tmp/our_output.txt
```

For batch verification of multiple examples:
```bash
for i in 001 002 003 004; do
  moon run cmd/main examples/mbt_examples/${i}_*.mbt 2>/dev/null
  chmod +x examples/mbt_examples/${i}_*.exe
  moon run examples/mbt_examples/${i}_*.mbt 2>/dev/null > /tmp/moon_$i.txt
  ./examples/mbt_examples/${i}_*.exe > /tmp/our_$i.txt 2>&1
  if diff -q /tmp/moon_$i.txt /tmp/our_$i.txt > /dev/null; then
    echo "$i: IDENTICAL"
  else
    echo "$i: DIFFERENT"
  fi
done
```

**Important**: Only mark an example as "working" in `plan_examples.md` if the output is IDENTICAL to the official compiler.

## Project Components

- `lexer.mbt` - Tokenizer (Token enum, Lexer struct, lexing functions)
- `parser.mbt` - Parser (AST enum, Parser struct, expression parsing)
- `codegen.mbt` - Code Generator (x86_64 instruction types, CodeGen struct, code generation)
- `double_ryu_nonjs.mbt` - Ryu float-to-string algorithm for IEEE 754 doubles
- `compiler.mbt` - Entry point and ELF header generation
- `cmd/main/main.mbt` - CLI entry point
