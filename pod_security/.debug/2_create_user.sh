#!/bin/bash

# Retrieving cluster CA cert
mkdir -p ~/users/bob && cd ~/users/bob
awk '/certificate-authority-data:/{print $2}' ~/.kube/config | base64 -d > ca.crt

# Generate x509 CSR for bob
touch ~/.rnd && openssl genrsa -out bob.key 2048
openssl req -new -key bob.key -out bob.csr -subj "/CN=bob/O=mirantis/O=testers"

# Request the CSR to be signed
kubectl apply -f - << EOF
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: bob_csr
spec:
  groups:
  - system:authenticated
  request: $(cat bob.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

# Approve CSR
kubectl certificate approve bob_csr
kubectl get csr bob_csr -o jsonpath='{.status.certificate}' | base64 -d > bob.crt

# Create Linux user account and copy keys and certs to account
sudo useradd -b /home -m -s /bin/bash -c "I work here" bob
echo "bob:bob" | sudo chpasswd
sudo mkdir ~bob/keys && sudo cp -a ~/users/bob/*.{key,crt} ~bob/keys
sudo chmod 400 ~bob/keys/* && sudo chown -R bob:bob ~bob/keys


exit 0
