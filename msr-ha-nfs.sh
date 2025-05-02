#!/bin/bash

set -euo pipefail

# CONFIGURATION
NAMESPACE="rook-nfs"
PV_NAME="nfs-backing-pv"
PVC_NAME="nfs-pvc"
NFS_SERVER_NAME="mynfs"
NFS_EXPORT_NAME="share1"
NFS_HOSTPATH="/mnt/data/nfs"
NFS_STORAGE="5Gi"
SC_NAME="nfs-client"
HELM_RELEASE_NAME="nfs-client"

# Step 2: Create hostPath directory on node
echo "Creating hostPath on local node (requires sudo)..."
sudo mkdir -p $NFS_HOSTPATH
sudo chmod 777 $NFS_HOSTPATH

# Step 3: Create PV
echo "Applying PersistentVolume..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $PV_NAME
spec:
  capacity:
    storage: $NFS_STORAGE
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: $NFS_HOSTPATH
EOF

# Step 3.5: Create namespace if needed
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE

# Step 3: Create PVC
echo "Creating backing PVC for NFSServer..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $NFS_STORAGE
  volumeName: $PV_NAME
EOF

# Step 4: Deploy NFSServer CR
echo "Deploying Rook NFS Server..."
cat <<EOF | kubectl apply -f -
apiVersion: nfs.rook.io/v1alpha1
kind: NFSServer
metadata:
  name: $NFS_SERVER_NAME
  namespace: $NAMESPACE
spec:
  replicas: 1
  exports:
    - name: $NFS_EXPORT_NAME
      server:
        accessMode: ReadWriteMany
        squash: "none"
      persistentVolumeClaim:
        claimName: $PVC_NAME
EOF

# Wait for NFS Service to be ready
echo "Waiting for NFS service to become available..."
sleep 10
NFS_SERVICE_IP=""
for i in {1..30}; do
  NFS_SERVICE_IP=$(kubectl get svc -n $NAMESPACE | grep $NFS_SERVER_NAME | awk '{print $3}')
  if [[ "$NFS_SERVICE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "NFS service IP: $NFS_SERVICE_IP"
    break
  fi
  echo "Waiting for NFS service... retrying ($i/30)"
  sleep 5
done

if [ -z "$NFS_SERVICE_IP" ]; then
  echo "❌ Failed to retrieve NFS service IP"
  exit 1
fi

# Step 6: Install external NFS provisioner
echo "Installing NFS Subdir External Provisioner via Helm..."
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

helm upgrade --install $HELM_RELEASE_NAME nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server="$NFS_SERVICE_IP" \
  --set nfs.path="/export/$NFS_EXPORT_NAME" \
  --set storageClass.name=$SC_NAME \
  --set storageClass.defaultClass=true
