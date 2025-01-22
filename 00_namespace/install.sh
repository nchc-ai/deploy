#!/bin/bash

echo ""
echo "0-1. Create namespace"


cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NS_PREFIX-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: $NS_PREFIX-public
  labels:
    instance: $NS_PREFIX
---
apiVersion: v1
kind: Namespace
metadata:
  name: $NS_PREFIX-teacher
  labels:
    instance: $NS_PREFIX
---
EOF


if [[ "$SYSTEM_SC_NAME" != "$COURSE_SC_NAME" ]]; then
cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NS_PREFIX-course-provisioner
EOF
fi

echo ""
echo "0-3. Create TLS Secret"

DEFAULT_PATH_KEY=(`ls ./hack/*.key`)
read -p "Enter file path to TLS key  [${DEFAULT_PATH_KEY[*]}]: " PATH_KEY
PATH_KEY=${PATH_KEY:-$DEFAULT_PATH_KEY}


DEFAULT_PATH_CERT=(`ls ./hack/*.crt`)
read -p "Enter file path to cert     [${DEFAULT_PATH_CERT[*]}]: " PATH_CERT
PATH_CERT=${PATH_CERT:-$DEFAULT_PATH_CERT}

echo "Use $PATH_KEY & $PATH_CERT create secret. "
read -p "Enter any key to continue..."


NS_LIST=($NS_PREFIX-system $NS_PREFIX-teacher $NS_PREFIX-public)
  
for ns in "${NS_LIST[@]}"; do
    $KUBECTL -n=$ns create secret tls nchc-tls-secret --dry-run=client \
    --key $PATH_KEY \
    --cert $PATH_CERT \
    -o yaml | $KUBECTL apply -f -
done


if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
    echo ""
    echo "0-4. Set scc to anyuid to run as root"
    for ns in "${NS_LIST[@]}"; do
cat <<EOF | $KUBECTL apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $ns
  name: scc-role
rules:
  - apiGroups: ["security.openshift.io"]
    resourceNames: ["anyuid", "hostmount-anyuid"]
    resources: ["securitycontextconstraints"]
    verbs: ["use"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: $ns
  name: scc-role-binding
subjects:
  - kind: ServiceAccount
    name: default
    namespace: $ns
roleRef:
  kind: Role
  name: scc-role
  apiGroup: rbac.authorization.k8s.io
EOF
    done
fi