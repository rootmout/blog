+++
draft = false
date = 2022-03-28T01:24:34+02:00
title = "Access a private docker registry with vault-secret-operator's help"
description = ""
slug = "acces-private-docker-registry-with-vault-secret-operator-s-help"
authors = ['rootmout']
tags = ['vault', 'vault-secret-operator', 'k8s']
categories = ['security']
externalLink = ""
series = []
+++

# Introduction

Basically, to enable a pod to load a container on a private registry (gitlab for example), the `spec.imagePullSecrets` parameter must contain a `regcred` secret. This type of secret must necessarily contain a key `.dockerconfigjson` whose value must follow this template :
```yaml
{
    "auths": {
        "REGISTRY_HOSTNAME":{
            "username":"REGISTRY_USERNAME",
            "password":"REGISTRY_PASSWORD",
            "email":"REGISTRY_EMAIL",
            "auth":"base64(REGISTRY_USERNAME:REGISTRY_PASSWORD)"
    	}
    }
}
```

source: [Chris Vermeulen](https://chris-vermeulen.com/using-gitlab-registry-with-kubernetes/#create-a-docker-credentials-file)

If you use [vault-secrets-operator](https://github.com/ricoberger/vault-secrets-operator) to inject your secrets into k8s, then be aware that you can generate a secret in this format from other secrets using [templates](https://github.com/ricoberger/vault-secrets-operator#using-templated-secrets).

# Explanation by example

Let's say you want to give access to the gitlab registry of your project. The first step is to create a login and password to connect to it (see [Project access tokens](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html), and don't forget to give at least the `read_registry` right).

Then, you have to register this username and password in a secret vault in addition to the hostname of the registry like this:

![](/images/acces-private-docker-registry-with-vault-secret-operator-s-help/vault.png)

To generate the secret, you just have to apply the following manifest:

```yaml
---
apiVersion: ricoberger.de/v1alpha1
kind: VaultSecret
metadata:
  name: my_app-registry
spec:
  type: kubernetes.io/dockerconfigjson
  path: example/my_app/registry
  keys:
    - hostname
    - username
    - password
  templates:
    ".dockerconfigjson": |
      {
          "auths": {
              "{% .Secrets.hostname %}":{
                  "username":"{% .Secrets.username %}",
                  "password":"{% .Secrets.password %}",
                  "auth":"{% list .Secrets.username ":" .Secrets.password | join "" | b64enc %}"
        	    }
          }
      }
```

If all went well, you should have the following output:

```
[rootmout@thinkpad:~]$ kubectl get secret myapp-registry -o 'jsonpath={.data.\.dockerconfigjson}' | base64 --decode
{
    "auths": {
        "registry.gitlab.com":{
            "username":"gitlab+deploy-token-910431",
            "password":"3zsAXZHJwg-QyTr7sRbW",
            "auth":"Z2l0bGFiK2RlcGxveS10b2tlbi05MTA0MzE6M3pzQVhaSEp3Zy1ReVRyN3NSYlc="
  	   }
    }
}
```

```
[rootmout@thinkpad:~]$ kubectl get secret myapp-registry -o 'jsonpath={.data.\.dockerconfigjson}' | base64 --decode | jq -r '.auths."registry.gitlab.com".auth' | base64 --decode
gitlab+deploy-token-910431:3zsAXZHJwg-QyTr7sRbW
```

Finally use this secret in a pod using the `spec.imagePullSecrets` parameter:

```
apiVersion: v1
kind: Pod
metadata:
  name: private-reg
spec:
  containers:
  - name: private-reg-container
    image: <your-private-image>
  imagePullSecrets:
  - name: regcred
```
source : [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-pod-that-uses-your-secret)

(The secret used in this article obviously does not exist...)

# Sources

- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- https://chris-vermeulen.com/using-gitlab-registry-with-kubernetes/
- https://github.com/ricoberger/vault-secrets-operator
