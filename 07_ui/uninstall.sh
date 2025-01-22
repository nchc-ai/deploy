#!/bin/bash



echo ""
echo "Uninstall Web UI"

$KUBECTL -n=$NS_PREFIX-system delete deployment twgc-ui
$KUBECTL -n=$NS_PREFIX-system delete svc twgc-ui
$KUBECTL -n=$NS_PREFIX-system delete ingress aitrain-ingress
$KUBECTL -n=$NS_PREFIX-system delete cm twgc-ui-cm twgc-nginx-cm