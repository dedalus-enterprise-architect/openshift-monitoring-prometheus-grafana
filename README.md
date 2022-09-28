# Grafana Operator Resources

This project explain how to deploy a custom Grafana instance having the following minimum requirements:

* Grafana Operator - community edition starting from version 4.2.0
* OpenShift/OKD 4.9 or higher

References:

* <https://github.com/grafana-operator/grafana-operator>

## Index

- [Grafana Operator Resources](#grafana-operator-resources)
  - [Index](#index)
  - [Installation:](#installation)
    - [Prerequisites](#prerequisites)
    - [Grafana Operator](#grafana-operator)
    - [Grafana Operator RBAC](#grafana-operator-rbac)
    - [Grafana Instance](#grafana-instance)
      - [Istance Basic](#istance-basic)
      - [Istance Oauth](#istance-oauth)
    - [Grafana Datasource](#grafana-datasource)
      - [Thanos-Querier](#thanos-querier)
        - [RBAC for Thanos-Querier](#rbac-for-thanos-querier)
        - [How to install DataSource to Thanos-Querier](#how-to-install-datasource-to-thanos-querier)
      - [Thanos-Tenancy](#thanos-tenancy)
        - [Prerequisites for Thanos-Tenancy](#prerequisites-for-thanos-tenancy)
        - [How to install DataSource to Thanos-Tenancy](#how-to-install-datasource-to-thanos-tenancy)
    - [Grafana Dashboard](#grafana-dashboard)
      - [Prerequisites](#prerequisites-1)
      - [How to install](#how-to-install)
- [##########################################](#)
    - [Grafana Instance](#grafana-instance-1)
    - [Grafana Datasource](#grafana-datasource-1)
      - [Thanos-Querier](#thanos-querier-1)
        - [RBAC for Thanos-Querier](#rbac-for-thanos-querier-1)
        - [How to install DataSource to Thanos-Querier](#how-to-install-datasource-to-thanos-querier-1)
      - [Thanos-Tenancy](#thanos-tenancy-1)
        - [Prerequisites for Thanos-Tenancy](#prerequisites-for-thanos-tenancy-1)
        - [How to install DataSource to Thanos-Tenancy](#how-to-install-datasource-to-thanos-tenancy-1)
    - [Grafana Dashboard](#grafana-dashboard-1)
      - [Prerequisites](#prerequisites-2)
      - [How to install](#how-to-install-1)
    - [Creating the Operator's objects](#creating-the-operators-objects)
      - [Enabling the dashboards automatic discovery how to - OPTIONAL](#enabling-the-dashboards-automatic-discovery-how-to---optional)
  - [Grafana operator: Installing the predefined dashboards](#grafana-operator-installing-the-predefined-dashboards)
    - [Pre-Requisites](#pre-requisites)
    - [Dashboard objects and its dependencies creation using a template](#dashboard-objects-and-its-dependencies-creation-using-a-template)
  - [Project's Contents](#projects-contents)
    - [dashboards](#dashboards)
    - [servicemonitor](#servicemonitor)
    - [templates](#templates)
    - [Useful commands](#useful-commands)

## Installation:
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

### Prerequisites

On your client

1. install the OpenShift CLI tool
2. clone the *grafana-resources* repo in your current working folder

On OpenShift

1. create a dedicated namespace (ex. *dedalus-monitoring*)
2. create a dedicated user (ex. *monitoring-user*)

### Grafana Operator

> :warning: **You need Cluster Admin role for this section**

In this section we are going to install the Grafana Operator itself, the following objects will be created:

* OperatorGroup
* Subscription
  * "Dashboard Namespace All" will be enabled
  * "installPlanApproval": Manual
* ServiceAccount

Set the following variables and deploy the operator

```bash
NAMESPACE=dedalus-monitoring
DASHBOARD_NAMESPACES_ALL=true

oc process -f grafana-resources/deploy/operator/grafanaoperator.template.yml \
-p DASHBOARD_NAMESPACES_ALL=$DASHBOARD_NAMESPACES_ALL \
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
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
oc patch installplan $(oc get ip -n $NAMESPACE -o=jsonpath='{.items[?(@.spec.approved==false)].metadata.name}') -n $NAMESPACE --type merge --patch '{"spec":{"approved":true}}'
```

Expected output

```bash
installplan.operators.coreos.com/install-xxxxx patched
```

The InstallPlan is set to Manual to avoid automatic update on versions that are not tested, please remember that new versions could NOT work as expected.

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

### Grafana Instance

Before start you must choose the rights template:

* **deploy/grafana/instance_basic.template.yml** : this template aims is installing the Grafana Operator without the following features:
  * ephemeral storage
  * basic login

* **deploy/grafana/instance_oauth.template.yml** : this template aims is installing the Grafana Operator with the following features:
  * persistent storage
  * oAuth Login (it allows the login by the same Openshift user data)

#### Istance Basic

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Namespace Admin if the aggregate RBAC had been created**

Set the following variable and deploy the operator

```bash
NAMESPACE=dedalus-monitoring

oc project $NAMESPACE
oc process -f grafana-resources/deploy/grafana/instance_basic.template.yml \
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
```

#### Istance Oauth

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**

The Oauth instance will need several obiect that needs the ClusterAdmin right to be created,
so before you can create the istance you need to issue the command:

```bash
NAMESPACE=dedalus-monitoring

oc project $NAMESPACE
oc process -f rbac\grafanaoperator_oauth_rbac.template.yml \
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
```

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Namespace Admin**
Set the following variable and deploy the operator

```bash
NAMESPACE=dedalus-monitoring

oc project $NAMESPACE
oc process -f grafana-resources/deploy/grafana/instance_oauth.template.yml \
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
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

### Grafana Datasource

Accessing the custom metrics collected by Prometheus is possible accessing the Thanos services.
Thanos has services exposed on different ports, you are going to use one port over another based on the kind of RBAC that you can assign to
the grafana service account.

Here an extensive documentation on what are the differences between the different services:

reference:
<https://cloud.redhat.com/blog/thanos-querier-versus-thanos-querier>

As described in the referenced link you are going to have 2 different endpoints as target for the datasource.
Thanos instance on port

* 9091 named Thanos-Querier:
  * To access this service you will need to have visibility of all namespaces into the cluster
* 9092 named Thanos-Tenancy
  * Using this will give you access to one namespace at the time (referred as TARGET_NAMESPACE in the future) so you will need 
  to create one datasource for each namespace
  * You are going to need view permission on the TARGET_NAMESPACE

---

#### Thanos-Querier

##### RBAC for Thanos-Querier

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**  

To be able to connect to Thanos-Querier, the service account **grafana-serviceaccount** needs to be able to perform a **get** to all **namespaces**. To achieve this you can assign the ClusterRole **cluster-monitoring-view** permission to the service account.

```bash
oc process -f grafana-resources/rbac/grafana-cluster-monitoring-view-binding_template.yml | \
oc create -f -
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

As Cluster Admin you will need to share to the Namespace Admin the route to the Thanos-Querier service 
here a way to collect the info, you can use any command you like:

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
> * **Namespace Admin**

```bash
NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/deploy/datasource/datasource-thanos-querier_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $NAMESPACE)" \
-p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
| oc -n ${NAMESPACE} create -f -
```

Here a list of all the parameters accepted by this yml and theirs defaults (this information are inside the yaml):

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

The port 9092 is not exposed by default from openshift so the first step is to be sure to have a route to it,
One way to do it is the following:

```bash
oc create -f grafana-resources/deploy/datasource/route-thanos-tenancy.yml
```

The second step is to give the right rbac to the service account **grafana-serviceaccount**, in this case it will need permission as viewer on the target namespace:

```bash
TARGET_NAMESPACE=@TARGET_NAMESPACE@
NAMESPACE=dedalus-monitoring

oc adm policy add-role-to-user view system:serviceaccount:${NAMESPACE}:grafana-serviceaccount -n ${TARGET_NAMESPACE}
```

As Cluster Admin you will need to share to the Namespace Admin the route to the Thanos-Tenancy service 
here a way to collect the info, you can use any command you like:

```bash
oc get route thanos-tenancy -n openshift-monitoring
```
or
```bash
THANOS_QUERIER_URL=$(oc get route thanos-tenancy -n openshift-monitoring -o json | jq -r .spec.host)
```

##### How to install DataSource to Thanos-Tenancy

> :warning: **You can complete this step with the following permissions:**  
>
> * **Namespace Admin**
>
```bash
NAMESPACE=dedalus-monitoring
TARGET_NAMESPACE=@TARGET_NAMESPACE@


oc process -f grafana_resources/deploy/datasource/datasource-thanos-querier_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
-p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@
-p TARGET_NAMESPACE=${TARGET_NAMESPACE}
| oc -n ${NAMESPACE} create -f -
```
> :warning: **Permessi insufficienti per oc get route:**


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

### Grafana Dashboard

#### Prerequisites

> NOTES: before proceed is important make sure the following dashboard selector snippet is already configured within the Grafana instance object:

```yaml
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana-dedalus
```

It follow the command check to run after you've replaced the "**@type_here_the_namespace@**" placeholder by the one where the Grafana Operator was installed:

```bash
  oc get grafana $(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) \
    --no-headers -n @type_here_the_namespace@ -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

afterward check that the output looks like as follow:

    grafana-dedalus

otherwise update the object by running the following command but only after you've replaced the  "**@type_here_the_namespace@**" placeholder by the one where the Grafana Operator was installed:

```bash
  oc patch grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) --type merge \
   --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
   -n @type_here_the_namespace@
```

**IMPORTANT**: Use the merge type when patching the CRD object.

#### How to install

Non ho avuto modo di lavorare molto sulle dashboard ma vi dico cosa ho usato per i test:

il file ./deploy/dashboards/standalone/grafana.dashboard.jvm.selectable.yml è quella che ho usato per i test
è basato sul file ./deploy/dashboards/grafana_dashboard_selectable.json che ho creato esportando la dashboard da grafana.

Le prove le avevo fatte partendo dalla dashboard basic quindi bisogna fare delle modifiche a quella advanced
quello che avevo fatto sulle dashboard da grafana è stato eliminare la definizione del Datasource e renderlo una variabile.

##########################################
##########################################
##########################################
##########################################
##########################################
=======
This section will create aggregated permissions needed to manage the new objects created by Grafana Operator.

This steps will let to admin/view the new objects by users with no Cluster Admin permissions.

Use these command to create the needed objects:

```bash
oc create -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/rbac/aggregate-grafana-admin-edit.yml

oc create -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/rbac/aggregate-grafana-admin-view.yml
```


### Grafana Instance

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**  
> * **Namespace Admin if the aggregate RBAC had been created**

Before start you must choose the rights template:

* __deploy\grafana\grafanaoperator_instance_basic.template.yml__ : this template aims is installing the Grafana Operator without the following features:
  * ephemeral storage
  * basic login

* __deploy\grafana\grafanaoperator_instance_oauth.template.yml__ : this template aims is installing the Grafana Operator with the following features:
  * persistent storage
  * oAuth Login (it allows the login by the same Openshift user data)

```bash
#Here I set the value of the parameter using a variable on a linux system

NAMESPACE=dedalus-monitoring
>>>>>>> 9c3a965478dd100f6bb400f3cc64001570f8b4d9

oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/grafanaoperator_instance_oauth.template.yml \
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
```

Here a list of all the parameters accepted by this yml and theirs defaults (this information are inside the yaml):

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

### Grafana Datasource

reference:
https://cloud.redhat.com/blog/thanos-querier-versus-thanos-querier

As described in the referenced link you are going to have 2 different endpoints as target for the datasource.
Thanos on port 9091 that we are going to name Thanos-Querier and Thanos on porto 9092 that we are going to name Thanos-Tenancy.

The main difference amon them is the kind of rbac needed to access the data.

---

#### Thanos-Querier

##### RBAC for Thanos-Querier

> :warning: **You can complete this step with the following permissions:**  
>  
> * **Cluster Admin**  

To be able to connect to Thanos-Querier, the service account **__grafana-serviceaccount__**, needs to be able to perform a __get__ to all __namespaces__ to archive this objective you can assign the ClusterRole __cluster-monitoring-view__ to the service account.
One way to do it is the following:

```bash

oc process -f grafana_resources/deploy/grafana/grafana-cluster-monitoring-view-binding_template.yml | \
oc create -f -
```

Here a list of all the parameters accepted by this yml and theirs defaults (this information are inside the yaml):

```yaml
parameters:
- name: NAMESPACE
  displayName: Namespace where the grafana Operator will be installed in
  description: Type the Namespace where the grafana Operator will be installed in
  required: true
  value: dedalus-monitoring
```

##### How to install DataSource to Thanos-Querier
> :warning: **You can complete this step with the following permissions:**  
>
> * **Namespace Admin**

```bash
NAMESPACE=dedalus-monitoring


oc process -f grafana_resources/deploy/datasource/datasource-thanos-querier_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
-p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
| oc -n ${NAMESPACE} create -f -
```

Here a list of all the parameters accepted by this yml and theirs defaults (this information are inside the yaml):

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

The port 9092 is not exposed by default from openshift so the first step is to be sure to have a route to it,
One way to do it is the following:

```bash
oc create -f grafana_resources/deploy/datasource/route-thanos-tenancy.yml
```

The second step is to give the right rbac to the __serviceaccount__ **__grafana-serviceaccount__**, in this case it will need permission as viewver on the target namespace:

```bash
TARGET_NAMESPACE=@TARGET_NAMESPACE@
NAMESPACE=dedalus-monitoring

oc adm policy add-role-to-user view system:serviceaccount:${NAMESPACE}:grafana-serviceaccount -n ${TARGET_NAMESPACE}
```
##### How to install DataSource to Thanos-Tenancy
> :warning: **You can complete this step with the following permissions:**  
>
> * **Namespace Admin**
```bash
NAMESPACE=dedalus-monitoring
TARGET_NAMESPACE=@target_namespace@


oc process -f grafana_resources/deploy/datasource/datasource-thanos-querier_template.yml \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
-p THANOS_QUERIER_URL=$(oc get route thanos-tenancy -n openshift-monitoring -o json | jq -r .spec.host) \
-p TARGET_NAMESPACE=${TARGET_NAMESPACE}
| oc -n ${NAMESPACE} create -f -
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

### Grafana Dashboard

#### Prerequisites

> NOTES: before proceed is important make sure the following dashboard selector snippet is already configured within the Grafana instance object:

```yaml
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana-dedalus
```

It follow the command check to run after you've replaced the "__@type_here_the_namespace@__" placeholder by the one where the Grafana Operator was installed:

```bash
  oc get grafana $(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) \
    --no-headers -n @type_here_the_namespace@ -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

afterward check that the output looks like as follow:

    grafana-dedalus

otherwise update the object by running the following command but only after you've replaced the  "__@type_here_the_namespace@__" placeholder by the one where the Grafana Operator was installed:

```bash
  oc patch grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) --type merge \
   --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
   -n @type_here_the_namespace@
```

**IMPORTANT**: Use the merge type when patching the CRD object.

#### How to install

Non ho avuto modo di lavorare molto sulle dashboard ma vi dico cosa ho usato per i test:

il file ./deploy/dashboards/standalone/grafana.dashboard.jvm.selectable.yml è quella che ho usato per i test
è basato sul file ./deploy/dashboards/grafana_dashboard_selectable.json che ho creato esportando la dashboard da grafana.

Le prove le avevo fatte partendo dalla dashboard basic quindi bisogna fare delle modifiche a quella advanced
quello che avevo fatto sulle dashboard da grafana è stato eliminare la definizione del Datasource e renderlo una variabile.

##########################################
##########################################
##########################################
##########################################
##########################################
### Creating the Operator's objects

> WARNING: a Cluster Role is required to proceed on this section.

It follows the step by step commands to install the Grafana Operator as well:

1. Process the template on fly by passing the parameters inline:

```bash
   oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
     -p DASHBOARD_NAMESPACES_ALL=true \
     -p NAMESPACE=@type_here_the_namespace@ \
     -p STORAGECLASS=@type_here_the_custom_storageclass@ \
     | oc -n @type_here_the_namespace@ create -f -
```

  where below is shown the command with the placeholder: '**@type_here_the_namespace@**' replaced by the value: 'dedalus-monitoring' and the others parameters have been omitted to load the default settings:

```bash
   oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
     -p NAMESPACE=dedalus-monitoring \
     | oc -n dedalus-monitoring create -f -
```

2. Approve the Operator's updates by patching the **InstallPlan** :

```bash
   oc patch InstallPlan/$(oc get --no-headers  InstallPlan|grep grafana-operator|cut -d' ' -f1) --type merge \
    --patch='{"spec":{"approved":true}}' -n @type_here_the_namespace@
```

> Check Objects

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

#### Enabling the dashboards automatic discovery how to - OPTIONAL

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

## Grafana operator: Installing the predefined dashboards

### Pre-Requisites

> NOTES: before proceed is important make sure the following dashboard selector snippet is already configured within the Grafana instance object:

```yaml
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana-dedalus
```

It follow the command check to run after you've replaced the "**@type_here_the_namespace@**" placeholder by the one where the Grafana Operator was installed:

```bash
  oc get grafana $(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) \
    --no-headers -n @type_here_the_namespace@ -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

afterward check that the output looks like as follow:

    grafana-dedalus

otherwise update the object by running the following command but only after you've replaced the  "**@type_here_the_namespace@**" placeholder by the one where the Grafana Operator was installed:

```bash
  oc patch grafana/$(oc get Grafana -l app=grafana-dedalus --no-headers -n @type_here_the_namespace@ |cut -d' ' -f1) --type merge \
   --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
   -n @type_here_the_namespace@
```

**IMPORTANT**: Use the merge type when patching the CRD object.

### Dashboard objects and its dependencies creation using a template

With the following commands you create the *dashboards presets* including its dependencies objects as well:

* Passing the parameters inline:

```bash
  oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
    -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@)" \
    -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
    | oc -n @type_here_the_namespace@ create -f -
```

  where below is shown the command with the placeholder: '**@type_here_the_namespace@**' replaced by the value: 'dedalus-monitoring':

```bash
  oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
    -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
    -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
    | oc -n dedalus-monitoring create -f -
```

> it follows an alternative way to manage multiple parameters to pass in using an env file as input:

```bash
  oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
    --param-file=dashboard.template.env | oc create -n @type_here_the_namespace@ -f -
```
  
  but don't forget to adjust the values within the file: **templates/dashboard.template.env** before proceed.

## Project's Contents

The directories tree:

* deploy:
  * dashboards:
    * standalone:
      * grafana.dashboard.jvm.advanced.yml
      * grafana.dashboard.jvm.basic.yml
    * grafana.dashboard.jvm.basic.json
    * grafana.dashboard.jvm.basic.yml
    * grafana.dashboard.jvm.json
    * grafana.dashboard.jvm.yml
  * grafana
    * patch-grafana.json
    * patch-grafana.yml
  * servicemonitor
    * dedalus.servicemonitor.yml
  * templates
    * dashboard.template.env
    * dashboard.template.yml
    * grafanaoperator.template.basic.yml
    * grafanaoperator.template.yml

### dashboards

This folder includes the templates used for:

* ```grafana.dashboard.jvm.basic.json```: the JSON dashboard template (not the micrometer version)
* ```grafana.dashboard.jvm.basic.yml```: the *grafanadashboard* object definition (with link to a remote location)
* ```grafana.dashboard.jvm.json```: the JSON dashboard template (micrometer version)
* ```grafana.dashboard.jvm.yml```: the *grafanadashboard* object definition
* ```standalone/grafana.dashboard.jvm.advanced.yml```: the *grafanadashboard* object definition with inline dashboard (micrometer version)
* ```standalone/grafana.dashboard.jvm.basic.yml```: the *grafanadashboard* object definition with inline dashboard (not the micrometer version)

### servicemonitor

> ```deploy/servicemonitor/dedalus.servicemonitor.yml```

For each POD which exposes the metrics has to be created a "ServiceMonitor" object.

This object specify both the application (or POD name) and the coordinates of metrics where the prometheus service will scrape.

### templates

This folder includes the templates used for:

* ```dashboard.template.yml```: setup the dashboards preset
* ```grafanaoperator.template.basic.yml```: setup the operator with ephemeral storage
* ```grafanaoperator.template.yml```: setup the operator with full feature

---

### Useful commands

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
