#!/bin/bash

echo ""
echo "Uninstall NFS-client provisioner"

NS_LIST=($NS_PREFIX-system)
SC_LIST=($SYSTEM_SC_NAME)

echo ""
read -p "Enter course storageclass to remove, keep empty to skip: " COURSE_SC_NAME
export COURSE_SC_NAME=${COURSE_SC_NAME:-}

if [ ! -z $COURSE_SC_NAME ]; then
    NS_LIST+=($NS_PREFIX-course-provisioner)
    SC_LIST+=($COURSE_SC_NAME)
fi



for ns in "${NS_LIST[@]}"; do
# namespace scoped object
$KUBECTL -n=$ns delete deployment nfs-client-provisioner
$KUBECTL -n=$ns delete sa nfs-client-provisioner
$KUBECTL -n=$ns delete role leader-locking-nfs-client-provisioner
$KUBECTL -n=$ns delete rolebinding  leader-locking-nfs-client-provisioner

# remove ssc in OCP
if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
    $KUBECTL adm policy remove-scc-from-user hostmount-anyuid system:serviceaccount:$ns:nfs-client-provisioner
fi
done


# cluster scoped object
for ns in "${NS_LIST[@]}"; do
$KUBECTL delete clusterrole $ns-nfs-client-provisioner-runner
$KUBECTL delete clusterrolebinding run-$ns-nfs-client-provisioner
done

for sc in "${SC_LIST[@]}"; do
$KUBECTL delete sc $sc
done

if [ ! -z $COURSE_SC_NAME ]; then
    $KUBECTL delete ns $NS_PREFIX-course-provisioner
fi