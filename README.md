# Grafana Operator Resources

This project explains how to deploy a custom Grafana instance having the following minimum requirements:

* Grafana Operator - community edition starting from version 4.2.0
* OpenShift/OKD 4.9 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

---
## Index

* 1. [Prerequisites](#Prerequisites)
* 2. [Installation](#Installation)
  * 2.1. [Grafana Operator](#GrafanaOperator)
  * 2.2. [Grafana Operator RBAC](#GrafanaOperatorRBAC)
  * 2.3. [Grafana Instance](#GrafanaInstance)
    * 2.3.1. [Instance Basic](#InstanceBasic)
    * 2.3.2. [Instance oAuth](#InstanceoAuth)
  * 2.4. [Grafana Datasource](#GrafanaDatasource)
    * 2.4.1. [Thanos-Querier](#Thanos-Querier)
    * 2.4.2. [Thanos-Tenancy](#Thanos-Tenancy)
  * 2.5. [Grafana Dashboard](#GrafanaDashboard)
    * 2.5.1. [Prerequisites](#Prerequisites-1)
    * 2.5.2. [How to install](#Howtoinstall)
  * 2.6. [Check Grafana](#CheckGrafana)
    * 2.6.1. [grafana-persistent-oauth-access](#grafana-persistent-oauth-access)
    * 2.6.2. [grafana-persistent-oauth-admin](#grafana-persistent-oauth-admin)
* 3. [Useful commands](#Usefulcommands)
  * 3.1. [Check Objects](#CheckObjects)
  * 3.2. [Enabling the dashboards automatic discovery how to - OPTIONAL](#Enablingthedashboardsautomaticdiscoveryhowto-OPTIONAL)

---
---

##  1. <a name='Prerequisites'></a>Prerequisites

On your client

1. install the OpenShift CLI tool
2. clone the *grafana-resources* repo in your current working folder

On OpenShift

1. at least one namespace (ex. dedalus-app) with a running application exposing metrics already exists
2. create a dedicated monitoring namespace (ex. *dedalus-monitoring*)
3. create a dedicated user (ex. *monitoring-user*)

---
---

##  2. <a name='Installation'></a>Installation

This is the procedure to install the Grafana Operator, to instantiate a working Grafana instance and to configure a Grafana datasource and dashboard.
The following components will be installed and configured:

1. Grafana Operator
2. Grafana Operator RBAC
3. Grafana Instance
4. Grafana Datasource
5. Grafana Dashboard

* All this object will be described in details in their own section
* Different ClusterRoles and Bindings will be added to be compliant with different scenario
* This installation is trying to cover a scenario where a tenancy segregation is required and one where is not
* Each command will explain the user level that you need to compelte that command

---
---

###  2.1. <a name='GrafanaOperator'></a>Grafana Operator

> :warning: **You need Cluster Admin role for this section**

In this section we are going to install the Grafana Operator itself in the monitoring namespace (from now on MONITORING_NAMESPACE), the following objects will be created:

* OperatorGroup
* Subscription
  * "Dashboard Namespace All" will be enabled
  * "installPlanApproval": Manual
* ServiceAccount

Set the following variables and deploy the operator

```bash
MONITORING_NAMESPACE=dedalus-monitoring
DASHBOARD_NAMESPACES_ALL=true

oc process -f grafana-resources/deploy/operator/grafanaoperator.template.yml \
-p DASHBOARD_NAMESPACES_ALL=$DASHBOARD_NAMESPACES_ALL \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

The output should be

```bash
operatorgroup.operators.coreos.com/grafana-operator-group created
subscription.operators.coreos.com/grafana-operator created
serviceaccount/grafana-serviceaccount created
```

*grafanaoperator.template.yml* contains the following parameters:

```yaml
parameters:
- name: NAMESPACE
  displayName: Namespace where the grafana Operator will be installed in
  description: Type the Namespace where the grafana Operator will be installed in
  required: true
  value: dedalus-monitoring
- name: DASHBOARD_NAMESPACES_ALL
  displayName: Dashboards Scan
  description: Type to 'true' wheather you want enable the dashboard discovery across all namespaces
  required: true
  value: "true"
```

Now you have installed all the objects needed by the operator but you need to approve "installPlanApproval", so run:

```bash
oc patch installplan $(oc get ip -n $MONITORING_NAMESPACE -o=jsonpath='{.items[?(@.spec.approved==false)].metadata.name}') -n $MONITORING_NAMESPACE --type merge --patch '{"spec":{"approved":true}}'
```

Expected output

```bash
installplan.operators.coreos.com/install-xxxxx patched
```

The InstallPlan is set to Manual to avoid automatic update on versions that are not tested, please remember that new versions could NOT work as expected.

> :warning: **If you want to skip the description of all steps and avoid deploy choices you can read grafana-resources/quickinstallation/QuickInstallation.md**

---
---

###  2.2. <a name='GrafanaOperatorRBAC'></a>Grafana Operator RBAC

> :warning: **You need Cluster Admin role for this section**

This section will create aggregated permissions needed to manage the new objects created by Grafana Operator, so non-admin users can manage and view the objects.
Create RBAC objects by running

```bash
oc create -f grafana-resources/rbac/aggregate-grafana-admin-edit.yml

oc create -f grafana-resources/rbac/aggregate-grafana-admin-view.yml
```

Expected output

```bash
clusterrole.rbac.authorization.k8s.io/aggregate-grafana-admin-edit created
clusterrole.rbac.authorization.k8s.io/aggregate-grafana-view created
```

---
---

###  2.3. <a name='GrafanaInstance'></a>Grafana Instance

Before starting you must choose the preferred template:

* **deploy/grafana/instance_basic.template.yml** : deploy of the Grafana Operator instance with the following features:
  * ephemeral storage
  * basic login

* **deploy/grafana/instance_oauth.template.yml** : deploy of the Grafana Operator instance with the following features:
  * persistent storage
  * oAuth Login (it allows the login by the same Openshift user data)

---

####  2.3.1. <a name='InstanceBasic'></a>Instance Basic

> :warning: **You need MONITORING_NAMESPACE Admin role for this section if the aggregate RBAC had been created**

Set the following variable and deploy the operator

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/deploy/grafana/instance_basic.template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

---

####  2.3.2. <a name='InstanceoAuth'></a>Instance oAuth

> :warning: **You need Cluster Admin role for this section**

The oAuth instance needs ClusterAdmin privileges to create several objects,
so before yum must provision the following RBAC:

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/rbac/grafanaoperator_oauth_rbac.template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

> :warning: **You need MONITORING_NAMESPACE Admin role for this section**

Set the following variable and deploy the instance

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/deploy/grafana/instance_oauth.template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

Expected output

```bash
grafana.integreatly.org/grafana-persistent-oauth created
route.route.openshift.io/grafana-persistent-oauth-access created
route.route.openshift.io/grafana-persistent-oauth-admin created
```

*grafanaoperator_instance_oauth.template.yml* contains the following parameters:

```yaml
parameters:
- name: NAMESPACE
  displayName: Namespace where the grafana Operator will be installed in
  description: Type the Namespace where the grafana Operator will be installed in
  required: true
  value: dedalus-monitoring
- name: STORAGECLASS
  displayName: Storage Class
  description: Type the Storage Class available on the cluster, if empty the default storageclass will be used
  required: false
  value: 
```

---
---

###  2.4. <a name='GrafanaDatasource'></a>Grafana Datasource

Accessing the custom metrics collected by Prometheus is possible accessing the Thanos services.
Thanos has services published on different ports, which one you will use depends on the kind of RBAC that you can assign to
the Grafana service account.

Here an extensive documentation on what are the differences between the different services:

reference:
<https://cloud.redhat.com/blog/thanos-querier-versus-thanos-querier>

As described in the referenced link you are going to have 2 different endpoints as target for the datasource.
Thanos instance on port

* 9091 named Thanos-Querier:
  * To access this service you will need to have visibility of all namespaces into the cluster
* 9092 named Thanos-Tenancy
  * This allows to give access to a specific application namespace metrics (from now on APPLICATION_NAMESPACE), so you will need to create one datasource for each APPLICATION_NAMESPACE
  * You are going to need view permission on the APPLICATION_NAMESPACE

> :heavy_exclamation_mark: **You must make a choice wich one to configure**
> * **Thanos-Querier if the Cluster-Admin agrees to assign "cluster-monitor-view" RBAC to Grafana service account**
> * **Thanos-Tenancy if the Cluster-Admin DO NOT agree to assign "cluster-monitor-view" RBAC to Grafana service account**

---

####  2.4.1. <a name='Thanos-Querier'></a>Thanos-Querier

##### RBAC for Thanos-Querier

> :warning: **You need Cluster Admin role for this section**

To be able to connect to Thanos-Querier, the service account **grafana-serviceaccount** needs to be able to perform a **get** to all **namespaces**. To achieve this you can assign the ClusterRole **cluster-monitoring-view** permission to the service account.

```bash
oc process -f grafana-resources/rbac/grafana-cluster-monitoring-view-binding_template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc create -n $MONITORING_NAMESPACE -f -
```

Expected output

```bash
clusterrolebinding.rbac.authorization.k8s.io/grafana-cluster-monitoring-view-binding created
```

*grafana-cluster-monitoring-view-binding_template.yml* contains the following parameters:

```yaml
parameters:
- name: NAMESPACE
  displayName: Namespace where the grafana Operator will be installed in
  description: Type the Namespace where the grafana Operator will be installed in
  required: true
  value: dedalus-monitoring
```

As Cluster Admin you will need to share to the MONITORING_NAMESPACE Admin the route to the Thanos-Querier service; here's a way to collect the info, you can use any command you like:

```bash
oc get route thanos-querier -n openshift-monitoring
```

or

```bash
THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host)
```

##### How to install DataSource to Thanos-Querier

> :warning: **You need MONITORING_NAMESPACE Admin role for this section**

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/deploy/datasource/datasource-thanos-querier_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $MONITORING_NAMESPACE)" \
-p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
| oc -n $MONITORING_NAMESPACE create -f -
```

*datasource-thanos-querier_template.yml* contains the following parameters:

```yaml
parameters:
- name: TOKEN_BEARER
  displayName: Openshift Token Bearer
  description: Type the Openshift Token
  required: true
  value:
- name: THANOS_QUERIER_URL
  displayName: Thanos Querier URL
  description: Type the Thanos querier URL
  required: true
  value:
```

---

####  2.4.2. <a name='Thanos-Tenancy'></a>Thanos-Tenancy

##### Prerequisites for Thanos-Tenancy

> :warning: **You need Cluster Admin role for this section**

The port 9092 is not exposed by default from OpenShift, so the first step is to be sure to create a route for it.
One way to do it is the following:

```bash
oc create -f grafana-resources/deploy/datasource/route-thanos-tenancy.yml
```

The second step is to give the right rbac to the service account **grafana-serviceaccount**, in this case it will need permission as viewer on the target namespace:

```bash
APPLICATION_NAMESPACE=dedalus-app
MONITORING_NAMESPACE=dedalus-monitoring

oc adm policy add-role-to-user view system:serviceaccount:${MONITORING_NAMESPACE}:grafana-serviceaccount -n ${APPLICATION_NAMESPACE}
```

As Cluster Admin you will need to share to the MONITORING_NAMESPACE Admin the route to the Thanos-Tenancy service.
Here's a way to collect the info, you can use any command you like:

```bash
oc get route thanos-tenancy -n openshift-monitoring
```

or

```bash
THANOS_TENANCY_URL=$(oc get route thanos-tenancy -n openshift-monitoring -o json | jq -r .spec.host)
```

##### How to install DataSource to Thanos-Tenancy

> :warning: **You need MONITORING_NAMESPACE Admin role for this section**

```bash
APPLICATION_NAMESPACE=dedalus-app
MONITORING_NAMESPACE=dedalus-monitoring


oc process -f grafana-resources/deploy/datasource/datasource-thanos-tenancy_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $MONITORING_NAMESPACE)" \
-p THANOS_TENANCY_URL=@ask_to_the_cluster_admin@ \
-p TARGET_NAMESPACE=$APPLICATION_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

Here a list of all the parameters accepted by this yml and theirs defaults (this information are inside the yaml):

```yaml
parameters:
- name: TARGET_NAMESPACE
  displayName: Openshift namespace for the custom query
  description: Type the namespace where to limit the datasource
  required: true
- name: TOKEN_BEARER
  displayName: Openshift Token Bearer
  description: Type the Openshift Token
  required: true
  value:
- name: THANOS_TENANCY_URL
  displayName: Thanos Tenancy URL
  description: Type the Thanos Tenancy URL (exposed on port 9092)
  required: true
  value:
```

---
---

###  2.5. <a name='GrafanaDashboard'></a>Grafana Dashboard

Dashboards are resources used by the Grafana instance itself, you can create them on OpenShift to automatically upload them into Grafana.
This procedure will add 2 preconfigured dashboards to Grafana about Java Metrics.

####  2.5.1. <a name='Prerequisites-1'></a>Prerequisites

Dashboards are imported following a *matchExpression* defined into the Grafana instance resource that you have created previously.

> NOTES: before proceeding make sure that the following dashboard selector snippet is already configured within the Grafana instance object:

```yaml
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana-dedalus
```

Run the following command to check the configuration; be aware to choose the MONITORING_NAMESPACE:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
oc get grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n $MONITORING_NAMESPACE |cut -d' ' -f1) \
    --no-headers -n $MONITORING_NAMESPACE -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

where the expected output is:

```bash
grafana-dedalus
```

Otherwise update the object by running the following command:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
  oc patch grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n $MONITORING_NAMESPACE |cut -d' ' -f1) --type merge \
   --patch-file=grafana-resources/deploy/operator/patch-grafana.json \
   -n $MONITORING_NAMESPACE
```

**IMPORTANT**: Use the merge type when patching the CRD object.

####  2.5.2. <a name='Howtoinstall'></a>How to install

> :warning: **You need MONITORING_NAMESPACE Admin role for this section**

Create the *dashboards presets* including dependencies:

```bash
MONITORING_NAMESPACE=dedalus-monitoring
oc process -f grafana-resources/deploy/dashboards/dashboard.template.yml \
  -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $MONITORING_NAMESPACE)" \
  -p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
  | oc -n $MONITORING_NAMESPACE create -f -
```

> :warning: **This template will download the dashboard from this repository**
> **If you need a local installation you can use the file in grafana-resources/deploy/dashboards/standalone**

###  2.6. <a name='CheckGrafana'></a>Check Grafana

At this point all the services and configurations needed have been installed.

You can connect to grafana using one of the routes that have been created during the installation of the instance.
Here is an example how to review the routes.

```bash
MONITORING_NAMESPACE=dedalus-monitoring
oc get route -n ${MONITORING_NAMESPACE}
```

You should get 2 routes:

* grafana-persistent-oauth-access
* grafana-persistent-oauth-admin 

You can connect to one of the routes and check if you can see the dashboards.

> :warning: **You will see data in the Dashboard only if there are Service Monitor deployed in the namespace.**  
> **Service monitor are not an Object of this documentation.**
####  2.6.1. <a name='grafana-persistent-oauth-access'></a>grafana-persistent-oauth-access
This route use OAUTH proxy to login you need to use a user that is existing on Openshift. All the users are Read-Only

####  2.6.2. <a name='grafana-persistent-oauth-admin'></a>grafana-persistent-oauth-admin
This route is needed for Grafana Administrator Login - Native Authentication. Credentials stored in the secret "grafana-admin-credentials"



##  3. <a name='Usefulcommands'></a>Useful commands

* give the RBAC permission to the SA: *grafana-serviceaccount*

```bash
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@
```

or remove if it needs to restore settings:

```bash
oc adm policy remove-cluster-role-from-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@
```

* fill the variable: **TOKEN_BEARER** getting the token bearer as follow:

```bash
oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@
```

* fill the variable: **THANOS_QUERIER_URL** getting the Thanos route as follow:

```bash
oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host
```

Here is an output example:

```bash
https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
```

###  3.1. <a name='CheckObjects'></a>Check Objects

you can get a list of the created objects as follows:

```bash
   oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard,ClusterRole,ClusterRoleBinding \
   -l app=grafana-dedalus --no-headers -n **@type_here_the_namespace@** |cut -d' ' -f1
```

and pay attention in case you wanted to delete any previously created objects at **cluster level**

```bash
   oc delete ClusterRole grafana-proxy-@type_here_the_namespace@
   oc delete ClusterRoleBinding grafana-proxy-@type_here_the_namespace@
   oc delete ClusterRoleBinding grafana-cluster-monitoring-view-binding-@type_here_the_namespace@
```

###  3.2. <a name='Enablingthedashboardsautomaticdiscoveryhowto-OPTIONAL'></a>Enabling the dashboards automatic discovery how to - OPTIONAL

> Consider this section as an *OPTIONAL* task because this feature is enabled by default

The dashboards can be loaded in several ways as explained below:

* within the same namespace where the operator is deployed in

* any namespace when the *scan-all* feature is enabled (read the guide on [link](https://github.com/grafana-operator/grafana-operator/blob/master/documentation/multi_namespace_support.md))

The operator can import dashboards from either one, some or all namespaces. By default, it will only look for dashboards in its own namespace.
By setting the  ```DASHBOARD_NAMESPACES_ALL="true"``` env var as in the below snippet of code, the operator can watch for dashboards in other namespaces.

```yaml
  apiVersion: integreatly.org/v1alpha1
  kind: Grafana
  spec:
    config:
      env:
      - name: DASHBOARD_NAMESPACES_ALL
        value: "true"
```
