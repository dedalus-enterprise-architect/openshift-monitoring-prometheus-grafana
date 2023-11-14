# Appmon Resources
<!-- markdownlint-disable MD004 MD034 -->
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
  - [Openshift Templates](#openshift-templates)
    - [3.1 Process the template](#31-process-the-template)
    - [3.2 Template Parameters](#32-template-parameters)
    - [3.3 Connect to the route](#33-connect-to-the-route)
  - [Other Templates](#other-templates)
    - [basic vs oauth](#basic-vs-oauth)
    - [querier vs tenancy](#querier-vs-tenancy)

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

* [Openshift Template](#openshift-templates)

## Openshift Templates

### 3.1 Process the template

```bash
oc process -f grafana-resources/deploy/openshift-template/appmon-oauth_querier_template.yaml | oc apply -f -
```

here the output:

```bash
Warning: resource serviceaccounts/appmon-serviceaccount is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by oc apply. oc apply should only be used on resources created declaratively by either oc create --save-config or oc apply. The missing annotation will be patched automatically.
serviceaccount/appmon-serviceaccount configured
clusterrolebinding.rbac.authorization.k8s.io/grafana-cluster-monitoring-view-binding created
secret/appmon-oauth-proxy created
configmap/appmon-oauth-certs created
clusterrole.rbac.authorization.k8s.io/appmon-oauth-proxy created
clusterrolebinding.authorization.openshift.io/appmon-oauth-proxy created
clusterrole.rbac.authorization.k8s.io/aggregate-grafana-view created
grafana.grafana.integreatly.org/appmon-oauth-querier created
grafanadatasource.grafana.integreatly.org/prometheus-ds-appmon-oauth-querier created
grafanadashboard.grafana.integreatly.org/jvm-dashboard-basic created
grafanadashboard.grafana.integreatly.org/jvm-dashboard-advanced created
route.route.openshift.io/appmon-oauth-querier-admin created
```

### 3.2 Template Parameters

here the list of the accepted parameters and their defaults:

```bash
parameters:
- name: MONITORING_NAMESPACE
  displayName: Type the Namespace "name"
  description: Namespace "name" where all the resources of AppMon will be deployed
  required: true
  value: dedalus-monitoring
- name: APPMON_SERVICEACCOUNT
  displayName: Type the ServiceAccount "name"
  description: The service account that will be created and used by AppMon resources
  required: true
  value: appmon-serviceaccount
- name: GRAFANA_INSTANCE_NAME
  displayName: Type a name for the Grafana Instance
  description: This value will be also used to attacch the Dashboards and Datasources created by this template to the instance
  required: true
  value: appmon-oauth-querier
- name: THANOS_URL
  displayName: Prometheus URL
  description: Type the Prometheus URL you can use the service on port 9091 or 9092
  required: true
  value: thanos-querier.openshift-monitoring.svc.cluster.local:9091
- name: STORAGECLASS
  displayName: Storage Class Name
  description: Type the Storage Class Name the pod will use to request PVC
  required: true
  value: gp3-csi
```

### 3.3 Connect to the route

use this command to get the routes where the service is exposed:

```bash
oc get route -n dedalus-monitoring
NAME                         HOST/PORT                                                                                   PATH   SERVICES
   PORT      TERMINATION     WILDCARD
appmon-oauth-querier-admin   appmon-oauth-querier-admin-dedalus-monitoring.apps.rubber-cluster.rubberworld.dedalus.aws          appmon-oauth-querier-service   grafana   edge/Redirect   None
appmon-oauth-querier-route   appmon-oauth-querier-route-dedalus-monitoring.apps.rubber-cluster.rubberworld.dedalus.aws          appmon-oauth-querier-service   https     reencrypt       None

```

the route named `*-admin` won't use the Oauth Proxy but the admin credentials into the secret `{GRAFANA_INSTANCE_NAME}-admin-credentials`.

the route named `*-route` will use the Oauth Proxy giving only "Read-Only" access.

## Other Templates

How you can check there are other templates ready for other scenario

```bash
grafana-resources/deploy/openshift-template/
├── appmon-basic_querier_template.yaml #Ephimeral Storage, Basic Authentication, Thanos Querier Datasource
├── appmon-basic_tenancy_template.yaml #Ephimeral Storage, Basic Authentication, Thanos Tenancy Datasource
├── appmon-oauth_querier_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Querier Datasource (Dedalus Best-Practice)
└── appmon-oauth_tenancy_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Tenancy Datasource

```

You can use the template that better suits your needs.

Be sure to check the parameter accepted by the template that you are going to use.

### basic vs oauth

The templates with the `basic` suffix will offer the bare minum to run all the resources and no persitance at all.

The templates with the `oauth` suffix will create extra resources to enable the following features:

* OAuth Proxy Authentication
* Persistent Storage

Rememeber to set the rith value for the STORAGECLASS parameter when using the persistant storage.

### querier vs tenancy

The templates with the `querier` suffix will connect to the thanos service exposed to port 9091.
To enable the access to this service the service account running the grafana instance will need to be able to perform the following operation:

```bash
"resource": "namespaces", "verb": "get"
```

The templates with the `tenancy` suffix will connect to the thanos service exposed to port 9092.
This service won't need the same RBAC of the `querier` but you will need to create a datasource for each namespace from wich you want to read the metrics.
(to help with this task you can use this [template](deploy/openshift-template/datasource/datasource-thanos-tenancy_template.yaml))


The service account will still need view access to the namespace from witch the metrics are read, you can grant this permission with this command:

```bash
oc adm policy add-role-to-user view system:serviceaccount:${MONITORING_NAMESPACE}:appmon-serviceaccount -n ${TARGET_NAMESPACE}
```
