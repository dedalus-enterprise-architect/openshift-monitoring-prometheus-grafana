# Grafana Operator Resources

This project explain how to Set Up a custom Grafana instance having the following minimum requirements:

 * Grafana Operator - community edition starting from version 4.2.0
 
 * Openshift 4.9 or major

References:
  - https://github.com/grafana-operator/grafana-operator

## Grafana operator: Installation

Before start you must choose the rights template:

* __templates/grafanaoperator.template.basic.yml__ : this template aims is installing the Grafana Operator without the following features:

    * ephemeral storage
    * basic login

* __templates/grafanaoperator.template.yml__ : this template aims is installing the Grafana Operator within the following features:

    * persistent storage
    * oAuth Login (it allows the login by the same Openshift user data)

### Creating the Operator's objects

> WARNING: a Cluster Role is required to proceed on this section.

It follows the step by step commands to install the Grafana Operator as well:

* Process the template on fly by passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
        -p DASHBOARD_NAMESPACES_ALL=true \
        -p NAMESPACE=@type_here_the_namespace@ \
        -p STORAGECLASS=@type_here_the_custom_storageclass@ \
        | oc -n @type_here_the_namespace@ create -f -

  where below is shown the command with the placeholder: '**@type_here_the_namespace@**' replaced by the value: 'dedalus-monitoring' and the others parameters have been omitted to load the default settings:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
        -p NAMESPACE=dedalus-monitoring \
        | oc -n dedalus-monitoring create -f -

* Approve the Operator's updates by patching the __InstallPlan__ :

      oc patch InstallPlan/$(oc get --no-headers  InstallPlan|grep grafana-operator|cut -d' ' -f1) --type merge \
       --patch='{"spec":{"approved":true}}' -n @type_here_the_namespace@

> Check Objects

you can get a list of the created objects as follows:

    oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard,ClusterRole,ClusterRoleBinding \
    -l app=grafana-dedalus --no-headers -n **@type_here_the_namespace@** |cut -d' ' -f1

and pay attention in case you wanted deleting any previously created objects at __cluster level__

    oc delete ClusterRole grafana-proxy-@type_here_the_namespace@
    oc delete ClusterRoleBinding grafana-proxy-@type_here_the_namespace@
    oc delete ClusterRoleBinding grafana-cluster-monitoring-view-binding-@type_here_the_namespace@

#### Enabling the dashboards automatic discovery how to

> Consider this section as an *OPTIONAL* task because this feature is enabled by default

The dashboards can be loaded from:

1. within the same namespace where the operator is deployed in

1. any namespace when the *scan-all* feature is enabled (read the guide on [link](https://github.com/grafana-operator/grafana-operator/blob/master/documentation/multi_namespace_support.md))

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

```
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana
```

Make the command to run depending by the template used before. Therefore replace the placeholder: "@type_here_the_grafana_instance_name@":
  - with 'grafana-persistent-oauth' if you used the template: 'grafanaoperator.template.yml'
  - with 'grafana-basic' if you used the template: 'grafanaoperator.template.basic.yml'

and run:

```bash
oc get grafana @type_here_the_grafana_instance_name@ --no-headers -n dedalus-monitoring -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'
```

afterward check that the output looks like as follow:

    grafana-dedalus

otherwise update the object by running the following command but only after you have replaced the placeholder = "__@type_here_the_namespace@__" by the one where the Grafana Operator was installed:

      oc patch grafana/$(oc get --no-headers  grafana/dedalus-grafana |cut -d' ' -f1) --type merge \
       --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
       -n @type_here_the_namespace@

**IMPORTANT**: Use the merge type when patching the CRD object.

### Dashboard objects and its dependencies creation using a template

With the following commands you create the *dashboards presets* including its dependencies objects as well:

* Passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n @type_here_the_namespace@ create -f -


  where below is shown the command with the placeholder: '**@type_here_the_namespace@**' replaced by the value: 'dedalus-monitoring':

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n dedalus-monitoring create -f -

> it follows an alternative way to manage multiple parameters to pass in using an env file as input:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        --param-file=dashboard.template.env | oc create -n @type_here_the_namespace@ -f -
  
  but don't forget to adjust the values within the file: __templates/dashboard.template.env__ before proceed.

## Project's Contents

The directories tree:

- deploy:
    - dashboards:
      - standalone:
        - grafana.dashboard.jvm.advanced.yml
        - grafana.dashboard.jvm.basic.yml
      - grafana.dashboard.jvm.basic.json
      - grafana.dashboard.jvm.basic.yml
      - grafana.dashboard.jvm.json
      - grafana.dashboard.jvm.yml
    - grafana
      - patch-grafana.json
      - patch-grafana.yml
    - servicemonitor
      - dedalus.servicemonitor.yml
    - templates
      - dashboard.template.env
      - dashboard.template.yml
      - grafanaoperator.template.basic.yml
      - grafanaoperator.template.yml

### dashboards

This folder includes the templates used for:

* ```grafana.dashboard.jvm.basic.json```: the JSON dashboard template (not the micrometer version)
* ```grafana.dashboard.jvm.basic.yml```: the _grafanadashboard_ object definition (with link to a remote location)
* ```grafana.dashboard.jvm.json```: the JSON dashboard template (micrometer version)
* ```grafana.dashboard.jvm.yml```: the _grafanadashboard_ object definition
* ```standalone/grafana.dashboard.jvm.advanced.yml```: the _grafanadashboard_ object definition with inline dashboard (micrometer version)
* ```standalone/grafana.dashboard.jvm.basic.yml```: the _grafanadashboard_ object definition with inline dashboard (not the micrometer version)

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

* give the RBAC permission to the SA: _grafana-serviceaccount_

    ```oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@```

    or remove if it needs to restore settings:

    ```oc adm policy remove-cluster-role-from-user cluster-monitoring-view -z grafana-serviceaccount -n @type_here_the_namespace@```

* fill the variable: __TOKEN_BEARER__ getting the token bearer as follow:

    ```oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@```

* fill the variable: __THANOS_QUERIER_URL__ getting the Thanos route as follow:

    ```oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host```

  it follows an output example:

      https://thanos-querier.openshift-monitoring.svc.cluster.local:9091