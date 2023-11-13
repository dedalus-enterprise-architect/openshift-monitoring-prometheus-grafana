# Appmon Resources

This project explains how to deploy a custom Appmon resources.

Appmon is a set of resources that use Grafana Operator and the embended Prometheus in Openshift to visualize metrics

* Grafana Operator - community edition  version 5.4.1
* OpenShift/OKD 4.12 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

---

## Index

- [Appmon Resources](#appmon-resources)
  - [Index](#index)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Grafana Operator](#2-grafana-operator)
    - [2.1 Clone the repo](#21-clone-the-repo)
    - [2.2 Login to Openshift Cluster using oc client](#22-login-to-openshift-cluster-using-oc-client)
    - [2.3 Install the Grafana Operator using Helm procedure](#23-install-the-grafana-operator-using-helm-procedure)
    - [2.3 Next Steps](#23-next-steps)

---
---

## 1. Prerequisites

On your client

1. install the OpenShift CLI tool
2. install the helm CLI v3.11+
3. Cluster-Admin rights on the Openshift Cluster

able to reach grafana operator image repository
`ghcr.io/grafana-operator/grafana-operator`

On OpenShift

1. at least one namespace (ex. dedalus-app) with a running application exposing metrics already exists
2. Prometheus configured to grab metrics from user workload

---
---

## 2. Grafana Operator

References:
* https://grafana-operator.github.io/grafana-operator/docs/installation/helm/

The deploy will follow the official procedure using a values.yaml provided by this project.
If you are going to change the content of values.yaml rememeber to reflect the changes that you made in the other resources.

### 2.1 Clone the repo

As a first step we are going to create a working directory and clone there the repository:

```bash
WORKING_DIRECTORY=/opt/git_testing

mkdir -vp ${WORKING_DIRECTORY}
cd ${WORKING_DIRECTORY}

git clone https://github.com/dedalus-enterprise-architect/grafana-resources.git --branch v5.4.1
```

---

### 2.2 Login to Openshift Cluster using oc client

---

### 2.3 Install the Grafana Operator using Helm procedure

```bash
MONITORING_NAMESPACE=dedalus-monitoring
KUBE_TOKEN=$(oc whoami -t)
KUBE_APISERVER=$(oc whoami --show-server=true)

helm upgrade -i grafana-operator oci://ghcr.io/grafana-operator/helm-charts/grafana-operator --version v5.4.1 --values grafana-resources/deploy/operator/values.yaml -n $MONITORING_NAMESPACE --create-namespace --kube-apiserver ${KUBE_APISERVER} --kube-token ${KUBE_TOKEN}
```

The output should be

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

To check the installation you can also run this command:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
KUBE_TOKEN=$(oc whoami -t)
KUBE_APISERVER=$(oc whoami --show-server=true)

helm list -n ${MONITORING_NAMESPACE} --kube-apiserver ${KUBE_APISERVER} --kube-token ${KUBE_TOKEN}
```

you will get the following output:
```bash
NAME                    NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
grafana-operator        dedalus-monitoring      1               2023-11-13 16:25:29.160445089 +0100 CET deployed        grafana-operator-v5.4.1 v5.4.1
```

### 2.3 Next Steps

You have successfully installed the Grafana Operator, to complete the deploy all the AppMon resources please refer to the documentation:
* [Openshift Template](deploy/openshift-template/OPENSHIFT_TEMPLATE.md)