+++
draft = false
date = 2022-03-21T10:07:51+01:00
title = "Presentation of the cocovoit project"
description = ""
slug = "presentation-of-the-cocovoit-project"
authors = ['rootmout']
tags = ['symfony', 'php', 'twig', 'bootstrap']
categories = ['school project']
externalLink = ""
series = []
+++

Demo : [cocovoit.lab.kelbert.fr](https://cocovoit.lab.kelbert.fr)

I made this school project with [Clément DUPLAND](https://www.linkedin.com/in/cldupland/) and [Hugo DI GUARDIA](https://www.linkedin.com/in/hdiguardia/) during my international semester at [UQAC](https://www.uqac.ca/).

The subject was to create a carpooling platform (like blablacar) using the framework of our choice, we decided to use the symfony framework that we had already used for a previous project.

To put the site online, I had to buy my first VPS in April 2019 and the site stayed online for 2 years on this solution. When I created my new infra, I promised myself to dockerize this project and to put cocovoit back online, hence this article 3 years later.

# Cocovoit working

First of all, the driver indicates on his dashboard the journey he is about to make. As we cannot anticipate the duration of the breaks, the driver must enter the duration of the trip himself.

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_created.png)

The last created trips are available on the `/trip` page. The travelers of the platform can see that Sarah, the driver in our example, has just proposed a trip between Montreal and Chicoutimi.

![](/images/presentation-of-the-cocovoit-project/cocovoit_latest_trip_list.png)

Tommy, our second user for this test, can therefore reserve a place for Sarah's trip. Our business model, very generous, allows Tommy to travel for free.

![](/images/presentation-of-the-cocovoit-project/cocovoit_reserve_trip.png)

Once the transaction is done, tommy sees his reservation appear on his dashboard, he can then cancel his reservation or display his ticket (a QR code).

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_reserved.png)

On her side, the driver Sarah sees the reservation on her dashboard. Note that she can decide to cancel her trip.

{{< notice info >}} One of the rule of the assignment was to disable users canceling their trips too often. From 3 cancelled trips, the user is therefore blocked and invited to contact a manager. {{< /notice >}}

![](/images/presentation-of-the-cocovoit-project/cocovoit_trip_list_with_one_reservation.png)

At the moment of departure, the passenger presents the QR code available on his dashboard (button "Voir le ticket" (See the ticket)). The driver, with his phone, must scan it to see if his ticket is in order.

![](/images/presentation-of-the-cocovoit-project/cocovoit_scan_qr_code_shamefully_resize.png)

An operation close to the sanitary pass, but with 2 years earlier :)

# Some technical details

The "restoration" of this site will have required the following steps:
- switch from mysql to postgresql
- upgrade to symfony 5
- use environment variables in config files
- writing a readme

For the deployment:
- create a Dockerfile
- creation of a gitlab CI (build the container and push to the gitlab registry)
- writing k8s manifests, see [mout.ch/k8s/apps/cocovoit (github)](https://github.com/mout-ch/k8s/tree/main/apps/cocovoit/templates)
