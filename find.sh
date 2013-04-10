#!/bin/bash

# TODO Use the location of this script for relative references...
# script_dir="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"

# TODO write an install script. setup.py? http://docs.python.org/2/distutils/setupscript.html

# TODO rename this file.
set -e
set -u

# TODO ONLY provide the following options:
# get rid of th -e pattern - it should just be the 'host patten' as known by ansible
# use -r for 'read only' (list only).
# 
# in other words, this command should be as much like ansible as possible.
# python and argparse would probably make more sense here...

help() {
  echo "Usage: find.sh [-u username][-l][-f postfail][-p postprocessing][-a ansible options] -e 'ec2 group pattern' 'ansible arguments'"
  echo ""
  echo "Run a command on a set of ec2 instances. Provides regex matching on the"
  echo "ec2 group/instance/tag names."
  echo ""
  echo "Options:"
  echo " -l just list matching nodes, don't do anything"
  echo " -p underscore postprocessing(ie, select .stdout). Prints host name and stdout by default."
  echo " -f underscore post fail (ie, select .failed). Prints host name by default"
  echo " -e group pattern"
  echo " -a ansible options (default: -m shell)"
  echo " 'ansible arguments' correspond to ansible's -a option."
  echo ""
  echo "Output:"
  echo "  out/all.json     = All of the results stored as a JSON hash."
  echo "  out/failed.json  = The portion of all.json that failed (bad credentials, no connection, etc)."
  echo "                     The '-f' option processes this file."
  echo "  out/results.json = The portion of all.json that succeeded."
  echo "                     The '-p' option processes this file."
  echo ""
  echo "Example:"
  echo ""
  echo "   # collect the size of all the messages files."
  echo "   ./find.sh -u USERNAME -e 'prod[1-9]' 'du -sh /var/log/messages'"
  echo ""
  exit 1
}

VERBOSE=0
USER='root'
LISTONLY=0
ANSIBLEOPTIONS='-m shell'
POSTPROCESSING=''
# first, just print the host, then break out the output (of shell) by line breaks
SHELLPOSTPROCESSING="map 'h = {} ; h[k] = v?.stdout?.split(\"\\n\") for k,v of value; h'"
# this is ideal for non-ssh stuff:
COPYPOSTPROCESSING="map 'h = {} ; h[k] = v?.changed for k,v of value; h'"
# for fails, print out the hostname only.
POSTFAIL="-q map 'console.log(k) for k,v of value'"
EC2PATTERN=''
while getopts "vlp:u:e:a:f:" opt; do
  case $opt in
    a )
      ANSIBLEOPTIONS=$OPTARG
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

if [[ "$POSTPROCESSING" = "" ]]
then
  if [[ "$ANSIBLEOPTIONS" = "-m copy" ]]
  then
    POSTPROCESSING=$COPYPOSTPROCESSING
  else
    POSTPROCESSING=$SHELLPOSTPROCESSING
  fi
fi

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

# obtain both the group name, and the host names for each match
underscore -i /tmp/ansible-ec2.cache --coffee map "[key,value] if key.match(/$EC2PATTERN/)" > __a.json
underscore -i __a.json filter value > __b.json
mv __b.json __a.json
underscore -i __a.json --coffee process "h={}; h[v[0]] = v[1] for k,v of data; h" > matches.txt

# extract the group name and join them into one line of ansible search terms
underscore -i matches.txt --coffee map -q "console.log(v) for i,v of value" > groups.txt
matchesjoined=`cat groups.txt | tr "\\n" ":"`

if [[ $LISTONLY -eq 1 ]]; then
  underscore -i matches.txt --coffee map -q "console.log(v) for i,v of value"
else
  rm -rf out
  mkdir out

  # do the ansible command, regardless of the error, continue to post processing
  echo ansible -i ./ansible-plugins/inventory/ec2.py -u $USER $matchesjoined $ANSIBLEOPTIONS -a "$1" -t out
  (ansible -i ./ansible-plugins/inventory/ec2.py -u $USER $matchesjoined $ANSIBLEOPTIONS -a "$1" -t out > /dev/null ; true)

  # combine all the results into one json file
  dir='out'
  output='all.json'
  # print the opening list w/o a carriage return
  echo '[' > $output
  # allow an empty list:
  shopt -s extglob
  shopt -s nullglob
  for i in $dir/*; do
    key=`echo $i | sed 's/out\///'`

    # try to find the tag name of the instance. If it can't be found, just show
    # the host name
    tag=`underscore -i /tmp/ansible-ec2.cache --coffee map -q "console.log(key) if size(value) == 1 && value[0].match(/$key/) && key.indexOf('tag') == 0"`
    if [[ -z "$tag" ]]
    then
      echo "{'$key':" >> $output
    else
      echo "{'$tag':" >> $output
    fi

    cat "$i" >> $output
    echo "}," >> $output
  done
  # print the trailing list w/o a carriage return
  echo "]" >> $output
  mv all.json out

  echo "[1m----------------------------------------------------------------------[0m"
  echo "[1mPost Processing:[0m"
  echo "[1m----------------------------------------------------------------------[0m"

  # group all the failed groups together:
  underscore -i out/all.json --coffee filter '(k for k,v of value when v?.failed).length > 0' > out/failed.json

  # group all the succeeded hosts together.
  underscore -i out/all.json --coffee filter '(k for k,v of value when not ("failed" of v)).length > 0' > out/results.json

  echo "Failed:"
  eval "underscore -i out/failed.json --color --coffee $POSTFAIL"

  echo "Processed:"
  eval "underscore -i out/results.json --color --coffee $POSTPROCESSING"
fi

rm -f groups.txt matches.txt __a.json
