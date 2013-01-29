#!/bin/bash

# TODO rename this file.
set -e
set -u

source lib/json.sh

help() {
  echo "Usage: find.sh [-u username][-l][-f postfail][-p postprocessing][-m module] -e 'ec2 group pattern' 'ansible arguments'"
  echo ""
  echo "Run a command on a set of ec2 instances. Provides regex matching on the"
  echo "ec2 group/instance/tag names."
  echo ""
  echo "Options:"
  echo " -l just list matching nodes, don't do anything"
  echo " -p underscore postprocessing(ie, select .stdout). Prints host name and stdout by default."
  echo " -f underscore post fail (ie, select .failed). Prints host name by default"
  echo " -e group pattern"
  echo " -m ansible module. (default: shell)"
  echo " 'ansible arguments' correspond to ansible's -a option."
  echo ""
  echo "Example:"
  echo ""
  echo "   # collect the size of all the messages files."
  echo "   ./find.sh -u USERNAME -e '.*prod-frontend[1-9]' 'du -sh /var/log/messages'"
  echo ""
  exit 1
}

VERBOSE=0
USER='root'
LISTONLY=0
# first, just print the host, then break out the output (of shell) by line breaks
POSTPROCESSING="map 'h = {} ; h[k] = v.stdout.split(\"\\n\") for k,v of value; h'"
POSTFAIL="-q map 'console.log(k) for k,v of value'"
EC2PATTERN=''
ANSIBLEMODULE='shell'
while getopts "vlp:u:e:m:f:" opt; do
  case $opt in
    m )
      ANSIBLEMODULE=$OPTARG
      ;;
    e )
      EC2PATTERN=$OPTARG
      ;;
    f )
      POSTFAIL=$OPTARG
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
  ansible-plugins/inventory/ec2.py > /tmp/ansible-ec2.cache
fi

cat /tmp/ansible-ec2.cache | underscore --coffee map -q "console.log(key) if key.match(/$EC2PATTERN/)" > matches.txt

if [[ $LISTONLY -eq 1 ]]; then
  cat matches.txt
else
  rm -rf out
  mkdir out
  matchesjoined=`cat matches.txt | tr "\\n" ":"`
  # do the ansible command, regardless of the error, continue to post processing
  echo ansible -i ./ansible-plugins/inventory/ec2.py -u $USER $matchesjoined -m shell -a "$1" -t out
  (ansible -i ./ansible-plugins/inventory/ec2.py -u $USER $matchesjoined -m shell -a "$1" -t out > /dev/null ; true)
  # loop thru the results and do post processing, if there is no failure.

  combinejsonfiles out all.json
  mv all.json out

  echo "[1m----------------------------------------------------------------------[0m"
  echo "[1mPost Processing:[0m"
  echo "[1m----------------------------------------------------------------------[0m"
  underscore -i out/all.json --coffee filter '(k for k,v of value when v?.failed).length > 0' > out/failed.json
  underscore -i out/all.json --coffee filter '(k for k,v of value when not ("failed" of v)).length > 0' > out/results.json

  echo "Failed:"
  eval "underscore -i out/failed.json --color --coffee $POSTFAIL"

  echo "Processed:"
  eval "underscore -i out/results.json --color --coffee $POSTPROCESSING"
fi

rm matches.txt
