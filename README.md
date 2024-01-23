# OpenShift AppMon Resources
<!-- markdownlint-disable MD004 MD034 -->
AppMon is a set of resources that use Grafana Operator and the embedded Prometheus engine in OpenShift to visualize metrics published by running applications.
This project collects some procedures on how to setup a custom AppMon instance based on the following software versions:

* Grafana Operator - Community Edition - version 5.4.1
* OpenShift/OKD 4.12 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

## Index

- [OpenShift AppMon Resources](#openshift-appmon-resources)
  - [Index](#index)
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

Clone this repository on your client:

```bash
git clone https://github.com/dedalus-enterprise-architect/grafana-resources.git --branch v5.4.1
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

## 3. AppMon resources

For now the only way to deploy in a declarative way all the _AppMon_ resources is using the Openshift Templates.
For a detailed procedure please read [here](/deploy/openshift-template/OPENSHIFT_TEMPLATE.md)

### Supported Deploy Method

[- Openshift Template](/deploy/openshift-template/OPENSHIFT_TEMPLATE.md)

## Updating from version 4.2.0 to 5.4.1

If you have to update from version 4.2.0 installed using this procedure [here](https://github.com/dedalus-enterprise-architect/grafana-resources/blob/main/README.md)

Or if you are planning to update the OpenShift cluster the best action to take is removing the old 4.2.0

Here is how to proceed:

### Check for the old resources

you can use this command to list all the resources related to the label `app: grafana-dedalus`

```bash
 oc get $(oc api-resources --verbs=list -o name | awk '{printf "%s%s",sep,$0;sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --sort-by='metadata.namespace' -l app=grafana-dedalus 2>/dev/null
```

Here is a sample output:

```bash
KIND                    NAME                                      NAMESPACE
Status                  <none>                                    <none>
ClusterRole             grafana-proxy-dedalus-monitoring          <none>
ClusterRoleBinding      grafana-proxy-dedalus-monitoring          <none>
ClusterRoleBinding      grafana-cluster-monitoring-view-binding   <none>
ClusterRoleBinding      grafana-proxy-dedalus-monitoring          <none>
ClusterRole             grafana-proxy-dedalus-monitoring          <none>
ClusterRoleBinding      grafana-cluster-monitoring-view-binding   <none>
ConfigMap               grafana-oauth-certs                       dedalus-monitoring
GrafanaDataSource       prometheus-grafana-ds                     dedalus-monitoring
Grafana                 grafana-persistent-oauth                  dedalus-monitoring
OperatorGroup           grafana-operator-group                    dedalus-monitoring
Subscription            grafana-operator                          dedalus-monitoring
GrafanaDashboard        jvm-dashboard-basic                       dedalus-monitoring
GrafanaDashboard        jvm-dashboard                             dedalus-monitoring
Secret                  grafana-proxy                             dedalus-monitoring
PersistentVolumeClaim   grafana-pvc                               dedalus-monitoring
Route                   grafana-persistent-oauth-access           dedalus-monitoring
Route                   grafana-persistent-oauth-admin            dedalus-monitoring
```

### Deleting the resources

Now you can start deleting the resource releted to the Grafana _CRD_.
You can use your list and delete the resource using the oc client or you can use the following command to speed up the process,
remember to check your list of resources.

```bash
 for resource in $(oc get $(oc api-resources --verbs=list -o name | awk '{printf "%s%s",sep,$0;sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --sort-by='metadata.namespace' -l app=grafana-dedalus 2>/dev/null | awk '{ print $1","$2","$3 }' | grep "Grafana" | sort -r) ; do oc delete $(echo $resource | awk -F, '{ print $1" "$2" -n "$3 }'); done
grafanadatasource.integreatly.org "prometheus-grafana-ds" deleted
grafanadashboard.integreatly.org "jvm-dashboard-basic" deleted
grafanadashboard.integreatly.org "jvm-dashboard" deleted
grafana.integreatly.org "grafana-persistent-oauth" deleted
```

then proceed deleting the rbac created:

```bash
 for resource in $(oc get $(oc api-resources --verbs=list -o name | awk '{printf "%s%s",sep,$0;sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --sort-by='metadata.namespace' -l app=grafana-dedalus 2>/dev/null | awk '{ print $1","$2","$3 }' | grep "Role" | sort -ur) ; do oc delete $(echo $resource | awk -F, '{ print $1" "$2 }'); done
clusterrolebinding.rbac.authorization.k8s.io "grafana-proxy-dedalus-monitoring" deleted
clusterrolebinding.rbac.authorization.k8s.io "grafana-cluster-monitoring-view-binding" deleted
clusterrole.rbac.authorization.k8s.io "grafana-proxy-dedalus-monitoring" deleted
```

after that continue deleting the operator resources:

```bash
for resource in $(oc get $(oc api-resources --verbs=list -o name | awk '{printf "%s%s",sep,$0;sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --sort-by='metadata.namespace' -l app=grafana-dedalus 2>/dev/null | awk '{ print $1","$2","$3 }' | grep -E 'Operator|Subscription' | sort -r) ; do oc delete $(echo $resource | awk -F, '{ print $1" "$2 }'); done
subscription.operators.coreos.com "grafana-operator" deleted
operatorgroup.operators.coreos.com "grafana-operator-group" deleted
```

and the namespace:

```bash
oc delete namespace dedalus-monitoring
namespace "dedalus-monitoring" deleted
```

At this point if you run the command to [check the resources](#check-for-the-old-resources) it should give you an empty list,
but there are few resources with no labels that we need to take care of so,

issue this command to get rid of the _CRD_ created by the operator:

```bash
for crd in $(oc get crd | grep grafana | awk '{ print $1 }'); do oc delete crd $crd ; done
customresourcedefinition.apiextensions.k8s.io "grafanadashboards.integreatly.org" deleted
customresourcedefinition.apiextensions.k8s.io "grafanadatasources.integreatly.org" deleted
customresourcedefinition.apiextensions.k8s.io "grafananotificationchannels.integreatly.org" deleted
customresourcedefinition.apiextensions.k8s.io "grafanas.integreatly.org" deleted
```

Now that you have a clean environment you can install the [new version](#1-prerequisites)
