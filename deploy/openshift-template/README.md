## Index

<!-- TOC -->

- [Index](#index)
- [Templates available](#templates-available)
- [Template Parameters](#template-parameters)
- [Deploy Grafana instance](#deploy-grafana-instance)
    - [Process the template](#process-the-template)
    - [Create the Dashboard ConfigMap](#create-the-dashboard-configmap)
    - [Connect to Grafana Web UI](#connect-to-grafana-web-ui)
- [Notes](#notes)
    - [Difference between Basic vs. OAuth](#difference-between-basic-vs-oauth)
    - [Querier vs. Tenancy](#querier-vs-tenancy)

<!-- /TOC -->

## Templates available

These are all the templates provided in this project

```bash
deploy/openshift-template/
├── appmon-basic_querier_template.yaml #Ephemeral Storage, Basic Authentication, Thanos Querier Datasource
├── appmon-basic_tenancy_template.yaml #Ephemeral Storage, Basic Authentication, Thanos Tenancy Datasource
├── appmon-oauth_querier_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Querier Datasource (Dedalus Best-Practice)
└── appmon-oauth_tenancy_template.yaml #Persistent Storage, OAuth Proxy Authentication, Thanos Tenancy Datasource
```

You can use the template that better suits your needs.
Check out the parameters accepted by the template before using it.

## Template Parameters

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

## 1 Deploy Grafana instance

Following there are the instructions to deploy
`appmon-oauth_querier_template.yaml`

### 1.1 Process the template

Set the following variables on your client:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
STORAGE_CLASS=myclusterstorageclass
```

Deploy the template via `oc process` client command:

```bash
oc process -f deploy/openshift-template/appmon-oauth_querier_template.yaml \
-p MONITORING_NAMESPACE=$MONITORING_NAMESPACE \
-p STORAGECLASS=$STORAGE_CLASS \
| oc apply -f -
```

```

### 1.3 Connect to Grafana Web UI

Get the OpenShift routes where the services are exposed:

```bash
oc get route -n $MONITORING_NAMESPACE

```

> The `*-admin` route won't use the _OAuth Proxy_ for authentication, but instead will require the admin credentials provided in this secret
`{GRAFANA_INSTANCE_NAME}-admin-credentials`.
The `*-route` one will use the _OAuth Proxy_ but grants only a read-only access.

## Notes

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
