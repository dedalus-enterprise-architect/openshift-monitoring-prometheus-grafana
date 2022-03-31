# Grafana Operator Setup

This is talks about the community edition of the operator.

## Step by Step procedure

oc apply -n test-monitoring -f deploy/operators/grafana.operator.operatorgroup.yml
oc apply -n test-monitoring -f deploy/operators/grafana.operator.subscription.yml
