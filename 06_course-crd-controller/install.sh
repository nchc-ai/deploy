#!/bin/bash


COURSE_CRD_IMG=ghcr.io/nchc-ai/course-operator
DB_IMG=ghcr.io/nchc-ai/mysql


echo ""
echo "6-1. Install Course CRD operator"


cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: course-operator-cm
  namespace: $NS_PREFIX-system
data:
  course-operator-conf: |-
    {
      "isOutsideCluster": false,
      "ingressBaseUrl": "$DOAMINNAME",
      "ingressClass": "$INGRESS_CLASS",
      "database": {
        "host": "twgc-database-svc.$NS_PREFIX-system",
        "port": 3306,
        "username": "$DB_USER",
        "password": "$DB_USER_PW",
        "database": "$DB_DATABASE"
      },
      "redis": {
        "host": "twgc-redis-svc.$NS_PREFIX-system",
        "port": 6379
      }
    }
EOF


cat <<EOF | $KUBECTL apply -f -
---
# Course CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: courses.nchc.ai
spec:
  group: nchc.ai
  names:
    kind: Course
    plural: courses
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                image:
                  type: string
                accessType:
                  type: string
                  enum:
                    - "Ingress"
                    - "NodePort"
                  default: "Ingress"
                gpu:
                  type: integer
                  minimum: 0
                  maximum: 8
                  default: 0
                schedule:
                  type: array
                  items:
                    type: string
                dataset:
                  type: array
                  items:
                    type: string
                port:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                writableVolume:
                  type: object
                  properties:
                    owner:
                      type: string
                    storageclass:
                      type: string
                    mountPoint:
                      type: string
                    uid:
                      type: integer
              required:
                - image
                - schedule
                - accessType
                - port
            status:
              type: object
              properties:
                service:
                  type: string
                accessible:
                  type: boolean
                subPath:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                nodePort:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true                     
      subresources:
        status: {}                
      additionalPrinterColumns:
        - name: AccessType
          type: string
          description: The cron spec defining the interval a CronJob is run
          jsonPath: .spec.accessType
        - name: Gpu
          type: integer
          description: The number of jobs launched by the CronJob
          jsonPath: .spec.gpu
        - name: owner
          type: string
          description: The number of jobs launched by the CronJob
          jsonPath: .spec.writableVolume.owner
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
---
# operator deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: course-operator
  namespace: $NS_PREFIX-system
spec:
  replicas: 1
  selector:
    matchLabels:
      operator: course
  template:
    metadata:
      labels:
        operator: course
    spec:
      serviceAccountName: course-operator-sa
      initContainers:
        - name: wait-for-mysql
          image: $DB_IMG:$VERSION
          imagePullPolicy: $IMAGE_PULL_POLICY
          command:
            - sh
            - -ec
            - |
              until mysql -h twgc-database-svc -u $DB_USER -p$DB_USER_PW  --execute "use $DB_DATABASE;"  > /dev/null 2>&1; do
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
      - name: course-operator
        image: $COURSE_CRD_IMG:$COURSE_IMG_VER
        imagePullPolicy: $IMAGE_PULL_POLICY
        volumeMounts:
        - name: course-operator-conf
          mountPath: /etc/course-operator
      volumes:
      - name: course-operator-conf
        configMap:
          name: course-operator-cm
          items:
          - key: course-operator-conf
            path: config.json

---
# service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: course-operator-sa
  namespace: $NS_PREFIX-system
---
# ClusterRole
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $NS_PREFIX-system-course-operator-clusterrole
rules:
- apiGroups: ["nchc.ai"]
  resources: ["courses", "courses/finalizers","courses/status"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments", "deployments/finalizers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]  
- apiGroups: [""]
  resources: ["events", "services", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["route.openshift.io"]
  resources: ["routes", "routes/custom-host"]
  verbs:  ["create", "patch"]  
---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $NS_PREFIX-system-course-operator-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $NS_PREFIX-system-course-operator-clusterrole
subjects:
- kind: ServiceAccount
  name: course-operator-sa
  namespace: $NS_PREFIX-system
EOF

if [ $DEST_CLUSTER_TYPE = "OCP" ]; then

cat <<EOF | $KUBECTL apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $NS_PREFIX-system-course-operator-clusterrole-route
rules:
- apiGroups: ["route.openshift.io"]
  resources: ["routes", "routes/custom-host"]
  verbs:  ["create", "patch"]  
---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $NS_PREFIX-system-course-operator-clusterrolebinding-route
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $NS_PREFIX-system-course-operator-clusterrole-route
subjects:
- kind: ServiceAccount
  name: course-operator-sa
  namespace: $NS_PREFIX-system
EOF

fi