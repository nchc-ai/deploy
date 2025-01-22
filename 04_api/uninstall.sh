#!/bin/bash


echo ""
echo "Uninstall API."

# namespace scoped object
$KUBECTL -n=$NS_PREFIX-system delete deployment twgc-database twgc-api twgc-redis-cache
$KUBECTL -n=$NS_PREFIX-system delete svc twgc-database-svc twgc-api-svc twgc-redis-svc
$KUBECTL -n=$NS_PREFIX-system delete cm twgc-database-cm twgc-api-cm
$KUBECTL -n=$NS_PREFIX-system delete sa twgc-api-server
$KUBECTL -n=$NS_PREFIX-system delete pvc mysql-pvc 

# cluster scoped object
$KUBECTL delete clusterrole $NS_PREFIX-system-course-namespace-clusterrole
$KUBECTL delete clusterrolebinding $NS_PREFIX-system-twgc-api-rolebinding-2 $NS_PREFIX-system-twgc-api-rolebinding