#!/bin/bash

set -u
set -e

# Given the arguments (a file blob), combine them all into an array of
# JSON. 
# 
# Parameters:
#   - directory
#   - output file
combinejsonfiles() {
  dir=$1
  output=$2

  # print the opening list w/o a carriage return
  echo '[' > $output
  # allow an empty list:
  shopt -s extglob
  for i in $dir/*; do
    echo "{'$i':" >> $output
    cat "$i" >> $output
    echo "}," >> $output
  done
  # print the trailing list w/o a carriage return
  echo "]" >> $output
}

