VT Ansible
====

Scripts to use ansible on top of ec2, with post-processing of results by
underscore-cli.

Scripts
====

__find.sh__ -- wrapper around ansible commandline app.

__tmux.sh__ -- open up several SSH connections in a new tmux session.

Examples
====

Compute the file size of `/var/log/messages` for all ec2 instances with `name` in their Name:

    ./find.sh -u USERNAME -e 'name' 'du -sh /var/log/messages'

Use ansible's [copy module](http://ansible.cc/docs/modules.html#copy) to copy
file `example.txt` to all ec2 instances with `devbox` in their name. Note that
b/c ansible's module commands are [generally
idempotent](http://ansible.cc/docs/) this command only copies the file to the
host if it doesn't exist or has a different hash:

    ./find.sh -u USERNAME -e 'devbox' -m copy 'src=example.txt dest=/opt/site/example.txt'

Requirements
====

The following libraries are needed:

 * [underscore-cli](https://github.com/ddopson/underscore-cli): Note that this requires nodejs.
 * [tmux](http://tmux.sourceforge.net/)
 * [Ansible](http://ansible.cc/): requires python2.6+
