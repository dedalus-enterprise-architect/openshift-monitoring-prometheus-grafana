# Grafana Operator Setup

This is talks about the community edition of the operator.

## Create the objects using the template

It follows the step by step commands to install the Grafana Operator as well.

* Passing the parameters inline:

      oc process -f https://raw.githubusercontent.com/dedalus-enterprise-architect/grafana-resources/master/deploy/templates/grafanaoperator.template.yml \
        -p NAMESPACE=**@type_here_the_namespace@** | oc -n **@type_here_the_namespace@** create -f -

  where below is a final command once the placeholder: '@type_here_the_namespace@' was replaced by the value: 'dedalus-monitoring' :

      oc process -f deploy/templates/grafanaoperator.template.yml -p NAMESPACE=dedalus-monitoring | oc -n dedalus-monitoring create -f -

* Approve the Operator's manual update by a remote patch file:

      oc patch InstallPlan/$(oc get --no-headers  InstallPlan|grep grafana-operator|cut -d' ' -f1) --type merge \
       --patch='{"spec":{"approved":true}}' -n @type_here_the_namespace@

  or pointing to a file locally stored:

      oc patch InstallPlan/$(oc get --no-headers  InstallPlan|grep grafana-operator|cut -d' ' -f1) --type merge \
       --patch='{"spec":{"approved":true}}' -n dedalus-monitoring

## Step by Step procedure - OPTIONAL

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

## Check Objects

you can get the previosuly created objects as follows:

    oc get all,ConfigMap,Secret,Grafana,OperatorGroup,Subscription,GrafanaDataSource,GrafanaDashboard,ClusterRole,ClusterRoleBinding -l app=grafana-dedalus -n **@type_here_the_namespace@**

and pay attention in deleting any objects at __cluster level__

    oc delete ClusterRole grafana-proxy
    oc delete ClusterRoleBinding grafana-proxy
    oc delete ClusterRoleBinding grafana-cluster-monitoring-view-binding