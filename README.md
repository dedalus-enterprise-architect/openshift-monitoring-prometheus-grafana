# Grafana Operator Resources

This project explain how to Set Up a custom Grafana instance having the following minimum requirements:

 * Grafana Operator - community edition starting from version 4.2.0
 
 * Openshift 4.9 or major

## Grafana operator setup

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

### Templates

#### Pre-Requisites

> NOTES: before proceed is important make sure the following dashboard selector snippet is already configured within the Grafana instance object:

```
  dashboardLabelSelector:
    - matchExpressions:
        - key: app
          operator: In
          values:
            - grafana
```

otherwise run the following command but only after you have replaced the placeholder = "__@type_here_the_namespace@__" by the one where the Grafana Operator was installed:

      oc patch grafana/$(oc get --no-headers  grafana/dedalus-grafana |cut -d' ' -f1) --type merge \
       --patch="$(curl -s https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/grafana/patch-grafana.json)" \
       -n @type_here_the_namespace@

**IMPORTANT**: Use the merge type when patching the CRD object.

#### Create the objects using the template

It follows some optionals command to create all objects as well.

* Passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n **@type_here_the_namespace@**)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n **@type_here_the_namespace@** create -f -


  where below is a final command afterward the paramaters was replaced:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/dashboard.template.yml \
        -p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring)" \
        -p THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host) \
        | oc -n dedalus-monitoring create -f -

* Passing the parameters by an env file as input:

      oc process -f dashboard.template.yml --param-file=dashboard.template.env | oc create -n **@type_here_the_namespace@** -f -
  
  but don't forget to adjust the values within the file: __dashboard.template.env__ before proceed.

## ServiceMonitor

For each POD which exposes the metrics has to be created a "ServiceMonitor" object.

This object specify both the application (or POD name) and the coordinates of metrics where the prometheus service will scrape.


> Clipboard

    oc get clusterversion -o jsonpath='{.items[].status.desired.version}{"\n"}' | cut -d. -f1,2