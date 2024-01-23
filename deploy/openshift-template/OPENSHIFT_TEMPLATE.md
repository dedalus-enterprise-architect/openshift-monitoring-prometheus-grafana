# Openshift Template
<!-- markdownlint-disable MD004 -->

Here will be explained how to complete the deploy of Appmon resources using Openshift Templates declarative deploy.

## Index

- [Openshift Template](#openshift-template)
  - [Index](#index)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Procedure](#2-procedure)
    - [2.1 Process the template](#21-process-the-template)
    - [2.2 Template Parameters](#22-template-parameters)
    - [2.3 Connect to the route](#23-connect-to-the-route)
  - [Other Templates](#other-templates)
    - [Difference between Basic vs. OAuth](#difference-between-basic-vs-oauth)
    - [Querier vs. Tenancy](#querier-vs-tenancy)

## 1. Prerequisites

Check the prerequisites on the main [README.md](/README.md)

## 2. Procedure

> WARNING: an Admin Cluster Role is required to proceed on this section.

To install AppMon resources following Dedalus Best-Practice follow these steps:

### 2.1 Process the template

Set the template parameters needed according to the target environment (this example in based on _AWS Cloud_ environment)

```bash
MONITORING_NAMESPACE=dedalus-monitoring
STORAGE_CLASS=gp3-csi
```

Deploy the template via `oc process` client command:

```bash
oc process -f grafana-resources/deploy/openshift-template/appmon-oauth_querier_template.yaml \
-p MONITORING_NAMESPACE=$MONITORING_NAMESPACE \
-p STORAGECLASS=$STORAGE_CLASS \
| oc apply -f -
```

you should get the following output:

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

The following is a list of the accepted template parameters and their default values:

```yaml
parameters:
- name: MONITORING_NAMESPACE
  displayName: AppMon namespace
  description: Namespace where all the resources of AppMon will be deployed
  required: true
  value: dedalus-monitoring
- name: APPMON_SERVICEACCOUNT
  displayName: AppMon service account
  description: Service account to be used by AppMon resources
  required: true
  value: appmon-serviceaccount
- name: GRAFANA_INSTANCE_NAME
  displayName: Grafana instance name
  description: This value will be also used to attach the Dashboards and Datasources created by this template to the Grafana instance
  required: true
  value: appmon-oauth-querier
- name: THANOS_URL
  displayName: Thanos service address:port
  description: Thanos service address:port (9091 or 9092)
  required: true
  value: thanos-querier.openshift-monitoring.svc.cluster.local:9091
- name: STORAGECLASS
  displayName: Storage Class Name
  description: Storage Class to be used to provision persistent storage
  required: true
```

### 2.3 Connect to the route

Get the OpenShift routes where the services are exposed:

```bash
oc get route -n dedalus-monitoring
NAME                         HOST/PORT                                                                                   PATH   SERVICES
   PORT      TERMINATION     WILDCARD
appmon-oauth-querier-admin   appmon-oauth-querier-admin-dedalus-monitoring.apps.rubber-cluster.rubberworld.dedalus.aws          appmon-oauth-querier-service   grafana   edge/Redirect   None
appmon-oauth-querier-route   appmon-oauth-querier-route-dedalus-monitoring.apps.rubber-cluster.rubberworld.dedalus.aws          appmon-oauth-querier-service   https     reencrypt       None

```

> The `*-admin` route won't use the _OAuth Proxy_ for authentication, but instead will require the admin credentials provided in the secret
`{GRAFANA_INSTANCE_NAME}-admin-credentials`.
The `*-route` one will use the _OAuth Proxy_ but grants only a read-only access.

## Other Templates

How you can check there are other templates ready for other scenario

```bash
grafana-resources/deploy/openshift-template/
├── appmon-basic_querier_template.yaml #Ephemeral Storage, Basic Authentication, Thanos Querier Datasource
├── appmon-basic_tenancy_template.yaml #Ephemeral Storage, Basic Authentication, Thanos Tenancy Datasource
├── appmon-oauth_querier_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Querier Datasource (Dedalus Best-Practice)
└── appmon-oauth_tenancy_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Tenancy Datasource
```

You can use the template that better suits your needs.

Be sure to check the parameter accepted by the template that you are going to use.

> :bulb:  **TIPS**  
You can list all parameters of a template using this command:
>
> ```bash
> oc process --parameters=true -f /path/to/template/file.yaml
> ```

### Difference between Basic vs. OAuth

The templates with the `basic` suffix will offer the bare minimum to run all the resources and no persistance at all.

The templates with the `oauth` suffix will create extra resources to enable the following features:

* OAuth Proxy Authentication
* Persistent Storage

Remember to set the right value for the STORAGECLASS parameter when using the persistent storage.

### Querier vs. Tenancy

The templates with the `querier` suffix will connect to the _Thanos_ service exposed to port `9091`.
Grafana instance service account requires the following privilege to access _Thanos_ service:

```bash
"resource": "namespaces", "verb": "get"
```

The templates with the `tenancy` suffix will connect to the _Thanos_ service exposed to port `9092`.
This service won't need the same RBAC of the `querier` but you will need to create a datasource for each namespace from wich you want to read the metrics.
(to help with this task you can use this [template](deploy/openshift-template/datasource/datasource-thanos-tenancy_template.yaml))

The service account will still need `view` access to the namespace from which the metrics are read, you can grant this permission with this command:

```bash
oc adm policy add-role-to-user view system:serviceaccount:${MONITORING_NAMESPACE}:appmon-serviceaccount -n ${TARGET_NAMESPACE}
```
