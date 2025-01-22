#!/bin/bash

UI_IMG=ghcr.io/nchc-ai/ui

echo ""
echo "Install Web UI"

echo ""
echo "7-1. Prepare Configuration"



cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-ui-cm
  namespace: $NS_PREFIX-system
data:
  endpoint-conf: |-
    export const WEBSITE_URL = 'https://$UI_URL';
    export const API_URL = '/api';
    export const API_VERSION = 'beta';
    export const API_VM_URL = ''
    export const API_VM_VERSION = 'v1';
    export const API_MOCK_URL = 'http://localhost:3000'
    export const AUTH_PROVIDER_URL = 'https://$OAUTH_SERVER_URL';
    export const RETURN_ROUTE = '/user/classroom-manage';
    export const JOB_INTERVAL = 10000;
    export const pdfLink = 'https://drive.google.com/file/d/1MvfNxfLkBr4yvbxsJhh-D6PeaFsovNPl/view'
    export const APPLY_ADMIN_LINK = 'https://docs.google.com/forms/d/e/1FAIpQLSccwgqH5a0sA9-UriWS5atlmQ8X4uzdbYl57eLF8S-NbodHHg/viewform'
    export const ENABLE_RFSTACK = false
    export const OAUTH_PROVIDER = '$OAUTH_TYPE'
    export const OAUTH_CLIENT_ID = '$CLIENT_ID'
EOF


echo ""
echo "7-2. Install UI"

K8S_DNS_SERVER="10.96.0.10"

if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
  K8S_DNS_SERVER="172.30.0.10"
fi

cat <<EOF | $KUBECTL apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twgc-ui
  namespace: $NS_PREFIX-system
spec:
  selector:
    matchLabels:
      tier: twgc-ui
  replicas: 1
  template:
    metadata:
      name: twgc-ui
      labels:
        tier: twgc-ui
    spec:
      containers:
        # use nginx to serve built page
        - name: twgc-nginx
          image: nginx:1.15-alpine
          ports:
            - containerPort: 3010
          volumeMounts:
            - name: twgc-nginx-conf
              mountPath: /etc/nginx/conf.d
            - name: dist
              mountPath: /usr/share/nginx/html
      initContainers:
        # some configuration is stored in configMap, we need a initContainer to build before serve
        - name: twgc-ui
          image: $UI_IMG:$UI_IMG_VER
          imagePullPolicy: $IMAGE_PULL_POLICY
          command: ["sh", "-c", "yarn build"]
          volumeMounts:
            - name: twgc-ui-conf
              mountPath: /src/github.com/nchc-ai/aitrain-ui/app/config/
            - name: dist
              mountPath: /tmp/dist
      volumes:
        - name: twgc-ui-conf
          configMap:
            name: twgc-ui-cm
            items:
              - key: endpoint-conf
                path: api.js
        - name: twgc-nginx-conf
          configMap:
            name: twgc-nginx-cm
            items:
              - key: nginx-conf
                path: default.conf
        - name: dist
          emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: twgc-ui
  namespace: $NS_PREFIX-system
spec:
  ports:
    - port: 3010
  selector:
    tier: twgc-ui
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-nginx-cm
  namespace: $NS_PREFIX-system
data:
  nginx-conf: |-
    server {
        listen       3010;
        server_name  localhost;

        # avoid proxy_pass DNS cache
        # https://www.jianshu.com/p/b2df15133d12
        resolver     $K8S_DNS_SERVER;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;

            # fix Single Page Application cannot found when proxy
            # https://stackoverflow.com/questions/32593739/nginx-config-for-single-page-app-with-html5-app-cache
            try_files \$uri /index.html =404;
        }

        # proxy /api/beta/* apis to api-server server
        set \$ctr_proxy_pass_url http://twgc-api-svc.$NS_PREFIX-system.svc.cluster.local:38080;
        location /api {
            proxy_pass \$ctr_proxy_pass_url;
        }

        # proxy /v1/* apis to rfstack server
        set \$vm_proxy_pass_url  http://rfstack-svc.$NS_PREFIX-system.svc.cluster.local:8088;
        location /v1 {
            proxy_pass \$vm_proxy_pass_url;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
EOF



echo ""
echo "7-3. Setup Ingress"

cat <<EOF | $KUBECTL apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aitrain-ingress
  namespace: $NS_PREFIX-system
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
    - host: $UI_URL
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: twgc-ui
                port: 
                  number: 3010
  tls:
    - secretName: nchc-tls-secret
      hosts:
        - $UI_URL
EOF

echo ""
echo "Use https://$UI_URL access web UI."