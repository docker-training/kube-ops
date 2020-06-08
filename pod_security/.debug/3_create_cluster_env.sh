#!/bin/bash

# Get k8s-api
kubectl config view | grep server | cut -d: -f2,3,4 | tr -d "[:space:]" > api.txt

# Pass over k8s-api to bob
sudo cp ./api.txt /home/bob
sudo chown bob:bob /home/bob/api.txt
rm api.txt

# Assume bob and configure cluster credentials
sudo su bob -c "kubectl config set-cluster work --server=$(cat /home/bob/api.txt) --certificate-authority=/home/bob/keys/ca.crt --embed-certs=true"
sudo su bob -c "kubectl config set-credentials bob --client-certificate=/home/bob/keys/bob.crt --client-key=/home/bob/keys/bob.key"
sudo su bob -c "kubectl config set-context work --cluster=work --user=bob --namespace=testing"
sudo su bob -c "kubectl config use-context work"

exit 0
