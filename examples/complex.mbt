fn main {
  println("=== Arithmetic ===")
  println(int_to_string(10 + 5))
  println(int_to_string(20 - 8))
  println(int_to_string(6 * 7))
  println(int_to_string(100 / 4))
  println(int_to_string(17 % 5))

  println("=== Comparison ===")
  println(int_to_string(if 5 < 10 { 1 } else { 0 }))
  println(int_to_string(if 10 > 5 { 1 } else { 0 }))
  println(int_to_string(if 5 <= 5 { 1 } else { 0 }))
  println(int_to_string(if 10 >= 10 { 1 } else { 0 }))
  println(int_to_string(if 5 == 5 { 1 } else { 0 }))
  println(int_to_string(if 5 != 10 { 1 } else { 0 }))

  println("=== Logical ===")
  println(int_to_string(if true && false { 1 } else { 0 }))
  println(int_to_string(if true || false { 1 } else { 0 }))
  println(int_to_string(if !false { 1 } else { 0 }))

  println("=== Bitwise ===")
  println(int_to_string(12 & 10))
  println(int_to_string(12 | 10))
  println(int_to_string(12 ^ 10))
  println(int_to_string(8 << 2))
  println(int_to_string(32 >> 2))

  println("=== Unary ===")
  println(int_to_string(0 - 42))

  println("=== Tuples ===")
  let pair = (100, 200)
  println(int_to_string(pair.0))
  println(int_to_string(pair.1))

  let triple = (1, 2, 3)
  println(int_to_string(triple.0))
  println(int_to_string(triple.1))
  println(int_to_string(triple.2))

  println("=== Arrays ===")
  let arr = [10, 20, 30, 40, 50]
  println(int_to_string(arr[0]))
  println(int_to_string(arr[1]))
  println(int_to_string(arr[2]))
  println(int_to_string(arr[3]))
  println(int_to_string(arr[4]))

  println("=== Array Assignment ===")
  arr[2] = 99
  println(int_to_string(arr[2]))

  println("=== Strings ===")
  println("Hello, World!")
  println(string_concat("Hello, ", "MoonBit!"))

  println("=== Float ===")
  println(float_to_string(3.14))

  println("=== Char ===")
  println(int_to_string(char_to_int('A')))
  println(int_to_string(char_to_int('Z')))

  println("=== While Loop ===")
  let i = 0
  while i < 5 {
    println(int_to_string(i))
    i = i + 1
  }

  println("=== For Loop ===")
  for (let j = 0; j < 5; j = j + 1) {
    println(int_to_string(j))
  }

  println("=== Break ===")
  let k = 0
  while k < 10 {
    if k == 5 {
      break
    }
    println(int_to_string(k))
    k = k + 1
  }

  println("=== Continue ===")
  let m = 0
  while m < 5 {
    m = m + 1
    if m == 3 {
      continue
    }
    println(int_to_string(m))
  }

  println("=== Match ===")
  let num = 3
  match num {
    case 1 => println("one")
    case 2 => println("two")
    case 3 => println("three")
    case _ => println("other")
  }

  println("=== Done ===")
  0
}
