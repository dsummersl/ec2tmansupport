#!/bin/bash

set -u
set -e

if [[ $# -lt 1 ]]; then
  echo "ERROR: you must pass one parameter (an instance name)."
  exit 1
fi

search=$1

# if the inventory can't be found regenerate it
if [[ ! -e /tmp/ansible-ec2.cache ]]; then
  ansible-plugins/inventory/ec2.py > /tmp/ansible-ec2.cache
fi

instance=`cat /tmp/ansible-ec2.cache| underscore --coffee map -q "console.log(value[0]) if key.match(/$search/)"`
cat /tmp/ansible-ec2.cache| underscore --coffee map -q "console.log(key) if key.match(/tag/) && value[0].match(/$instance/)"
