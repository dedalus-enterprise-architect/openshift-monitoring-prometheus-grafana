# Grafana Dashboards

Reference:
* https://grafana-operator.github.io/grafana-operator/docs/

This paragraph describes how does the Grafana Dashboard works.

The application to be monitored must meet the following requirements:

* create the servicemonitor object in the namespace where the POD is runnin in (you can see an example on [here](../servicemonitor/dedalus.servicemonitor.yaml))

The dashboard to be added must meet the following requirements:

* must have the `instanceSelectors` defined.
* you need to configure `spec.allowCrossNamespaceImport` to true if the dashboard is in a different namespace of the grafana instance
* a JSON dashboard stored locally or on a remote location must exist

You can see an example [here](./dashboard.template.yaml)

## servicemonitor processing

```bash
for i in $(oc get svc -n test --no-headers | cut -d" " -f1 | grep ".*-8080-tcp"); do echo -e "$i";oc get svc $i --no-headers -n test -o=jsonpath='{.spec.ports[?(@.name=="8080-tcp")].name}'> /dev/null;done
```

## Getting the cluster version

```bash
oc get clusterversion -o jsonpath='{.items[].status.desired.version}{"\n"}' | cut -d. -f1,2
```
