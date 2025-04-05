# Application monitoring on OpenShift with Grafana
<!-- markdownlint-disable MD004 MD034 -->
AppMon is a set of resources that use Grafana Operator and the embedded Prometheus engine in OpenShift to visualize metrics published by running applications.
This project collects some procedures on how to setup a custom AppMon instance based on the following software versions:

* Grafana Operator - Community Edition - version 5.17
* OpenShift/OKD 4.15 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>
* <https://grafana.github.io/grafana-operator/docs/installation/helm/>

## Index

<!-- TOC -->

- [Application monitoring on OpenShift with Grafana](#application-monitoring-on-openshift-with-grafana)
    - [Index](#index)
    - [Prerequisites](#prerequisites)
    - [Deploy Grafana Operator](#deploy-grafana-operator)
        - [Clone the repository](#clone-the-repository)
        - [Install the Grafana Operator using its Helm chart](#install-the-grafana-operator-using-its-helm-chart)
    - [Deploy Grafana instance](#deploy-grafana-instance)

<!-- /TOC -->

## 1. Prerequisites

On your Linux client

* OpenShift client utility: ```oc```
* Helm client utility v3.11 or higher: ```helm```

On OpenShift

* Cluster admin privileges
* Access to GitHub Container Registry `ghcr.io`
* at least one running application exposing metrics
* at least a Prometheus instance configured to scrape metrics from user workloads

## 2. Deploy Grafana Operator

### 2.1 Clone the repository

Clone this repository on your client:

```bash
git clone --branch 5.17.0 https://github.com/dedalus-enterprise-architect/openshift-monitoring-prometheus-grafana.git
cd openshift-monitoring-prometheus-grafana/
```

### 2.2 Install the Grafana Operator using its Helm chart

Before proceeding you must be logged in to the OpenShift API server via `oc login` client command.

Set the following variables:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
KUBE_TOKEN=$(oc whoami -t)
KUBE_APISERVER=$(oc whoami --show-server=true)
```

Deploy the Grafana Operator:

```bash
helm upgrade -i grafana-operator oci://ghcr.io/grafana/helm-charts/grafana-operator \
--version v5.17.0 \ 
--values deploy/operator/values.yaml \
-n $MONITORING_NAMESPACE --create-namespace \
--kube-apiserver ${KUBE_APISERVER} \
--kube-token ${KUBE_TOKEN}
```

To check the installation you can also run this command:

```bash
helm list -n ${MONITORING_NAMESPACE} \
--kube-apiserver ${KUBE_APISERVER} \
--kube-token ${KUBE_TOKEN}
```

## 3. Deploy Grafana instance
- [Using OpenShift Template](/deploy/openshift-template/README.md)

### 3.1 Create the Dashboard ConfigMap

```bash
oc create configmap jvm-dashboard-advanced-configmap --from-file=deploy/dashboards/jvm-dashboard-advanced.json \
-n $MONITORING_NAMESPACE
```

### 3.2 Create the GrafanaDashboard resource

Create a YAML file for the `GrafanaDashboard` resource, for example `jvm-advanced-metrics.yaml`:

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: jvm-advanced-metrics
  namespace: $MONITORING_NAMESPACE
  labels:
    app: appmon-dedalus
    dashboards: "${GRAFANA_INSTANCE_NAME}"
spec:
  instanceSelector:
    matchLabels:
      dashboards: "${GRAFANA_INSTANCE_NAME}"
  configMapRef:
    name: jvm-dashboard-advanced-configmap
    key: jvm-dashboard-advanced.json
```

Apply the `GrafanaDashboard` resource:

```bash
oc apply -f jvm-advanced-metrics.yaml
```

### 3.3 Connect to Grafana Web UI

Get the OpenShift routes where the services are exposed:

```bash
oc get route -n $MONITORING_NAMESPACE

```

> The `*-admin` route won't use the _OAuth Proxy_ for authentication, but instead will require the admin credentials provided in this secret
`{GRAFANA_INSTANCE_NAME}-admin-credentials`.
The `*-route` one will use the _OAuth Proxy_ but grants only a read-only access.
