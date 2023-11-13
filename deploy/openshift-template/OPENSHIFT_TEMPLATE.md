# Openshift Template

Here will be explained how to complete the deploy of Appmon resources using Openshift Templates declarative deploy.

# Index

- [Openshift Template](#openshift-template)
- [Index](#index)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Procedure](#2-procedure)
    - [2.1 Process the template](#21-process-the-template)
    - [2.2 Template Parameters](#22-template-parameters)
    - [2.3 Connect to the route](#23-connect-to-the-route)
  - [Other Templates](#other-templates)
    - [basic vs oauth](#basic-vs-oauth)
    - [querier vs tenancy](#querier-vs-tenancy)

## 1. Prerequisites

Check the prerequisites on the main [README.md](/README.md)

## 2. Procedure

To install AppMon resources following Dedalus Best-Practice follow these steps:

### 2.1 Process the template

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

### 2.2 Template Parameters

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

### 2.3 Connect to the route

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
The service account will still need view access to the namespace from witch the metrics are read, you can grant this permission with this command:

```bash
oc adm policy add-role-to-user view system:serviceaccount:${MONITORING_NAMESPACE}:appmon-serviceaccount -n ${TARGET_NAMESPACE}
```
