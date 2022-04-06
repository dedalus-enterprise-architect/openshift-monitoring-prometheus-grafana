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
    * oAuth Login (it allows the login by the same Openshift user datas)

> IMPORTANT: an user cluster role is needed in order to run the following commands.


### Creating the Operator's objects

It follows the step by step commands to install the Grafana Operator as well.

* Process the template on fly by passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
        -p NAMESPACE=@type_here_the_namespace@ | oc -n @type_here_the_namespace@ create -f -

  where below is a final command after the placeholder: '**@type_here_the_namespace@**' was replaced by the value: 'dedalus-monitoring' :

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
        -p NAMESPACE=dedalus-monitoring | oc -n dedalus-monitoring create -f -

* Approve the Operator's updates by patching the __InstallPlan__ :

      oc patch InstallPlan/$(oc get --no-headers  InstallPlan|grep grafana-operator|cut -d' ' -f1) --type merge \
       --patch='{"spec":{"approved":true}}' -n @type_here_the_namespace@

> Check Objects

you can get a list of the created objects as follows:

    oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard,ClusterRole,ClusterRoleBinding -l app=grafana-dedalus -n **@type_here_the_namespace@**

and pay attention in case you wanted deleting any previously created objects at __cluster level__

    oc delete ClusterRole grafana-proxy
    oc delete ClusterRoleBinding grafana-proxy
    oc delete ClusterRoleBinding grafana-cluster-monitoring-view-binding

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

Proceed running the following command:

```oc get grafana grafana-basic --no-headers -n dedalus-monitoring -o=jsonpath='{.spec.dashboardLabelSelector[0].matchExpressions[?(@.key=="app")].values[]}'```

and check the output is:

    grafana-dedalus

otherwise update the object by running the following command but only after you have replaced the placeholder = "__@type_here_the_namespace@__" by the one where the Grafana Operator was installed:

      oc patch grafana/$(oc get --no-headers  grafana/dedalus-grafana |cut -d' ' -f1) --type merge \
       --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
       -n @type_here_the_namespace@

**IMPORTANT**: Use the merge type when patching the CRD object.

### Dashboard objects and its dependencies creation using a template

It follows some optionals command to create all objects as well.

* Passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n @type_here_the_namespace@)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n @type_here_the_namespace@ create -f -

  where below is a final command after the placeholder: '**@type_here_the_namespace@**' was replaced by the value: 'dedalus-monitoring':

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n dedalus-monitoring create -f -

> if you had several parameters to manage is prefereable passing the parameters by an env file as input like in the example below:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        --param-file=dashboard.template.env | oc create -n @type_here_the_namespace@ -f -
  
  but don't forget to adjust the values within the file: __templates/dashboard.template.env__ before proceed.


## Project's Contents

### Datasource

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

* Replace both the ${TOKEN_BEARER} and the ${THANOS_QUERIER_URL} variables with the previous command output above into the file: _grafana.datasource.yml_

__the original template__

```
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDataSource
metadata:
  name: prometheus-grafana-ds
spec:
  datasources:
    - access: proxy
      editable: true
      isDefault: true
      jsonData:
        httpHeaderName1: Authorization
        timeInterval: 5s
        tlsSkipVerify: true
      name: Prometheus
      secureJsonData:
        httpHeaderValue1: >-
          Bearer ${TOKEN_BEARER}
      type: prometheus
      url: '${THANOS_QUERIER_URL}'
  name: prometheus-grafana-ds.yaml
```

__the target template__

```
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDataSource
metadata:
  name: prometheus-grafana-ds
spec:
  datasources:
    - access: proxy
      editable: true
      isDefault: true
      jsonData:
        httpHeaderName1: Authorization
        timeInterval: 5s
        tlsSkipVerify: true
      name: Prometheus
      secureJsonData:
        httpHeaderValue1: >-
          Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IkNoWjNSak5OZFNFRi1Cb3ZGd3dpaXhySU9ZSVRvSE9pYVBBMzlIQjRYdkEif.
      type: prometheus
      url: 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091'
  name: prometheus-grafana-ds.yaml
```

### Dashboards

The dashboards can be loaded from:

* within the same namespace where the operator is deployed in

* any namespace if the scan-all feature is enabled (read the guide on [link](https://github.com/grafana-operator/grafana-operator/tree/master/deploy/cluster_roles))


#### Grafana Dashboard Variables

> Working in progress


    projects:  	    up{namespace!~".*openshift-.*|.*kube-.*"}                           .*namespace="(.*?)".*
    application	    up{namespace=~"$projects"}                                          .*app="(.*?)".*
    pod             up{app=~"$application",namespace=~"$projects"}                      .*pod="(.*?)".*
    instance	      up{app=~"$application",pod=~"$pod",namespace=~"$projects"}          .*instance="(.*?)".*
    instance_http	label_values(http_requests_total{app="$application"}, instance)       .*instance="(.*?)".*


> regexp examples:

    .*pod="(.*?)".*instance="(.*?)"
    .*instance="(.*?)".*
    /.*instance="([^"]*).*/
    /pod="(?<text>[^"]+)|instance="(?<value>[^"]+)/g
    label_values(jvm_memory_bytes_used{app="$application", instance="$instance", area="heap"},id)
    jvm_memory_bytes_used{app="$application", instance="$instance", id=~"$jvm_memory_pool_heap"}

## ServiceMonitor

For each POD which exposes the metrics has to be created a "ServiceMonitor" object.

This object specify both the application (or POD name) and the coordinates of metrics where the prometheus service will scrape.


> Clipboard

    oc get clusterversion -o jsonpath='{.items[].status.desired.version}{"\n"}' | cut -d. -f1,2