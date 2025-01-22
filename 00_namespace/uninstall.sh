echo ""
echo "Remove Namespace"

NS_LIST=($NS_PREFIX-system $NS_PREFIX-teacher $NS_PREFIX-public)
if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
    echo ""
    for ns in "${NS_LIST[@]}"; do
        $KUBECTL delete -n=$ns role scc-role
        $KUBECTL delete -n=$ns rolebinding scc-role-binding
    done
fi

$KUBECTL delete ns $NS_PREFIX-system  $NS_PREFIX-public 

