#!/bin/bash


echo ""
echo "Uninstall Admin UI"

$KUBECTL -n=$NS_PREFIX-system delete deployment twgc-signup-ui
$KUBECTL -n=$NS_PREFIX-system delete svc twgc-signup-ui-svc
$KUBECTL -n=$NS_PREFIX-system delete ingress twgc-signup-ui-ingress
$KUBECTL -n=$NS_PREFIX-system delete cm twgc-signup-ui-cm twgc-signup-nginx-cm