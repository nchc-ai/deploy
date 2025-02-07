# How to setup AI Platform

## Deploy in localhost 

### Prerequisite

* Place a TLS certificate in `hack/` (including both key and crt file)
* Prepare a OAuth Client ID and Secret from Google or GitHub. 
  * [Google OAuth Reference Video](https://youtu.be/75brbKarbn0?t=72)
  * [Github OAuth Reference Video](https://youtu.be/Bx1JqfPROXA?t=230)
  * Authorization callback URL has form of `https://<FQDN>/user/classroom-manage`
* Install [KinD](https://kind.sigs.k8s.io/docs/user/ingress/#option-2-extraportmapping) with  ingress enabled.
* Prepare a NFS for storing course data. You can create a NFS contianer and connect it to the network which KinD used, the used default network is `kind`.

  For exanple, 
  ```bash
  docker run -d -v /nfs -e NFS_EXPORT_0='/nfs *(rw,sync,no_root_squash,no_all_squash,fsid=1)' --cap-add SYS_ADMIN --network kind erichough/nfs-server
  ```


### Build and load Image

```bash
cd  00_build
make
```

### Installation

```bash
./install.sh
```

 


