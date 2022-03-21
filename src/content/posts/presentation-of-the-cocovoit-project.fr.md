+++
draft = false
date = 2022-03-21T10:07:51+01:00
title = "Présentation du projet cocovoit"
description = ""
slug = "presentation-of-the-cocovoit-project"
authors = ['rootmout']
tags = ['symfony', 'php', 'twig', 'bootstrap']
categories = ['school project']
externalLink = ""
series = []
+++

Démo : [cocovoit.lab.kelbert.fr](https://cocovoit.lab.kelbert.fr)

Le projet cocovoit est un projet que j'ai réalisé avec [Clément DUPLAND](https://www.linkedin.com/in/cldupland/) et [Hugo DI GUARDIA](https://www.linkedin.com/in/hdiguardia/) lors de mon semestre à l'[UQAC](https://www.uqac.ca/).

Le sujet était de réaliser une platforme de covoiturage (type blablacar) en utilisant le frameworks de notre choix, nous avons décidé d'utiliser le framework symfony que nous avions déjà utilisé pour un projet antérieur.

Pour mettre le site en ligne, j'ai du, en avril 2019, faire l'acquisition de mon premier VPS et le site est resté en ligne pendant 2ans sur cette solution. À l'occasion de la création de ma nouvelle infra, je me suis promis de dockeriser ce projet et de remettre cocovoit en ligne, d'où cet article 3 ans après.

# Fonctionnement de cocovoit

En premier lieu, le conducteur renseigne sur son tableau de bord le trajet qu'il s'apprête à faire. Comme nous ne pouvons pas anticiper la durée des pauses, le conducteur doit renseigner lui-même la durée du trajet.

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_created.png)

Les derniers trajets créés sont disponibles sur la page `/trip`. Les voyageurs de la platforme peuvent voir que Sarah vient de proposer un voyage entre Montréal et Chicoutimi.

![](/images/presentation-of-the-cocovoit-project/cocovoit_latest_trip_list.png)

Tommy, notre second utilisateur pour ce test, peut donc réserver une place pour le voyage de Sarah. Notre business modèle, très généreux, permet à Tommy de voyager gratuitement.

![](/images/presentation-of-the-cocovoit-project/cocovoit_reserve_trip.png)

Une fois la transaction effectuée, tommy voit apparaître sa réservation sur son tableau de bord, il peut alors annuler sa réservation ou bien afficher son billet (un QR code).

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_reserved.png)

De son côté, la conductrice Sarah voit la réservation sur son tableau de bord. Notez qu'elle peut décider d'annuler son voyage.

{{< notice info >}} L'une des consignes du devoir était de désactiver les utilisateurs annulant trop souvent leurs voyages. Au partir de 3 voyages annulés, l'utilisateur est donc bloqué et invité à contacter un responsable. {{< /notice >}}

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_list_with_one_reservation.png)

Au moment du départ, le voyageur présente le QR code disponible sur son tableau de bord (bouton "Voir le ticket"). Le conducteur, avec son téléphone doit le scanner afin de voir si son titre est en règle.

![](/images/presentation-of-the-cocovoit-project/cocovoit_scan_qr_code_shamefully_resize.png)

Un fonctionnement proche du passe sanitaire, mais avec 2 ans d'avance :)

# Quelques détails techniques

La "restauration" de ce site aura nécessité les étapes suivantes :
- passage de mysql à postgresql
- mise à jour vers symfony 5
- ajouter l'utilisation de variable d'environnement
- écriture d'un readme

Pour la mise en ligne :
- création d'un Dockerfile
- création d'une CI gitlab (build le contener et push sur le registry gitlab)
- écriture de manifests k8s, voir [mout.ch/k8s/apps/cocovoit (github)](https://github.com/mout-ch/k8s/tree/main/apps/cocovoit/templates)
