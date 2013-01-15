#!/bin/sh

# TODO rename this file.
set -e
set -u

help() {
  echo "Usage: ans2und.sh [-u username][-l][-p postprocessing] -e 'ec2 group pattern' 'shell command'"
  echo ""
  echo "Options:"
  echo " -p underscore postprocessing. (ie, select .stdout)"
  echo " -e group pattern"
  exit 1
}

VERBOSE=0
USER='root'
LISTONLY=0
# TODO figure out how to do postprocessing...
POSTPROCESSING='select .stdout'
EC2PATTERN=''
while getopts "vlp:u:e:" opt; do
  case $opt in
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
  (ansible -i ./ec2.py -u $USER $matchesjoined -m command -a "$1" -t out ; true)
  # loop thru the results and do post processing, if there is no failure.
  cd out
  echo "[1m----------------------------------------------------------------------[0m"
  echo "[1mPost Processing:0m"
  echo "[1m----------------------------------------------------------------------[0m"
  for i in *; do
    tag=`cat /tmp/ansible-ec2.cache | underscore map --coffee -q "console.log(key) if key.match(/^tag_Name/) && value[0].match(/$i/)"`
    failed=`cat $i | underscore select .failed`
    if [[ "$failed" == "[true]" ]]; then
      echo "[1m$tag[0m : [1;31mFAILED[0m"
    else
      echo "[1m$tag[0m :"
      cat $i | underscore --color $POSTPROCESSING
    fi
  done
  cd ..
  rm -rf out
fi

rm matches.txt

# TODO extend this to do a search, and then do a search/run thru ansible.

