#!/bin/bash

component=$1              #receiving component from bootstrap.sh 
env=$2

echo "Installing Ansible..."
dnf install ansible -y

echo "Ansible installation complete"
ansible --version

cd /home/ec2-user

git clone https://github.com/mayuri-mb/ansible-roboshop-roles-tf.git
git pull

cd ansible-roboshop-roles-tf
ansible-playbook -e component=$component -e env=$env roboshop.yaml
