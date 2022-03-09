+++
draft = false
date = 2022-03-09T10:13:46+01:00
title = "Migration vers ma nouvelle infra"
description = ""
slug = "migration-to-my-new-infra"
authors = ["rootmout"]
tags = ["k8s", "ceph", "argocd", "ansible"]
categories = ["infra"]
externalLink = ""
series = []
+++

{{< notice info >}} Les descriptions dans cet article concernent une infra en développement et seront très probablement mises à jour dans un article futur. {{< /notice >}}

# TL;DR

- La nouvelle infra est composée de 4 serveurs, d'une Raspberry pi faisant office de gate, et d'un onduleur eaton.
- 3 serveurs (ceph-1:3) forment un cluster Ceph (stockage) et Consul (service mesh). Chaque noeud Ceph a 2 HDD de 1To.
- 1 serveur (compute-1) forme un "cluster" k3s pour déployer les applications (managées par ArgoCD).

# 1. Legacy

2016 est l'année où j'ai commencé à déployer mes premières applications. Déployer est peut-être un grand mot car j'ai utilisé un service proposé par [1&1](https://www.ionos.fr/) (renommé IONOS) qui consiste à donner, comme seul accès, une connexion FTP à un serveur NGINX administré par leurs soins. À ce stade, c'était donc plus de l'envoie de fichiers.

