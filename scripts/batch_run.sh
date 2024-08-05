#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <path_to_la_emu> <workload directory>"
  exit 1
fi

if [ ! -x "$1" ]; then
  echo "Error: $1 is not a valid executable file."
  exit 1
fi

if [ ! -d "$2" ]; then
  echo "Error: Directory $2 does not exist."
  exit 1
fi

LA_EMU=$1
DIR=$2

for file in "$DIR"/*.vmlinux; do
  if [ -f "$file" ]; then
    echo run file=$file
    "$LA_EMU" -z -m 16 -k "$file"
  fi
done