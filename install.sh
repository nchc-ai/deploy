#!/bin/bash

generate_random_password() {
    local password_length=$1
    if [[ -z "$password_length" || "$password_length" -lt 1 ]]; then
        echo "Usage: generate_random_password <length>"
        return 1
    fi

    # Define the character set for the password
    local charset='A-Za-z0-9'

    # Generate the password
    local password=$(LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$password_length")

    echo "$password"
}

# Edit patch image tag here. For now, only 4 images are support
API_IMG_VER=
UI_IMG_VER=
COURSE_IMG_VER=
PROVISIONER_IMG_VER=

RANDOM_PW=$(generate_random_password 8)

# Database Credential
export DB_ROOT_PW=$RANDOM_PW
export DB_USER=user
export DB_USER_PW=$RANDOM_PW
export DB_DATABASE=user

export IMAGE_PULL_POLICY=Always

echo " ============================================= "
echo " =         Configure Global variable         = "
echo " ============================================= "

echo ""
echo "Select destion Cluster type"
echo "OpenShift:  1"
echo "Kubernetes: 2"

read -p "Enter your destion cluster type: " DEST_CLUSTER_INPUT

export DEST_CLUSTER_TYPE="OCP"
export KUBECTL="oc"

case $DEST_CLUSTER_INPUT in
1)
    DEST_CLUSTER_TYPE="OCP"
    KUBECTL="oc"
    echo "Install to OCP"
    ;;
2)
    DEST_CLUSTER_TYPE="K8S"
    KUBECTL="kubectl"
    echo "Install to K8S"
    ;;
*)
    echo "Not support value, use default type $DEST_CLUSTER_TYPE"
    ;;
esac

echo ""
LAST_VER="v2025.02"
export VERSION
read -p "Enter installation version [ v2025.02 ]: " VERSION

case $VERSION in
v2025.02) ;;
*)
    VERSION=$LAST_VER
    echo "not valid version, use $VERSION for default version."
    ;;
esac

echo ""
read -p "Enter namespace prefix [aitrain]: " NS_PREFIX
export NS_PREFIX=${NS_PREFIX:-aitrain}

export IS_USE_EXISTING_SC=Y
echo ""
read -p "Do you want to use existing storage class ? [ Y/N ]: " IS_USE_EXISTING_SC
case $IS_USE_EXISTING_SC in
Y)
    echo ""
    read -p "Enter existing storageclass name [ standard ]: " EXISTING_SC_NAME
    export SYSTEM_SC_NAME=${EXISTING_SC_NAME:-standard}
    export COURSE_SC_NAME=${EXISTING_SC_NAME:-standard}
    ;;
N)
    echo ""
    read -p "Enter storageclass suffix for *SYSTEM* data [nchc-ai-nfs]: " SYSTEM_SC_NAME
    export SYSTEM_SC_NAME=$NS_PREFIX-${SYSTEM_SC_NAME:-nchc-ai-nfs}
    echo "Warning: $SYSTEM_SC_NAME will be created."

    echo ""
    read -p "Enter storageclass suffix for *COURSE* data [nchc-ai-nfs]: " COURSE_SC_NAME
    export COURSE_SC_NAME=$NS_PREFIX-${COURSE_SC_NAME:-nchc-ai-nfs}
    ;;
*)
    echo "not support value, use existing storageclass by default."
    echo ""
    read -p "Enter existing storageclass name [ standard ]: " EXISTING_SC_NAME
    export SYSTEM_SC_NAME=${EXISTING_SC_NAME:-standard}
    export COURSE_SC_NAME=${EXISTING_SC_NAME:-standard}
    ;;
esac

export IS_INSTALL_COURSE_PROVISIONER=N
if [[ "$SYSTEM_SC_NAME" != "$COURSE_SC_NAME" ]]; then
    echo ""
    read -p "Do you want to install nfs provisioner for course ? [ Y/N ]: " IS_INSTALL_COURSE_PROVISIONER
    case $IS_INSTALL_COURSE_PROVISIONER in
    Y) ;;
    N)
        echo "Warning: $COURSE_SC_NAME will NOT be created. You must prepare $COURSE_SC_NAME storageclass first."
        ;;
    *)
        echo "not support value, not install course nfs provisioner by default."
        IS_INSTALL_COURSE_PROVISIONER=N
        ;;
    esac
fi

echo ""
read -p "Enter URL domian [nchc.org.tw]: " DOAMINNAME
export DOAMINNAME=${DOAMINNAME:-nchc.org.tw}

echo ""
DEFAULT_URL="${VERSION/./-}-$NS_PREFIX-ui.$DOAMINNAME"
DEFAULT_URL=$(echo $DEFAULT_URL | tr '[:upper:]' '[:lower:]')
read -p "Enter URL for Web UI [$DEFAULT_URL]: " UI_URL
export UI_URL=${UI_URL:-$DEFAULT_URL}

echo ""
DEFAULT_URL="${VERSION/./-}-$NS_PREFIX-nodeport.$DOAMINNAME"
DEFAULT_URL=$(echo $DEFAULT_URL | tr '[:upper:]' '[:lower:]')
read -p "Enter NodePort Endpoint [$DEFAULT_URL]: " NODEPORT_URL
export NODEPORT_URL=${NODEPORT_URL:-$DEFAULT_URL}

