+++
draft = false
date = 2022-03-28T01:24:34+02:00
title = "Accéder à un registry docker privé avec l'aide de vault-secret-operator"
description = ""
slug = "acces-private-docker-registry-with-vault-secret-operator-s-help"
authors = ['rootmout']
tags = ['vault', 'vault-secret-operator', 'k8s']
categories = ['security']
externalLink = ""
series = []
+++

# Introduction

De base, pour qu'un pod puisse charger un container sur un registry privé (gitlab par exemple), le paramètre `spec.imagePullSecrets` doit renseigner un secret de type `regcred`. Ce type de secret doit nécessairement contenir une clé `.dockerconfigjson` dont la valeur doit être sous la forme :
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

Si vous utilisez [vault-secrets-operator](https://github.com/ricoberger/vault-secrets-operator) pour injecter vos secrets dans k8s, alors sachez que vous pouvez générer un secret sous ce format depuis d'autres secrets grâce aux [templates](https://github.com/ricoberger/vault-secrets-operator#using-templated-secrets).

# Explication par l'exemple

Imaginons que vous souhaitez donner un accès au registry gitlab de votre projet. La première étape est de créer un identifiant et mot de passe pour s'y connecter (voir [Project access tokens](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html), sans oublier d'attribuer au minimum le droit `read_registry`).

Ensuite, il faut renseigner cet identifiant et mot de passe dans un secret vault en ajoutant le hostname du registry comme ceci :

![](/images/acces-private-docker-registry-with-vault-secret-operator-s-help/vault.png)

Pour générer le secret, il suffit d'appliquer le manifest suivant :

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

Si tout s'est bien passé, vous devriez avoir le resultat suivant :

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

Enfin utilisez ce secret dans un pod en utilisant le paramètre `spec.imagePullSecrets` :

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

(Le secret utilisé dans cet article n'existe évidemment pas...)

# Sources

- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- https://chris-vermeulen.com/using-gitlab-registry-with-kubernetes/
- https://github.com/ricoberger/vault-secrets-operator
