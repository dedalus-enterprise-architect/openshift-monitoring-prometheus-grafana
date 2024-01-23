# Grafana Datasources
<!-- markdownlint-disable MD004 MD034 -->

Reference:

* https://grafana-operator.github.io/grafana-operator/docs/
* https://cloud.redhat.com/blog/thanos-querier-versus-thanos-querier

This paragraph describes how does the Grafana Datasources works.

The datasource added must meet the following requirements:

* must have the `instanceSelectors` defined.
* you need to configure `spec.allowCrossNamespaceImport` to true if the datasource is in a different namespace of the grafana instance
* a JSON dashboard stored locally or on a remote location must exist

## Token Bearer

 You can configure the datasource for reading the Token Bearer, to authenticate with Prometheus, directly from a secret using `spec.Valuesfom`

 ```yaml
   spec:
    valuesFrom:
      - targetPath: "secureJsonData.httpHeaderValue1"
        valueFrom:
          secretKeyRef:
            name: "appmon-serviceaccount-api-token"
            key: "token"
 ```
