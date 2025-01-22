#!/bin/bash





ADMIN_UI_IMAGE=ghcr.io/nchc-ai/ui-signup
ADMIN_UI=twgc-signup-ui
ADMIN_UI_SVC=$ADMIN_UI-svc

echo ""
echo "8-1. Install admin web page"



K8S_DNS_SERVER="10.96.0.10"

if [ $DEST_CLUSTER_TYPE = "OCP" ]; then
  K8S_DNS_SERVER="172.30.0.10"
fi


cat <<EOF | $KUBECTL apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $ADMIN_UI
  namespace: $NS_PREFIX-system
spec:
  selector:
    matchLabels:
      tier: twgc-signup-ui
  replicas: 1
  template:
    metadata:
      name: twgc-signup-ui
      labels:
        tier: twgc-signup-ui
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
      - name: twgc-signup-ui
        image: $ADMIN_UI_IMAGE:$VERSION
        imagePullPolicy: $IMAGE_PULL_POLICY
        command: ["sh", "-c","yarn build"]
        volumeMounts:
        - name: twgc-ui-conf
          mountPath: /src/github.com/nchc-ai/aitrain-ui-signup/app/config/
        - name: dist
          mountPath: /tmp/dist
      volumes:
      - name: twgc-ui-conf
        configMap:
          name: twgc-signup-ui-cm
          items:
          - key: endpoint-conf
            path: api.js
      - name: twgc-nginx-conf
        configMap:
          name: twgc-signup-nginx-cm
          items:
          - key: nginx-conf
            path:  default.conf
      - name: dist
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: $ADMIN_UI_SVC
  namespace: $NS_PREFIX-system
spec:
  ports:
    - port: 3010
  selector:
    tier: twgc-signup-ui
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-signup-ui-cm
  namespace: $NS_PREFIX-system
data:
  endpoint-conf: |-
    export const API_URL = '/api';
    export const API_VERSION = 'beta';
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-signup-nginx-cm
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


        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
EOF


cat <<EOF | $KUBECTL apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $ADMIN_UI-ingress
  namespace: $NS_PREFIX-system
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
    - host: $ADMIN_UI_URL
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: $ADMIN_UI_SVC
                port: 
                  number: 3010
  tls:
    - secretName: nchc-tls-secret
      hosts:
        - $ADMIN_UI_URL
EOF



echo "Use https://$ADMIN_UI_URL access admin web console"