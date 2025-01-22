#!/bin/bash



echo ""
echo "Select destion Cluster type"
echo "OpenShift : 1"
echo "Kubernetes: 2"


read -p "Enter your destion cluster type: " DEST_CLUSTER_INPUT

export KUBECTL="kubectl"
export DEST_CLUSTER_TYPE="K8S"

case $DEST_CLUSTER_INPUT in
      1) 
      KUBECTL="oc"
      DEST_CLUSTER_TYPE="OCP"
      echo "Uninstall from OCP"
      ;;
      2) 
      KUBECTL="kubectl"
      DEST_CLUSTER_TYPE="K8S"
      echo "Uninstall from K8S"
      ;;
      *) 
      echo "Not support value, exit..."
      exit ;;
esac


echo ""
read -p "Enter system storageclass to remove [nchc-ai-nfs]: " SYSTEM_SC_NAME
export SYSTEM_SC_NAME=${SYSTEM_SC_NAME:-nchc-ai-nfs}


echo ""
read -p "Enter namespace prefix [aitrain]: " NS_PREFIX
export NS_PREFIX=${NS_PREFIX:-aitrain}



TO_REMOVE_NS=(`$KUBECTL get ns --no-headers -o custom-columns=":metadata.name" | grep -E "$NS_PREFIX-[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}|$NS_PREFIX-teacher"`)
echo "Will remove still running course, then remove classroom namespace: "
echo ""
for ns in "${TO_REMOVE_NS[@]}"; do
    echo "$ns"
done
echo ""
read -p "Press any key to continue..."

  
for ns in "${TO_REMOVE_NS[@]}"; do

    echo "deleting classroom $ns"

    # delete course pod
    TO_REMOVE_COURSE=(`$KUBECTL get -n=$ns course --no-headers -o custom-columns=":metadata.name"`)
    for course in "${TO_REMOVE_COURSE[@]}"; do
        echo "  delete course $course/$ns"
        $KUBECTL -n=$ns delete course $course > /dev/null 2>&1
    done

    # delete pvc & pv used by course
    TO_REMOVE_PVC=(`$KUBECTL get -n=$ns pvc --no-headers -o custom-columns=":metadata.name"`)
    for pvc in "${TO_REMOVE_PVC[@]}"; do
        echo "  delete pvc $pvc/$ns"
        $KUBECTL -n=$ns delete pvc $pvc > /dev/null 2>&1
    done

    # delete namespace
    $KUBECTL delete ns $ns > /dev/null 2>&1
    echo "classroom $ns deleted"
done


echo ""
echo "Will remove all resources in $NS_PREFIX-system, $NS_PREFIX-public"
read -p "Press any key to continue..."


bash ./08_admin-signup-ui/uninstall.sh
bash ./07_ui/uninstall.sh
bash ./06_course-crd-controller/uninstall.sh
bash ./04_api/uninstall.sh
bash ./01_nfs-client/uninstall.sh
bash ./00_namespace/uninstall.sh
