# Grafana Operator Resources

This project explain how to Set Up a custom Grafana instance having the following minimum requirements:

 * Grafana Operator - community edition starting from version 4.2.0
 
 * Openshift 4.9 or major

## Grafana operator setup

### Datasource

* give the RBAC permission to the SA: _grafana-serviceaccount_

    ```oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount -n dedalus-monitoring```

* get the token bearer

    ```oc serviceaccounts get-token grafana-serviceaccount -n dedalus-monitoring```

* get the Thanos route

    ```oc get route thanos-querier -n openshift-monitoring -o json | jq .spec.host```

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
          Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IkNoWjNSak5OZFNFRi1Cb3ZGd3dpaXhySU9ZSVRvSE9pYVBBMzlIQjRYdkEifQ.eyJpc3MiOiJrdWJlcm5ldGVzLfewpjfowjoèfj3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWRhbHVzLW1vbml0b3JpbmciLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlY3JldC5uYW1lIjoiZ3JhZmFuYS1zZXJ2aWNlYWt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJncmFmYW5hLXNlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiNjIwYjhjZWMtOTVlZS00ZDBhLWJhMzctMmYzNjE0NDJiMWYyIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZGFsdXMtbW9uaXRvcmluZzpncmFmYW5hLXNlcnZpY2VhY2NvdW50In0.
      type: prometheus
      url: 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091'
  name: prometheus-grafana-ds.yaml
```

### Dashboards

The dashboards can be loaded from:

* within the same namespace where the operator is deployed in

* any namespace if the scan-all feature is enabled (read the guide on [link](https://github.com/grafana-operator/grafana-operator/tree/master/deploy/cluster_roles)


## Grafana Dashboard Variables

> Working in progress


    projects	    up{namespace!~".*openshift-.*|.*kube-.*"}                           .*namespace="(.*?)".*
    application	    up{namespace=~"$projects"}                                          .*app="(.*?)".*
    pod             up{app=~"$application",namespace=~"$projects"}                      .*pod="(.*?)".*
    instance	    up{app=~"$application",pod=~"$pod",namespace=~"$projects"}          .*instance="(.*?)".*
    instance_http	label_values(http_requests_total{app="$application"}, instance)     .*instance="(.*?)".*


regexp:

    .*pod="(.*?)".*instance="(.*?)"

    .*instance="(.*?)".*

    /.*instance="([^"]*).*/

    /pod="(?<text>[^"]+)|instance="(?<value>[^"]+)/g

    label_values(jvm_memory_bytes_used{app="$application", instance="$instance", area="heap"},id)

    jvm_memory_bytes_used{app="$application", instance="$instance", id=~"$jvm_memory_pool_heap"}
