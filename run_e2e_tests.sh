#!/bin/bash
# E2E tests for mbtc compiler
# Compares output with official MoonBit compiler

# Don't exit on error - we want to run all tests

EXAMPLES_DIR="examples/mbt_examples"
PASS=0
FAIL=0

for i in 001 002 003 004 005 006 007 008 009 010 011; do
  file=$(ls $EXAMPLES_DIR/${i}_*.mbt 2>/dev/null | head -1)
  if [ -z "$file" ]; then
    echo "$i: FILE NOT FOUND"
    continue
  fi
  
  # Compile with our compiler
  moon run cmd/main "$file" > /dev/null 2>&1
  exe="${file%.mbt}.exe"
  
  if [ ! -f "$exe" ]; then
    echo "$i: COMPILE FAILED"
    ((FAIL++))
    continue
  fi
  
  chmod +x "$exe"
  
  # Run both and compare
  moon run "$file" > "/tmp/moon_${i}.txt" 2>&1
  "./$exe" > "/tmp/our_${i}.txt" 2>&1
  
  if diff -q "/tmp/moon_${i}.txt" "/tmp/our_${i}.txt" > /dev/null 2>&1; then
    echo "$i: PASS"
    ((PASS++))
  else
    echo "$i: FAIL"
    ((FAIL++))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
