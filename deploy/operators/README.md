# Grafana Operator Setup

This is talks about the community edition of the operator.

## Step by Step procedure

oc apply -n openshift-monitoring-dedalus -f deploy/operators/001_grafana.operator.operatorgroup.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/002_grafana.operator.subscription.yml
<!-- objects -->
oc apply -n openshift-monitoring-dedalus -f deploy/operators/004_service_account.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/005_secret.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/006_configmap-inject-cert.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/007_cluster-role.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/008_cluster_role_bindings.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/009_grafana.persistent.oauth.yml
<!-- oc apply -n openshift-monitoring-dedalus -f deploy/operators/009_grafana.persistent.yml -->
oc apply -n openshift-monitoring-dedalus -f deploy/operators/010_route_access.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/010_route_admin.yml

Check Objects

oc get ConfigMap,Secret,Grafana,OperatorGroup,Subscription -n openshift-monitoring-dedalus

oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard -l app=grafana-dedalus -n openshift-monitoring-dedalus