En 2019 pour le projet [cocovoit](/fr/projects/#avril-2019--cocovoit), le peu de puissance alloué dans mon offre par 1&1 aux scripts php m'ont contraint à utiliser mon premier VPS ([OVH](https://www.ovhcloud.com/fr/)), le premier d'une longue lignée. Aujourd'hui les sites que j'héberge sont donc soit sur un serveur autogéré par 1&1 soit sont sur un VPS.

Dans les deux cas, le fonctionnement actuel pose problème, non seulement il est coûteux mais en plus il est loin de respecter certaines bonnes pratiques de base.

En 2020, j'avais bien l'intention de migrer ces applications sur un k8s hébergé par mes soins, mais je me suis heurté au manque de matériel. J'ai donc récupéré plusieurs ordinateurs et fait installer la fibre au cours de l'année 2021, ce qui m'a permis début 2022 de commencer ma nouvelle infra que voici.

# 2. Hardware

On peut organiser les serveurs en deux groupes, les ceph d'une part (au nombre de 3), qui se chargent du stockage et les computes d'autre part (au nombre de 1), chargés d'héberger les applications. Le nombre de serveurs dans ce second groupe sera augmenté avec le temps.

Une Raspberry pi, fait office de gate et de passerelle VPN vers un VPS OVHCloud, le but étant de garder une IP fixe pour se SSH aux serveurs, même si le dynDNS effectué sur l'IP de la boxe viendrait à faire défaut.

### 2.1 Serveurs

| Nom d'hôte  | Modèle                    | Processeur                  | Mémoire     | Stockage                     |
|-------------|---------------------------|-----------------------------|-------------|------------------------------|
| ceph-1      | HP Z240 Tower Workstation | intel i7-6700 CPU @ 3.40GHz | 8Go DDR4    | 2x WDC WD10EZEX-21W (1To)    |
| ceph-2      | HP Compaq Elite 8300 CMT  | intel i7-3770 CPU @ 3.40GHz | 16Gb DDR3   | 2x WDC WD10EZEX-21W (1To)    |
| ceph-3      | HP Compaq Elite 8300 CMT  | intel i7-3770 CPU @ 3.40GHz | 16Gb DDR3   | 2x WDC WD10EZEX-21W (1To)    |
| compute-1   | HP EliteDesk 800 G1 TWR   | intel i7-4790 CPU @ 3.60GHz | 8Gb DDR3    | 1 x WDC WD5000BHTZ-0 (500GB) |
| gate-1      | Raspberry Pi 4 Model B    | Broadcom BCM2711  @ 1.50GHz | 4Gb LPDDR4  | 16Gb SD Card                 |

### 2.2 Autre

Switch : D-Link DGS-1016D

Onduleur : EATON EX 1,5kVA

# 3. Software

## 3.1 Stockage

Le stockage fournit aux applications provient d'un cluster [Ceph](https://ceph.io/en/) composé de 3 nœuds (ceph-1:3). Chacun des nœuds dispose de 2 disques de 1To chacun. Le premier est tronqué de 50Go pour l'OS et Consul, le second est intégralement dédié à Ceph. Cela nous fait donc 3 [OSD](https://docs.ceph.com/en/latest/glossary/#term-Object-Storage-Device) de 1to et 3 OSD de 950Go.

Utiliser un cluster Ceph est sans doute exagéré pour l'utilisation de cette infra, d'autant plus que pour le moment les critères réseau recommandés ne sont pas remplis ce qui en fait un cluster un peu lent (~33 MB/s), mais l'intérêt est de construire une solution résiliente, bien plus passionnant à configurer qu'un serveur NFS.

```
$ dd if=/dev/zero of=speetest bs=1M count=2000 conv=fdatasync
2000+0 records in
2000+0 records out
2097152000 bytes (2.1 GB, 2.0 GiB) copied, 63.4384 s, 33.1 MB/s
```

L'avenir permettra de consolider et optimiser ce cluster pour atteindre de bonnes performances, mais pour l'heure il est en capacité de faire fonctionner les application clientes, ce qui est largement suffisant.

## 3.2 Déploiement

Le cluster k3s (actuellement mononode) est hébergé sur compute-1 et est les déploiements sont gérés par [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) qui se base sur le repository [mout-ch/k8s (github)](https://github.com/mout-ch/k8s) afin de connaître l'état du cluster souhaité.

L'application *root* localisée dans le chemin `root/` du repo est en charge de déployer toutes les autres applications, comprenant ArgoCD lui-même. Les applications sont stockées dans le dossier `apps/` et sont des charts [Helm](https://helm.sh/).

La quasi intégralité de ces chartes ne comportent pas de dossier template, mais ont dans leur dépendance une chart publique dont les valeurs peuvent êtres configurées dans le fichier values. De cette manière il est possible de déployer des charts opensource en ne conservant dans mout-ch/k8s que les configurations ou manifests supplémentaires au bon fonctionnement des apps.

{{< notice example >}} L'app cert-manager installe la chart cert-manager décrite comme dépendance dans [Chart.yaml](https://github.com/mout-ch/k8s/blob/0beae8032c8476e136d2cabf5b78501c38c5a781/apps/cert-manager/Chart.yaml#L9) en utilisant les valeurs fournies dans [values.yaml](https://github.com/mout-ch/k8s/blob/0beae8032c8476e136d2cabf5b78501c38c5a781/apps/cert-manager/values.yaml#L1). Les `ClusterIssuer` quant à eux sont déployés par des manifests décrits dans le dossier [templates](https://github.com/mout-ch/k8s/tree/main/apps/cert-manager/templates). {{< /notice >}}


## 3.3 Certificats TLS

Les certificats TLS sont générés par cert manager. Une fois le(s) différent(s) `ClusterIssuer` déclarés, il suffit de rajouter l'annotation dans l'ingress des applications. La [doc officielle](https://cert-manager.io/docs/) saura vous donner les détails du fonctionnement.

En ce qui me concerne, deux ClusterIssuer sont présents, les deux sont configurés pour LetsEncrypt et utilisent le challenge http01. La distinction se situe sur l'URL utilisé pour contacter LetsEncrypt. L'un va obtenir un certificat de staging tandis que le second sera de la production.

{{< notice info >}} Les limites, en nombre de certificats, imposés par LetsEncrypt sont : En [staging](https://letsencrypt.org/docs/staging-environment/) : 30k/semaine en [production](https://letsencrypt.org/docs/rate-limits/) : 50/semaine {{< /notice >}}

## 3.4 Service Mesh

Les connexions HTTPS sont établies entre le client et l'ingress [Traefik](https://doc.traefik.io/traefik/), le chiffrement ne perdure donc pas au-delà. Le projet initial était de mettre en place [Consul](https://www.consul.io/) avant de déployer les premières applications.

Faire communiquer les apps dans le cluster avec des services comme ceph nécéssite de créer plusieurs datacenter ([selon la terminologie de consul](https://www.consul.io/docs/install/glossary#datacenter)). Une difficulté supplémentaire que j'ai décidé de repporter mais qui sera à terme surmontée.

Le trafic derrière l'ingress sera lui aussi chiffré mais avec un certificat fourni par Consul (généré par Vault).

{{< notice info >}} Les services enregistrés par Consul au sein d'un datacenter doivent êtres sur le même réseau pour fonctionner. Comme k8s/k3s isole les pods dans son propre réseau, il faut le considérer comme un datacenter à part entière. Le trafic pourra ensuite communiquer entre ces deux datacenter à l'aide d'une [mesh gateway](https://www.consul.io/docs/connect/gateways#mesh-gateways). {{< /notice >}}

## 3.5 Gestion des secrets

Une instance de [Vault](https://www.vaultproject.io/) est présente sur chaque noeud Ceph et utilise le [stockage K/V](https://www.consul.io/docs/dynamic-app-config/kv) proposé par Consul pour stocker ses secrets (chiffrés bien évidemment). Vault sera utilisé à terme pour générer les certificats des services enregistrés par Consul dans le but d'activer le mTLS sur toute l'infrastructure.

# 4. Étapes à venir

- Passer les machine avec 8Go de RAM vers 16Go ;
- Mise en place de monitoring ;
- Fédérer le k3s au cluster HC Consul en place ;
- Déploiement d'une application de centralisation des identités (type Keycloak).

# 5. Points d'amélioration

- Mise en place de backup off-site (Restic) ;
- Utiliser un switch manageable pour l'intégration de VLANs ;
- Ajout de nœuds pour le cluster k3s.

# Sources

Articles de blog qui ont su compléter la documentation officielle des services listés ci-dessus.

- https://blog.stephane-robert.info/post/https-k3s-lets-encrypt/
- https://www.arthurkoziel.com/setting-up-argocd-with-helm/
