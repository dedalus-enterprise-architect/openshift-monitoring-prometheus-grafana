# Grafana Operator Resources

This project explain how to deploy a custom Grafana instance having the following minimum requirements:

* Grafana Operator - community edition starting from version 4.2.0
* OpenShift/OKD 4.9 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

---

## Index

* [Grafana Operator Resources](#grafana-operator-resources)
  * [Index](#index)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
    * [Grafana Operator](#grafana-operator)
    * [Grafana Operator RBAC](#grafana-operator-rbac)
    * [Grafana Instance](#grafana-instance)
      * [Instance Basic](#instance-basic)
      * [Instance oAuth](#instance-oauth)
    * [Grafana Datasource](#grafana-datasource)
      * [Thanos-Querier](#thanos-querier)
        * [RBAC for Thanos-Querier](#rbac-for-thanos-querier)
        * [How to install DataSource to Thanos-Querier](#how-to-install-datasource-to-thanos-querier)
      * [Thanos-Tenancy](#thanos-tenancy)
        * [Prerequisites for Thanos-Tenancy](#prerequisites-for-thanos-tenancy)
        * [How to install DataSource to Thanos-Tenancy](#how-to-install-datasource-to-thanos-tenancy)
    * [Grafana Dashboard](#grafana-dashboard)
      * [Prerequisites](#prerequisites-1)
      * [How to install](#how-to-install)
  * [Useful commands](#useful-commands)
    * [Check Objects](#check-objects)
    * [Enabling the dashboards automatic discovery how to - OPTIONAL](#enabling-the-dashboards-automatic-discovery-how-to---optional)

---
---

## Prerequisites

On your client

1. install the OpenShift CLI tool
2. clone the *grafana-resources* repo in your current working folder

On OpenShift

1. at least one namespace (ex. dedalus-app) with a running application exposing metrics already exists
2. create a dedicated monitoring namespace (ex. *dedalus-monitoring*)
3. create a dedicated user (ex. *monitoring-user*)

---
---

## Installation

This is the procedure to install the Grafana Operator, to instantiate a working grafana instance and to configure a grafana datasource and bashboard, the following components will be installed and configured:

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

### Grafana Operator

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


> :warning: **If you want to install all the resources quickly you can read grafana-resources/quickinstallation/QuickInstallation.md**
> **It will skip the description of all steps and will short the number of choices that you have to make to complete the installation**

---
---

### Grafana Operator RBAC

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

### Grafana Instance

Before starting you must choose the preferred template:

* **deploy/grafana/instance_basic.template.yml** : deploy of the Grafana Operator instance with the following features:
  * ephemeral storage
  * basic login

* **deploy/grafana/instance_oauth.template.yml** : deploy of the Grafana Operator instance with the following features:
  * persistent storage
  * oAuth Login (it allows the login by the same Openshift user data)

---

#### Instance Basic

> :warning: **You can complete this step with the following permissions:**  
>  
> * **MONITORING_NAMESPACE Admin if the aggregate RBAC had been created**

Set the following variable and deploy the operator

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/deploy/grafana/instance_basic.template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

---

#### Instance oAuth

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**

The oAuth instance needs ClusterAdmin privileges to create several objects,
so before yum must provision the following RBAC:

```bash
MONITORING_NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/rbac/grafanaoperator_oauth_rbac.template.yml \
-p NAMESPACE=$MONITORING_NAMESPACE \
| oc -n $MONITORING_NAMESPACE create -f -
```

> :warning: **You can complete this step with the following permissions:**  
>  
> * **MONITORING_NAMESPACE Admin**
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

### Grafana Datasource

Accessing the custom metrics collected by Prometheus is possible accessing the Thanos services.
Thanos has services published on different ports, which one you will use depends on the kind of RBAC that you can assign to
the grafana service account.

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

---

#### Thanos-Querier

##### RBAC for Thanos-Querier

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**  

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

> :warning: **You can complete this step with the following permissions:**  
>
> * **MONITORING_NAMESPACE Admin**

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

#### Thanos-Tenancy

##### Prerequisites for Thanos-Tenancy

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**

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

As Cluster Admin you will need to share to the Namespace Admin the route to the Thanos-Tenancy service 
here a way to collect the info, you can use any command you like:

```bash
oc get route thanos-tenancy -n openshift-monitoring
```

or

```bash
THANOS_TENANCY_URL=$(oc get route thanos-tenancy -n openshift-monitoring -o json | jq -r .spec.host)
```

##### How to install DataSource to Thanos-Tenancy

> :warning: **You can complete this step with the following permissions:**  
>
> * **MONITORING_NAMESPACE Admin**
>
```bash
APPLICATION_NAMESPACE=dedalus-app
MONITORING_NAMESPACE=dedalus-monitoring


oc process -f grafana_resources/deploy/datasource/datasource-thanos-tenancy_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $MONITORING_NAMESPACE)" \
-p THANOS_TENANCY_URL=@ask_to_the_cluster_admin@
-p APPLICATION_NAMESPACE=$APPLICATION_NAMESPACE
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
- name: THANOS_QUERIER_URL
  displayName: Thanos Querier URL
  description: Type the Thanos querier URL
  required: true
  value:
```

---
---

### Grafana Dashboard

Dashboards are resources used by the Grafana instance itself, you can create them on Openshift to automatically upload them into Grafana.
This procedure will add 2 preconfigured dashboards to Grafana about Java Metrics.
#### Prerequisites

The Dashboard are imported following a matchExpression defined into the Grafana Instance resource that you have created previously.

> NOTES: before proceed is important make sure the following dashboard selector snippet is already configured within the Grafana instance object:

```yaml
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana-dedalus
```

It follow the command to check the configuration be aware you have to choose the **NAMESPACE** where you installed grafana

```bash
NAMESPACE=dedalus-monitoring
  oc get grafana $(oc get Grafana -l app=grafana-dedalus --no-headers -n ${NAMESPACE} |cut -d' ' -f1) \
    --no-headers -n${NAMESPACE} -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

afterward check that the output looks like as follow:

    grafana-dedalus

otherwise update the object by running the following command

```bash
NAMESPACE=dedalus-monitoring
  oc patch grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n ${NAMESPACE} |cut -d' ' -f1) --type merge \
   --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/operator/patch-grafana.json)" \
   -n ${NAMESPACE}
```

**IMPORTANT**: Use the merge type when patching the CRD object.

#### How to install


> :warning: **You can complete this step with the following permissions:**  
>
> * **Namespace Admin**

With the following commands you create the *dashboards presets* including its dependencies objects as well

```bash
NAMESPACE=dedalus-monitoring
  oc process -f grafana-resources/deploy/dashboards/dashboard.template.yml \
    -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
    -p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
    | oc -n ${NAMESPACE} -f -
```

> :warning: **This template will download the dashboard from the this own repository**
> **If you need a local installation you can use the file in grafana-resources/deploy/dashboards/standalone**

## Useful commands

* give the RBAC permission to the SA: *grafana-serviceaccount*

    ```oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@```

    or remove if it needs to restore settings:

    ```oc adm policy remove-cluster-role-from-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@```

* fill the variable: **TOKEN_BEARER** getting the token bearer as follow:

    ```oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@```

* fill the variable: **THANOS_QUERIER_URL** getting the Thanos route as follow:

    ```oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host```

  it follows an output example:

      https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
### Check Objects

you can get a list of the created objects as follows:

```bash
   oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard,ClusterRole,ClusterRoleBinding \
   -l app=grafana-dedalus --no-headers -n **@type_here_the_namespace@** |cut -d' ' -f1
```

and pay attention in case you wanted deleting any previously created objects at **cluster level**

```bash
   oc delete ClusterRole grafana-proxy-@type_here_the_namespace@
   oc delete ClusterRoleBinding grafana-proxy-@type_here_the_namespace@
   oc delete ClusterRoleBinding grafana-cluster-monitoring-view-binding-@type_here_the_namespace@
```

### Enabling the dashboards automatic discovery how to - OPTIONAL

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
