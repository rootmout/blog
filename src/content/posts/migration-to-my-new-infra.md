+++
draft = false
date = 2022-03-09T10:13:46+01:00
title = "Migration to my new infra"
description = ""
slug = "migration-to-my-new-infra"
authors = ["rootmout"]
tags = ["k8s", "ceph", "argocd", "ansible"]
categories = ["infra"]
externalLink = ""
series = []
+++

{{< notice info >}} The descriptions in this article are for an infra in development and will probably be updated in a future article. {{< /notice >}}

# TL;DR

- The new infrastructure is composed of 4 servers, a Raspberry pi acting as a gate, and an eaton UPS.
- 3 servers (ceph-1:3) form a Ceph (storage) and Consul (service mesh) cluster. Each Ceph node has 2 HDD of 1TB.
- 1 server (compute-1) forms a k3s "cluster" to deploy applications (managed by ArgoCD).

# 1. Legacy

2016 is the year I started deploying my first applications. Deploy is perhaps a big word because I used a service offered by [1&1](https://www.ionos.fr/) (renamed IONOS) which consists in giving, an very basic FTP connection to a NGINX server administered by them. It was therefore more about file sending I think.

In 2019 for the project [cocovoit](/projects/#april-2019--cocovoit), the little power allocated in my offer by 1&1 to php scripts forced me to use my first VPS ([OVH](https://www.ovhcloud.com/fr/)), the first of a long line. Today, the sites I host are either on a server managed by 1&1 or on a VPS.

In both cases, the current design is problematic, not only because it is expensive but also because it is far from respecting some basic good practices.

In 2020, I had the intention to migrate these applications on a self-hosted k8s, but I ran up against the lack of hardware. So I picked up several computers and had installed fiber (my ISP do the job ofc) during 2021, which allowed me to start my new infra at the beginning of 2022.

# 2. Hardware

We can organize the servers in two different groups, the ceph servers on the one hand (3 devices), which are in charge of storage and the computes on the other hand (1 device), in charge of hosting applications. The number of servers in this second group will be increased over time.

A Raspberry pi, acts as a gate and VPN gateway to a VPS OVHCloud, the goal being to keep a fixed IP to SSH to the servers, even if the dynDNS made over the IP of the box would come to fail.

### 2.1 Servers

| Hostname    | Model                     | Processor                   | Memory      | Storage                      |
|-------------|---------------------------|-----------------------------|-------------|------------------------------|
| ceph-1      | HP Z240 Tower Workstation | intel i7-6700 CPU @ 3.40GHz | 8Go DDR4    | 2x WDC WD10EZEX-21W (1To)    |
| ceph-2      | HP Compaq Elite 8300 CMT  | intel i7-3770 CPU @ 3.40GHz | 16Gb DDR3   | 2x WDC WD10EZEX-21W (1To)    |
| ceph-3      | HP Compaq Elite 8300 CMT  | intel i7-3770 CPU @ 3.40GHz | 16Gb DDR3   | 2x WDC WD10EZEX-21W (1To)    |
| compute-1   | HP EliteDesk 800 G1 TWR   | intel i7-4790 CPU @ 3.60GHz | 8Gb DDR3    | 1 x WDC WD5000BHTZ-0 (500GB) |
| gate-1      | Raspberry Pi 4 Model B    | Broadcom BCM2711  @ 1.50GHz | 4Gb LPDDR4  | 16Gb SD Card                 |

### 2.2 Others

Switch : D-Link DGS-1016D

UPS : EATON EX 1,5kVA

# 3. Software

## 3.1 Storage

The storage provided to the applications comes from a [Ceph](https://ceph.io/en/) cluster composed of 3 nodes (ceph-1:3). Each node has 2 disks of 1TB each. The first one is truncated by 50GB for the OS and Consul, the second one is fully dedicated to Ceph. This gives us 3 [OSD](https://docs.ceph.com/en/latest/glossary/#term-Object-Storage-Device) of 1TB and 3 OSD of 950GB.

Using a Ceph cluster is probably overkill for the use of this infra, especially since the recommended network criteria are not met for now which makes it a bit slow (~33 MB/s), but the interest is to build a resilient solution, much more exciting to configure than an NFS server.

```
$ dd if=/dev/zero of=speetest bs=1M count=2000 conv=fdatasync
2000+0 records in
2000+0 records out
2097152000 bytes (2.1 GB, 2.0 GiB) copied, 63.4384 s, 33.1 MB/s
```

The time will allow me to consolidate and optimize this cluster to reach good performances, but for the moment it is ok to run client applications, which match my expectations.

## 3.2 Deployments

The k3s cluster (currently mononode) is hosted on compute-1 and deployments are managed by [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) which relies on the [mout-ch/k8s (github)](https://github.com/mout-ch/k8s) repository to know the desired cluster state.

The *root* application located in the `root/` path of the repo is responsible for deploying all other applications, including ArgoCD itself. The applications are stored in the `apps/` folder and are [Helm](https://helm.sh/) charts .

Almost all of these charts do not have a template folder, but have in their dependency a public chart whose values can be configured in the values file. In this way it is possible to deploy opensource charts by keeping in mout-ch/k8s only the  configurations or additionals manifests for the good functioning of the apps.

{{< notice example >}} The cert-manager app installs the cert-manager chart described as a dependency in [Chart.yaml](https://github.com/mout-ch/k8s/blob/0beae8032c8476e136d2cabf5b78501c38c5a781/apps/cert-manager/Chart.yaml#L9) using the values provided in [values.yaml](https://github.com/mout-ch/k8s/blob/0beae8032c8476e136d2cabf5b78501c38c5a781/apps/cert-manager/values.yaml#L1). The `ClusterIssuer` are deployed by manifests described in the [templates](https://github.com/mout-ch/k8s/tree/main/apps/cert-manager/templates) folder. {{< /notice >}}


## 3.3 TLS Certificates

TLS certificates are generated by cert manager. Once the different `ClusterIssuer` is declared, you have to add one annotation in the applications ingress. The [official doc](https://cert-manager.io/docs/) will give you the details of how it works.

In my own configuration, two `ClusterIssuer` are presents, both are configured for LetsEncrypt and use the http01 challenge. The distinction is on the URL used to contact LetsEncrypt. One will get a staging certificate while the second will be for production.

{{< notice info >}} The limits, in number of certificates, imposed by LetsEncrypt are: In [staging](https://letsencrypt.org/docs/staging-environment/): 30k/week in [production](https://letsencrypt.org/docs/rate-limits/): 50/week {{< /notice >}}

## 3.4 Service Mesh

HTTPS connections are established between the client and the [Traefik](https://doc.traefik.io/traefik/) ingress, so encryption does not persist beyond that. The initial plan was to set up [Consul](https://www.consul.io/) before deploying the first applications.

To make the apps communicate in the cluster with services, like Ceph, it's requires to create several datacenters ([according to the terminology of consul](https://www.consul.io/docs/install/glossary#datacenter)). An additional difficulty that I decided to report but that will be fixed in the future.

The traffic behind the ingress will also be encrypted but with a certificate provided by Consul (generated by Vault).

{{< notice info >}} Services registered by Consul within a datacenter must be on the same network to work together. Since k8s/k3s isolates the pods in its own network, it should be considered a datacenter in its own right. The traffic can then communicate between these two datacenters using a [mesh gateway](https://www.consul.io/docs/connect/gateways#mesh-gateways). {{< /notice >}}

## 3.5 Secret management

An instance of [Vault](https://www.vaultproject.io/) is present on each Ceph node and uses the [K/V storage](https://www.consul.io/docs/dynamic-app-config/kv) backend offered by Consul to store its secrets (encrypted of course). Vault will eventually be used to generate certificates for services registered by Consul in order to enable mTLS on the entire infrastructure.

# 4. Next steps

- Upgrade servers with 8GB of RAM to 16GB;
- Setting up monitoring ;
- Connect the k3s to the Consul cluster in place;
- Deployment of an identity centralization application (like Keycloak).

# 5. Points of improvement

- Adding off-site backup (Restic);
- Use a manageable switch for VLAN integration;
- Adding nodes for the k3s cluster.

# Sources

ABlog articles that complement the official documentation of the services listed above.

- https://blog.stephane-robert.info/post/https-k3s-lets-encrypt/
- https://www.arthurkoziel.com/setting-up-argocd-with-helm/
