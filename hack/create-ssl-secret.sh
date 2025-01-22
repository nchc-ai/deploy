#!/usr/bin/env bash

kubectl -n=aitrain-system create secret tls nchc-tls-secret --dry-run=client \
--key ./nchc-ssl.key \
--cert ./chain.crt \
-o yaml > nchc-tls-secret.yaml
