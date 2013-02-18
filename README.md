VT Ansible
====

Scripts for using ansible on top of ec2, with post-processing of results by
underscore-cli.

Scripts
====

__find.sh__ -- wrapper around ansible commandline app.

__tmux.sh__ -- open up several SSH connections in a new tmux session.

Examples
====

./find.sh -u dsummers -p -e '.*name.*' 'du -sh /var/log/messages'

Requirements
====

npm install -g underscore-cli

tmux

Ansible
