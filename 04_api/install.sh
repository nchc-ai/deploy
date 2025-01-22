#!/bin/bash


# Image
DB_IMG=ghcr.io/nchc-ai/mysql
REDIS_IMG=ghcr.io/nchc-ai/rejson
API_IMG=ghcr.io/nchc-ai/backend-api


echo ""
echo "4-1. Create PVC for DB using storageclass $SYSTEM_SC_NAME"

cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: $NS_PREFIX-system
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $SYSTEM_SC_NAME
  resources:
    requests:
      storage: 1Gi
EOF


echo ""
echo "4-2. Install DB for API Server"

cat <<EOF | $KUBECTL apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twgc-database
  namespace: $NS_PREFIX-system
spec:
  selector:
    matchLabels:
      tier: mysql
  replicas: 1
  template:
    metadata:
      name: mysql-pod
      labels:
        tier: mysql
    spec:
      containers:
      - name: twgc-database
        image: $DB_IMG:$VERSION
        imagePullPolicy: $IMAGE_PULL_POLICY
        ports:
          - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: $DB_ROOT_PW
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        - name: twgc-database-init
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
      - name: twgc-database-init
        configMap:
          name: twgc-database-cm
          items:
          - key: database-init
            path: init.sql
---
apiVersion: v1
kind: Service
metadata:
  name: twgc-database-svc
  namespace: $NS_PREFIX-system
spec:
  ports:
    - port: 3306
  selector:
    tier: mysql
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-database-cm
  namespace: $NS_PREFIX-system
data:
  database-init: |-
    CREATE DATABASE $DB_DATABASE;
    CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PW';
    CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PW';
    GRANT ALL ON $DB_USER.* TO '$DB_USER'@'localhost';
    GRANT ALL ON $DB_USER.* TO '$DB_USER'@'%';
EOF



echo ""
echo "4-3. Prepare API Server configuration"





cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: twgc-api-cm
  namespace: $NS_PREFIX-system
data:
  api-conf: |-
    {
      "api-server": {
        "isOutsideCluster": false,
        "port": 38080,
        "enableSecureAPI": true,
        "namespacePrefix": "$NS_PREFIX",
        "uidRange": "$UID_RANGE",
        "provider": {
          "type": "go-oauth",
          "name": "test-provider",
          "client_id": "$CLIENT_ID",
          "client_secret": "$CLIENT_SECRET",
          "url": "http://oauth-server-svc.$NS_PREFIX-system:8080",
          "redirect_url": "https://$UI_URL/user/classroom-manage"
        }
      },
      "database": {
        "host": "twgc-database-svc.$NS_PREFIX-system",
        "port": 3306,
        "username": "$DB_USER",
        "password": "$DB_USER_PW",
        "database": "$DB_DATABASE"
      },
      "kubernetes": {
        "kubeconfig": "/etc/api-server/openstack-kubeconfig",
        "nodeportDNS": "http://$NODEPORT_URL",
        "storageclass": "$COURSE_SC_NAME"
      },
      "rfstack": {
        "enable": false,
        "url": "http://rfstack-svc.$NS_PREFIX-system:8088"
      },
      "redis": {
        "host": "twgc-redis-svc.$NS_PREFIX-system",
        "port": 6379
      }
    }
  api-conf-google: |-
    {
      "api-server": {
        "isOutsideCluster": false,
        "port": 38080,
        "enableSecureAPI": true,
        "namespacePrefix": "$NS_PREFIX",
        "uidRange": "$UID_RANGE",
        "provider": {
          "type": "google-oauth",
          "name": "google-provider",
          "client_id": "$CLIENT_ID",
          "client_secret": "$CLIENT_SECRET",
          "url": "http://oauth-server-svc.$NS_PREFIX-system:8080",
          "redirect_url": "https://$UI_URL/user/classroom-manage"
        }
      },
      "database": {
        "host": "twgc-database-svc.$NS_PREFIX-system",
        "port": 3306,
        "username": "$DB_USER",
        "password": "$DB_USER_PW",
        "database": "$DB_DATABASE"
      },
      "kubernetes": {
        "kubeconfig": "/etc/api-server/openstack-kubeconfig",
        "nodeportDNS": "http://$NODEPORT_URL",
        "storageclass": "$COURSE_SC_NAME"
      },
      "rfstack": {
        "enable": false,
        "url": "http://rfstack-svc.$NS_PREFIX-system:8088"
      },
      "redis": {
        "host": "twgc-redis-svc.$NS_PREFIX-system",
        "port": 6379
      }
    }
  api-conf-github: |-
    {
      "api-server": {
        "isOutsideCluster": false,
        "port": 38080,
        "enableSecureAPI": true,
        "namespacePrefix": "$NS_PREFIX",
        "uidRange": "$UID_RANGE",
        "provider": {
          "type": "github-oauth",
          "name": "github-provider",
          "client_id": "$CLIENT_ID",
          "client_secret": "$CLIENT_SECRET",
          "url": "http://oauth-server-svc.$NS_PREFIX-system:8080",
          "redirect_url": "https://$UI_URL/user/classroom-manage"
        }
      },
      "database": {
        "host": "twgc-database-svc.$NS_PREFIX-system",
        "port": 3306,
        "username": "$DB_USER",
        "password": "$DB_USER_PW",
        "database": "$DB_DATABASE"
      },
      "kubernetes": {
        "kubeconfig": "/etc/api-server/openstack-kubeconfig",
        "nodeportDNS": "http://$NODEPORT_URL",
        "storageclass": "$COURSE_SC_NAME"
      },
      "rfstack": {
        "enable": false,
        "url": "http://rfstack-svc.$NS_PREFIX-system:8088"
      },
      "redis": {
        "host": "twgc-redis-svc.$NS_PREFIX-system",
        "port": 6379
      }
    }
