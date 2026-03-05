///|
/// Entry point for the CLI
/// Run with `moon run cmd/main` from the project root
fn main {
  let args = @env.args()
  if args.length() < 2 {
    return
  }

  let input_path = args[1]
  let output_path = if args.length() >= 3 {
    args[2]
  } else {
    match input_path.strip_suffix(".mbt") {
      Some(base) => base.to_string() + ".exe"
      None => input_path + ".exe"
    }
  }

  match @lib.compile_file(input_path, output_path) {
    Ok(_) => println("Compiled to \{output_path}")
    Err(e) => println("Error: \{e}")
  }
}
