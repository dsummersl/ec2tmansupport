VT Ansible
====

Support scripts for using ansible on top of ec2.

Scripts
====

__find.sh__ -- simple script that searches all groups in ec2 by your regex.

    # find all prod groups/keys
    ./find.sh prod

ansible. Use ansible with ec2 by specifying the ec2 script to search boxes.

    # search all hosts for the current version of puppet. Save to an out file as json.
    ansible -i ./ec2.py -u dsummers all -m command -a "puppet --version" -t out

    # use underscore-cli to aggregate the results.
    (for i in out/*; do cat $i | underscore select .stdout; done) | sort | uniq -c

__tmux.sh__ -- open up several SSH connections in a new tmux session.

Examples
====

./find.sh -u dsummers -p -e '.*name.*' 'du -sh /var/log/messages'

Requirements
====

npm install -g underscore-cli

tmux

Ansible

Testing
====

sh lib/test/json_test.sh
