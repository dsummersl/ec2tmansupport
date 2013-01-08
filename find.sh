#!/bin/sh

set -e
set -u

if [[ $# -lt 1 ]]; then
  echo "Requires one argument - the search regular expression"
  exit 1
fi

cat /tmp/ansible-ec2.cache | underscore map --coffee -q "console.log(key) if key.match(/$1/)"