EOF


echo ""
echo "4-4. Install API server"

OAUTH_CONF_FILE="api-config-google.json"

case $OAUTH_TYPE in
      google-oauth) 
      OAUTH_CONF_FILE="api-config-google.json"
      ;;
      github-oauth) 
      OAUTH_CONF_FILE="api-config-github.json"
      ;;
      *) 
      echo "Not support value, use default config file $OAUTH_CONF_FILE" 
      ;;
 esac

 echo "Use $OAUTH_CONF_FILE"


cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: twgc-api-server
  namespace: $NS_PREFIX-system
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $NS_PREFIX-system-course-namespace-clusterrole
rules:
- apiGroups: ["nchc.ai"]
  resources: ["courses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["namespaces", "persistentvolumes", "persistentvolumeclaims","nodes"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["create"]
- apiGroups: ["security.openshift.io"]
  resourceNames: ["anyuid", "hostmount-anyuid"]
  resources: ["securitycontextconstraints"]
  verbs: ["use"]  
---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $NS_PREFIX-system-twgc-api-rolebinding-2
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $NS_PREFIX-system-course-namespace-clusterrole
subjects:
- kind: ServiceAccount
  namespace: $NS_PREFIX-system
  name: twgc-api-server

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $NS_PREFIX-system-twgc-api-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  namespace: $NS_PREFIX-system
  name: twgc-api-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twgc-api
  namespace: $NS_PREFIX-system
spec:
  selector:
    matchLabels:
      tier: api-server
  replicas: 1
  template:
    metadata:
      name: api-server
      labels:
        tier: api-server
    spec:
      serviceAccountName: twgc-api-server
      initContainers:
        - name: wait-for-mysql
          image: $DB_IMG:$VERSION
          imagePullPolicy: $IMAGE_PULL_POLICY
          command:
            - sh
            - -ec
            - |
              until mysql -h twgc-database-svc -u root -p$DB_ROOT_PW  --execute "SHOW DATABASES;"  > /dev/null 2>&1; do
                  if [ $? -ne 0 ]; then
                      echo "wait for DB ready"
                      sleep 5
                  fi
              done
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
            limits:
              cpu: 50m
              memory: 64Mi      
      containers:
      - name: twgc-api
        image: $API_IMG:$API_IMG_VER
        imagePullPolicy: $IMAGE_PULL_POLICY
        command: ['sh', '-c']
        args:
        - ln -s /etc/ssl/certs/nchc/chain.cert /etc/ssl/certs/chain.cert;
          /app --logtostderr=true --conf=/etc/api-server/$OAUTH_CONF_FILE
        ports:
        - containerPort: 38080
        volumeMounts:
        - name: twgc-api-conf
          mountPath: /etc/api-server/
        - name: nchc-cert
          mountPath: /etc/ssl/certs/nchc
      volumes:
      - name: twgc-api-conf
        configMap:
          name: twgc-api-cm
          items:
          - key: api-conf-google
            path: api-config-google.json
          - key: api-conf-github
            path: api-config-github.json
      - name: nchc-cert
        secret:
          secretName: nchc-tls-secret
          items:
          - key: tls.crt
            path: chain.cert
---
apiVersion: v1
kind: Service
metadata:
  name: twgc-api-svc
  namespace: $NS_PREFIX-system
spec:
  ports:
    - port: 38080
  selector:
    tier: api-server
EOF




echo ""
echo "4-5. Install Redis for API cache"

cat <<EOF | $KUBECTL apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twgc-redis-cache
  namespace: $NS_PREFIX-system
spec:
  selector:
    matchLabels:
      tier: redis
  replicas: 1
  template:
    metadata:
      name: redis-pod
      labels:
        tier: redis
    spec:
      containers:
      - name: twgc-redis-cache
        image: $REDIS_IMG:$VERSION
        imagePullPolicy: $IMAGE_PULL_POLICY
        ports:
          - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: twgc-redis-svc
  namespace: $NS_PREFIX-system
spec:
  ports:
    - port: 6379
  selector:
    tier: redis
EOF