#!/bin/bash
# This is a wrapper shell script for saving a seperate log file per playbook
# Guided by https://stackoverflow.com/questions/35135954/how-to-log-in-a-separate-file-per-playbook-in-ansible
# Logging in the ansible.cfg file should be disabled

export ANSIBLE_LOG_PATH=/var/log/ansible/plabook_$(echo $1 | cut -d . -f 1).log
ansible-playbook $@