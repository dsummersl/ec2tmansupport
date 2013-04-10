#!/bin/bash

set -e
set -u

help() {
  echo "Usage: ./vtmux.sh [-l][-s name][-u user][-p num] host-pattern"
  echo ""
  echo "Connect to several hosts in a new tmux session."
  echo ""
  echo "Options:"
  echo " -p : Max SSH panes per window (defaults to 0 == no max)"
  echo " -l : Just list hosts that match your pattern and exit"
  echo " -s : tmux session name. Defaults to the 'ec2hosts'"
  echo " -u : ssh username"
  echo ""
  echo "Note: You cannot use this script inside a tmux session, as it creates a new one."
  exit 1
}

if [[ "$TERM" = "screen"  && -n "$TMUX" ]]
then
  echo "ERROR: You are inside a tmux session!"
  echo ""
  help
fi

LISTONLY=0
TMUXSESSION='ec2hosts'
SSHUSER='root'
MAXPANECOUNT=0
while getopts "ls:u:p:" opt; do
  case $opt in
    p )
      MAXPANECOUNT=$OPTARG
      ;;
    u )
      SSHUSER="$OPTARG"
      ;;
    s )
      TMUXSESSION="$OPTARG"
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

if [[ $# -lt 1 ]]; then
  echo "ERROR: You must provide a host pattern."
  echo ""
  help
fi

EC2PATTERN=$1
shift

# if the inventory can't be found regenerate it
if [[ ! -e /tmp/ansible-ec2.cache ]]; then
  ansible-plugins/inventory/ec2.py > /tmp/ansible-ec2.cache
fi

underscore -i /tmp/ansible-ec2.cache --coffee map "[key,value] if key.match(/$EC2PATTERN/)" > __a.json
underscore -i __a.json filter value > __b.json
mv __b.json __a.json
underscore -i __a.json --coffee process "h={}; h[v[0]] = v[1] for k,v of data; h" > __b.json

# extract the group name and join them into one line of ansible search terms
underscore -i __b.json --coffee map -q "console.log(v) for i,v of value" > matches.txt

if [[ $LISTONLY -eq 1 ]]; then
  cat matches.txt
else
  # TODO verify that the session doesn't already exist.
  tmux new-session -d -s "$TMUXSESSION"

  # turn on window activity notification:
  tmux set-window-option -t "$TMUXSESSION" -g monitor-activity on
  tmux set-option -t "$TMUXSESSION" -g visual-activity on

  tmux bind-key e command-prompt -p "message?" "run-shell \"./lib/execute_everywhere.sh '%1'\""

  cnt=0
  wcnt=0
  first=1
  while read line
  do
    # pull the actual host name from whatever the tag name was:
    hostname=$line
    if [ $cnt -lt $MAXPANECOUNT -o $MAXPANECOUNT -eq 0 ]; then
      if [[ $first = 0 ]]; then
        tmux split-window -t "$TMUXSESSION:$wcnt"
      fi
      first=0
      let cnt=$cnt+1
    else
      let cnt=$cnt+1
      let wcnt=$wcnt+1
      cnt=1
      tmux new-window -t "$TMUXSESSION:$wcnt"
      tmux rename-window -t "$TMUXSESSION:$wcnt" $line
      tmux set-window-option -t "$TMUXSESSION:$wcnt" allow-rename off
    fi

    tmux send-keys -t "$TMUXSESSION:$wcnt" "ssh -o StrictHostKeyChecking=no $SSHUSER@$hostname" C-m
    tmux select-layout -t "$TMUXSESSION:$wcnt" tiled
  done < matches.txt

  # remove session 0 - which is not connected to anything
  # TODO provide a hotkey to run in all sessions

  tmux attach-session -t "$TMUXSESSION"
fi

rm matches.txt __b.json
