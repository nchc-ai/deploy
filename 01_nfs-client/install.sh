#!/bin/bash


PROVISIONER_IMG=ghcr.io/nchc-ai/nfs-client-provisioner

echo ""
echo "Install NFS provisioner for $SC_NAME"


echo ""
read -p "Enter NFS server IP [192.168.1.1]: " NFS_IP
NFS_IP=${NFS_IP:-192.168.1.1}

read -p "Enter NFS exposed path IP [/mnt/NFS]: " NFS_EXPOSE_PATH
NFS_EXPOSE_PATH=${NFS_EXPOSE_PATH:-/mnt/NFS}

echo "Please make NFS server and export path ($NFS_IP:$NFS_EXPOSE_PATH) are configured properly."
read -p "Press any key to continue..."

NAMESPACE=$NS_PREFIX-system
if [[ "$SYSTEM_SC_NAME" != "$COURSE_SC_NAME" && "$SC_NAME" == "$COURSE_SC_NAME" ]]; then
    NAMESPACE=$NS_PREFIX-course-provisioner
fi

cat <<EOF | $KUBECTL apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $SC_NAME
provisioner: $NAMESPACE/nfs
parameters:
  archiveOnDelete: "$ARCHIVE"
EOF

echo ""
read -p "Is $SC_NAME default provisioner ? [Y/N] " IS_DEFAULT_SC

 case $IS_DEFAULT_SC in
      Y) 
      $KUBECTL patch sc $SC_NAME -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
      ;;
      N) 
      $KUBECTL patch sc $SC_NAME -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
      ;;
      *) 
      echo "not support value, set not-default provisioner" 
      $KUBECTL patch sc $SC_NAME -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' ;;
 esac



echo ""
echo "1-2. Setup RBAC"


cat <<EOF | $KUBECTL apply -f -
kind: ServiceAccount
apiVersion: v1
metadata:
  namespace: $NAMESPACE
  name: nfs-client-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $NAMESPACE-nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete", "update"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-$NAMESPACE-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: $NAMESPACE-nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $NAMESPACE
  name: leader-locking-nfs-client-provisioner
rules:
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $NAMESPACE
  name: leader-locking-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: $NAMESPACE
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF



echo ""
echo "1-3. Install provisioner"

cat <<EOF | $KUBECTL apply -f -
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-client-provisioner
  namespace: $NAMESPACE
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: $PROVISIONER_IMG:$PROVISIONER_IMG_VER
          imagePullPolicy: $IMAGE_PULL_POLICY
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: $NAMESPACE/nfs
            - name: NFS_SERVER
              value: $NFS_IP
            - name: NFS_PATH
              value: $NFS_EXPOSE_PATH
      volumes:
        - name: nfs-client-root
          nfs:
            server: $NFS_IP
            path: $NFS_EXPOSE_PATH
EOF




if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
    echo ""
    echo "1-4. Set scc to hostmount-anyuid"
    $KUBECTL adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
fi



