# Quickinstallation

Those steps will be divided per role and it will install grafana instance with oauth proxy in front of it.
For any details about the commands here plase refer to the main README.md file
## Index
- [Quickinstallation](#quickinstallation)
  - [Index](#index)
  - [Cluster-Admin](#cluster-admin)
    - [Thanos-Querier](#thanos-querier)
    - [Thanos-Tenancy](#thanos-tenancy)
  - [Namespace-Admin](#namespace-admin)
    - [Thanos-Querier](#thanos-querier-1)
    - [Thanos-Tenancy](#thanos-tenancy-1)
## Cluster-Admin

you still need to passh some information to the Namespace Admin like the THANOS_QUERIER_URL

```bash
oc get route thanos-querier -n openshift-monitoring
```

or

```bash
THANOS_QUERIER_URL=$(oc get route thanos-querier -n openshift-monitoring -o json | jq -r .spec.host)
```

### Thanos-Querier

use the following command

```bash
NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/quickinstallation/quickinstallation_clusteradmin_querier.yaml 
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
```

### Thanos-Tenancy

use the following command

```bash
NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/quickinstallation/quickinstallation_clusteradmin_tenancy.yaml 
-p NAMESPACE=$NAMESPACE \
| oc -n $NAMESPACE create -f -
```

You have to give the permission to the grafana user to view the TARGET_NAMESPACE

```bash
TARGET_NAMESPACE=@TARGET_NAMESPACE@
NAMESPACE=dedalus-monitoring

oc adm policy add-role-to-user view system:serviceaccount:${NAMESPACE}:grafana-serviceaccount -n ${TARGET_NAMESPACE}
```


## Namespace-Admin

you still need to ask to the Cluster Admin the value for THANOS_QUERIER_URL
### Thanos-Querier

use the following command

```bash
NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/quickinstallation/quickinstallation_namespaceadmin_querier.yaml 
-p NAMESPACE=$NAMESPACE \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $NAMESPACE)" \
-p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
| oc -n $NAMESPACE create -f -
```

### Thanos-Tenancy

use the following command

```bash
NAMESPACE=dedalus-monitoring

oc process -f grafana-resources/quickinstallation/quickinstallation_namespaceadmin_tenancy.yaml 
-p NAMESPACE=$NAMESPACE \
-p TOKEN_BEARER="$(oc serviceaccounts get-token grafana-serviceaccount -n $NAMESPACE)" \
-p THANOS_QUERIER_URL=@ask_to_the_cluster_admin@ \
-p TARGET_NAMESPACE=@the_namespace_that you want to monitor@
| oc -n $NAMESPACE create -f -
```