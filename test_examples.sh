#!/bin/bash
for i in 001 002 003 004 005 006 007 008 009 010 011 012 013; do
  file=$(ls examples/mbt_examples/${i}_*.mbt 2>/dev/null | head -1)
  if [ -n "$file" ]; then
    moon run cmd/main "$file" 2>/dev/null
    if [ -f "${file%.mbt}.exe" ]; then
      chmod +x "${file%.mbt}.exe"
      ./"${file%.mbt}.exe" > "/tmp/our_${i}.txt" 2>&1
      moon run "$file" > "/tmp/moon_${i}.txt" 2>&1
      if diff -q "/tmp/moon_${i}.txt" "/tmp/our_${i}.txt" > /dev/null 2>&1; then
        echo "$i: PASS"
      else
        echo "$i: FAIL"
      fi
    else
      echo "$i: COMPILE ERROR"
    fi
  fi
done
