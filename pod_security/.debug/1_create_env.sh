#!/bin/bash

# Creating testing namespace
kubectl create namespace testing

# Creating testing-role
kubectl apply -f - << EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tester
  namespace: testing
rules:
- apiGroups: ["", "batch", "autoscaling", "extensions", "apps",]
  resources:
  - "statefulsets"
  - "horizontalpodautoscalers"
  - "jobs"
  - "replicationcontrollers"
  - "services"
  - "deployments"
  - "replicasets"
  - "pods"
  - "pods/attach"
  - "pods/log"
  - "pods/exec"
  - "pods/proxy"
  - "pods/portforward"
  verbs:  ["*"]
EOF

# Creating role binding
kubectl apply -f - << EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tester-binding
  namespace: testing
subjects:
- kind: Group
  name: testers
  apiGroup: ""
roleRef:
  kind: Role
  name: tester
  apiGroup: ""
EOF

exit 0
