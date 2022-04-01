# Grafana Operator Setup

This is talks about the community edition of the operator.

## Step by Step procedure

oc apply -n openshift-monitoring-dedalus -f deploy/operators/001_grafana.operator.operatorgroup.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/002_grafana.operator.subscription.yml
<!-- oc apply -n openshift-monitoring-dedalus -f deploy/operators/003_grafana.persistent.oauth.yml -->
oc apply -n openshift-monitoring-dedalus -f deploy/operators/003_grafana.persistent.yml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/004_service_account.yaml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/005_secret.yaml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/006_cluster-role.yaml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/007_cluster_role_bindings.yaml
oc apply -n openshift-monitoring-dedalus -f deploy/operators/008_ocp-inject-cert.yaml

Check Objects

oc get ConfigMap,Secret,Grafana,OperatorGroup,Subscription -n openshift-monitoring-dedalus