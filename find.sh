#!/bin/bash

# TODO rename this file.
set -e
set -u

help() {
  echo "Usage: ans2und.sh [-u username][-l][-p postprocessing][-m module] -e 'ec2 group pattern' 'ansible arguments'"
  echo ""
  echo "Options:"
  echo " -p underscore postprocessing. (ie, select .stdout)"
  echo " -e group pattern"
  echo " -m ansible module. (default: shell)"
  echo " 'ansible arguments' correspond to ansible's -a option."
  echo ""
  echo "Example:"
  echo ""
  exit 1
}

VERBOSE=0
USER='root'
LISTONLY=0
# first, just select STDOUT, then break it out by line breaks
POSTPROCESSING="underscore select .stdout | underscore --color --coffee map 'value.split(\"\\n\")'"
EC2PATTERN=''
ANSIBLEMODULE='shell'
while getopts "vlp:u:e:m:" opt; do
  case $opt in
    m )
      ANSIBLEMODULE=$OPTARG
      ;;
    e )
      EC2PATTERN=$OPTARG
      ;;
    p )
      POSTPROCESSING=$OPTARG
      ;;
    v )
      VERBOSE=1
      ;;
    u )
      USER=$OPTARG
      ;;
    l )
      LISTONLY=1
      ;;
    \?)
      help
      ;;
  esac
done

shift $((OPTIND-1))

if [[ $LISTONLY == 0 ]]; then
  if [[ $# -lt 1 ]]
  then
    help
  fi
  if [[ "${EC2PATTERN}" == '' ]]
  then
    help
  fi
fi

# if the inventory can't be found regenerate it
if [[ ! -e /tmp/ansible-ec2.cache ]]; then
  ./ec2.py > /tmp/ansible-ec2.cache
fi

cat /tmp/ansible-ec2.cache | underscore --coffee map -q "console.log(key) if key.match(/$EC2PATTERN/)" > matches.txt

if [[ $LISTONLY -eq 1 ]]; then
  cat matches.txt
else
  rm -rf out
  mkdir out
  matchesjoined=`cat matches.txt | tr "\\n" ":"`
  # do the ansible command, regardless of the error, continue to post processing
  echo ansible -i ./ec2.py -u $USER $matchesjoined -m shell -a "$1" -t out
  (ansible -i ./ec2.py -u $USER $matchesjoined -m shell -a "$1" -t out ; true)
  # loop thru the results and do post processing, if there is no failure.
  cd out
  echo "[1m----------------------------------------------------------------------[0m"
  echo "[1mPost Processing:[0m"
  echo "[1m----------------------------------------------------------------------[0m"
  for i in *; do
    tag=`cat /tmp/ansible-ec2.cache | underscore map --coffee -q "console.log(key) if key.match(/^tag_Name/) && value[0].match(/$i/)"`
    failed=`cat $i | underscore select .failed`
    if [[ "$failed" == "[true]" ]]; then
      echo "[1m$tag[0m : [1;31mFAILED[0m"
    else
      echo "[1m$tag[0m :"
      eval "cat ${i} | ${POSTPROCESSING}"
    fi
  done
  cd ..
fi

rm matches.txt
