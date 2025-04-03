# OpenShift AppMon Resources
<!-- markdownlint-disable MD004 MD034 -->
AppMon is a set of resources that use Grafana Operator and the embedded Prometheus engine in OpenShift to visualize metrics published by running applications.
This project collects some procedures on how to setup a custom AppMon instance based on the following software versions:

* Grafana Operator - Community Edition - version 5.17
* OpenShift/OKD 4.15 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

## Index

  - [1. Prerequisites](#1-prerequisites)
  - [2. Grafana Operator](#2-grafana-operator)
    - [2.1 Clone the repo](#21-clone-the-repo)
    - [2.2 Install the Grafana Operator using its Helm chart](#22-install-the-grafana-operator-using-its-helm-chart)
  - [3. AppMon resources](#3-appmon-resources)
    - [Supported Deploy Method](#supported-deploy-method)
  - [Updating from version 4.2.0 to 5.4.1](#updating-from-version-420-to-541)
    - [Check for the old resources](#check-for-the-old-resources)
    - [Deleting the resources](#deleting-the-resources)

## 1. Prerequisites

On your client

* OpenShift client utility: ```oc```
* Helm client utility v3.11 or higher: ```helm```
* OpenShift cluster admin privileges
* Access to Grafana Operator image repository `ghcr.io/grafana-operator/grafana-operator`

On OpenShift

* at least one namespace (ex. _dedalus-app_) with a running application exposing metrics should exists
* one namespace to host AppMon components (ex. _dedalus-monitoring_)
* a Prometheus instance configured to scrape metrics from user workloads

## 2. Grafana Operator

References:

* https://grafana-operator.github.io/grafana-operator/docs/installation/helm/

The deploy will follow the official procedure using a values.yaml provided by this project.
If you are going to change the content of values.yaml rememeber to reflect the changes that you made in the other resources.

### 2.1 Clone the repo

Clone this repository at the right realease on your client:

```bash
git clone https://github.com/dedalus-enterprise-architect/grafana-resources.git
cd grafana-resources/
git checkout tags/v2.0.0
```

### 2.2 Install the Grafana Operator using its Helm chart

> WARNING: an Admin Cluster Role is required to proceed on this section.

Before proceeding you must be logged in to the OpenShift API server via `oc login` client command.

Set the following variables:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
KUBE_TOKEN=$(oc whoami -t)
KUBE_APISERVER=$(oc whoami --show-server=true)
```

deploy the Grafana Operator:

```bash
helm upgrade -i grafana-operator oci://ghcr.io/grafana-operator/helm-charts/grafana-operator --version v5.4.1 --values grafana-resources/deploy/operator/values.yaml -n $MONITORING_NAMESPACE --create-namespace --kube-apiserver ${KUBE_APISERVER} --kube-token ${KUBE_TOKEN}
```

then the output should be:

```bash
Release "grafana-operator" does not exist. Installing it now.
Pulled: ghcr.io/grafana-operator/helm-charts/grafana-operator:v5.4.1
Digest: sha256:584c94257f6df505f9fd4f8dd5b6f6c27536d99a49bb6e6ff89da65bf462bdda
NAME: grafana-operator
LAST DEPLOYED: Mon Nov 13 16:25:29 2023
NAMESPACE: dedalus-monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

to check the installation you can also run this command:

```bash
helm list -n ${MONITORING_NAMESPACE} --kube-apiserver ${KUBE_APISERVER} --kube-token ${KUBE_TOKEN}
```

you should get the following output:

```bash
NAME                    NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
grafana-operator        dedalus-monitoring      1               2023-11-13 16:25:29.160445089 +0100 CET deployed        grafana-operator-v5.4.1 v5.4.1
```

You have successfully installed the Grafana Operator.
Proceed to the next section to complete the AppMon deployment.

## 3. Deploy methods
[- OpenShift Template](/deploy/openshift-template/README.md)
