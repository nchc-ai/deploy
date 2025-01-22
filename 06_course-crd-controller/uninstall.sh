#!/bin/bash



echo ""
echo "Uninstall Course CRD Operator."

# namespace scoped object
$KUBECTL -n=$NS_PREFIX-system delete deployment course-operator
$KUBECTL -n=$NS_PREFIX-system delete cm course-operator-cm
$KUBECTL -n=$NS_PREFIX-system delete sa course-operator-sa


# cluster scoped object
# $KUBECTL -n=$NS_PREFIX-system delete crd courses.nchc.ai
$KUBECTL delete clusterrole $NS_PREFIX-system-course-operator-clusterrole $NS_PREFIX-system-course-operator-clusterrole-route
$KUBECTL delete clusterrolebinding $NS_PREFIX-system-course-operator-clusterrolebinding $NS_PREFIX-system-course-operator-clusterrolebinding-route
$KUBECTL delete crd courses.nchc.ai