echo ""
DEFAULT_URL="${VERSION/./-}-$NS_PREFIX-admin.$DOAMINNAME"
DEFAULT_URL=$(echo $DEFAULT_URL | tr '[:upper:]' '[:lower:]')
read -p "Enter URL for admin UI  [$DEFAULT_URL]: " ADMIN_UI_URL
export ADMIN_UI_URL=${ADMIN_UI_URL:-$DEFAULT_URL}

echo ""
read -p "Enter your OAuth provider type [ google-oauth | github-oauth ]: " OAUTH_TYPE

case $OAUTH_TYPE in
google-oauth) ;;
github-oauth) ;;
*)
    echo "Not support value, use default OAuth type: google-oauth"
    OAUTH_TYPE=google-oauth
    ;;
esac

export OAUTH_TYPE

# OAuth Credential

echo ""
read -p "Enter your OAuth client ID for $OAUTH_TYPE: " CLIENT_ID

if [ -z "$CLIENT_ID" ]; then
    echo "Error: CLIENT_ID is empty"
    exit 1
fi

export CLIENT_ID

echo ""
read -p "Enter your OAuth client Secret for $OAUTH_TYPE: " CLIENT_SECRET

# check if CLIENT_SECRET is empty
if [ -z "$CLIENT_SECRET" ]; then
    echo "Error: CLIENT_SECRET is empty"
    exit 1
fi

export CLIENT_SECRET

echo ""
read -p "Please enter ingress class name. [ nginx ]: " INGRESS_CLASS
export INGRESS_CLASS=${INGRESS_CLASS:-nginx}

echo ""
read -p "Please enter start UID number, use \" 0 \" disable UID support in container. [ 2000620000 ]: " UID_START
UID_START=${UID_START:-2000620000}

read -p "Please enter # of UID [ 100000 ]: " UID_COUNT
UID_COUNT=${UID_COUNT:-100000}

export UID_RANGE="$UID_START/$UID_COUNT"

echo ""
echo " ============================================= "
echo " =    Following variable will be used        = "
echo " =    during installation, Please confirm.   = "
echo " ============================================= "
echo ""
echo "Destion Cluster Type           : $DEST_CLUSTER_TYPE"
echo "Domain Name                    : $DOAMINNAME"
echo "Web UI URL                     : $UI_URL"
echo "Nodeport endpoint              : $NODEPORT_URL"
echo "Admin UI URL                   : $ADMIN_UI_URL"
echo "Namespace prefix               : $NS_PREFIX"
echo "Storage Class for system       : $SYSTEM_SC_NAME"
echo "Storage Class for course       : $COURSE_SC_NAME"
echo "Ingress Class Name             : $INGRESS_CLASS"
echo "Installation Version           : $VERSION"
echo "UID range                      : $UID_RANGE"
echo "Install course NFS provisioner : $IS_INSTALL_COURSE_PROVISIONER"
echo "Generated Random DB Password   : $RANDOM_PW"
echo "OAuth2 Provider                : $OAUTH_TYPE"
echo "OAuth2 Client ID               : $CLIENT_ID"
echo "OAuth2 Client Secret           : $CLIENT_SECRET"

echo ""
echo " Storage Class \"$SYSTEM_SC_NAME\" will be created."

if [[ ! -z $API_IMG_VER || ! -z $UI_IMG_VER || ! -z $COURSE_IMG_VER || ! -z $PROVISIONER_IMG_VER ]]; then
    export API_IMG_VER=${API_IMG_VER:-$VERSION}
    export UI_IMG_VER=${UI_IMG_VER:-$VERSION}
    export COURSE_IMG_VER=${COURSE_IMG_VER:-$VERSION}
    export PROVISIONER_IMG_VER=${PROVISIONER_IMG_VER:-$VERSION}
    echo ""
    echo " Some Patched image version are found: "
    echo "  API              Image: $API_IMG_VER"
    echo "  UI               Image: $UI_IMG_VER"
    echo "  Course CRD       Image: $COURSE_IMG_VER"
    echo "  nfs provisioner  Image: $PROVISIONER_IMG_VER"
else
    export API_IMG_VER=$VERSION
    export UI_IMG_VER=$VERSION
    export COURSE_IMG_VER=$VERSION
    export PROVISIONER_IMG_VER=$VERSION
fi

echo ""
echo " ============================================= "
echo " =   Press any key to start installatiom.    = "
read -p " ============================================= "

export SC_NAME=$SYSTEM_SC_NAME
export ARCHIVE=false
bash ./00_namespace/install.sh

if [ $IS_USE_EXISTING_SC = "N" ]; then
    bash ./01_nfs-client/install.sh
    if [[ "$SYSTEM_SC_NAME" != "$COURSE_SC_NAME" && $IS_INSTALL_COURSE_PROVISIONER == "Y" ]]; then
        echo ""
        export SC_NAME=$COURSE_SC_NAME
        export ARCHIVE=true
        bash ./01_nfs-client/install.sh
    fi
fi

bash ./04_api/install.sh
bash ./06_course-crd-controller/install.sh
bash ./07_ui/install.sh
bash ./08_admin-signup-ui/install.sh
