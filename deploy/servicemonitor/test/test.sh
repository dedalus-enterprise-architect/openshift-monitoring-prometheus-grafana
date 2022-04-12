##!/usr/bin/env bash
##
# =======================================
# AUTHOR        : Serena Sensini@Team EA
# CREATE DATE   : 2022/01/17
# PURPOSE       : Script to extract the template once being logged in Openshift
# SPECIAL NOTES : Integration of the Reloader in the copied template, in order to detect changes in ConfigMaps or Secrets
# =======================================
#

# scaling down the pod when finishes its tasks...
# function scale_down {
#   printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "About to exit in 15 sec..."
#   rm errors.txt
#   sleep 15
#   oc scale dc template-extractor --replicas=0
#   exit 0
# }

# set -o errexit
set -o pipefail
# set -o nounset

function error_handler {
  error="${1//\"/\'}"
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "err" "$error"
  # scale_down
  return 1
}

# :::
# ::: METRICS - START
# :::

# oc image extract $TARGET_IMAGE --path /opt/dedalus/templates/*.yml:.  --insecure=true; [[ -f dedalus.template.yml ]]

function extract_template_files() {
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "Extracting the templates objects..."
  local error=$(oc image extract $TARGET_IMAGE --path /opt/dedalus/templates/*.yml:.  --insecure=true  2>&1 > /dev/null)
  # if oc image extract $TARGET_IMAGE --path /opt/dedalus/templates/*.yml:.  --insecure=true &> errors.txt; then
  if [[ $? -ne 0 ]]; then
    error_handler "$error"
  else
    for f in `find "./" -maxdepth 1 -iname "*.yml" -o -iname "*.yaml"`
    do
      printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "The template file: ${f} has been extracted successfully"
    done
  fi
}

function build_servicemonitor() {

# target template
local filename=$1
# target service port
local serviceport_name=$2

cat << END > servicemonitor-build.sh
##!/usr/bin/env bash

yq e -P -i '.objects += (
{
  "apiVersion": "monitoring.coreos.com/v1",
  "kind": "ServiceMonitor",
  "metadata": {
    "labels": {
      "k8s-app": "\${APP_NAME}-servicemonitor"
    },
    "name": "\${APP_NAME}-servicemonitor"
  },
  "spec": {
    "endpoints": [
      {
        "interval": "30s",
        "port": "${serviceport_name}",
        "scheme": "http",
        "path": "/metrics",
        "relabelings": [
          {
            "action": "replace",
            "regex": "(.*)",
            "replacement": "\$1",
            "separator": ";",
            "sourceLabels": [
              "__meta_kubernetes_namespace"
            ],
            "targetLabel": "namespace"
          },
          {
            "action": "replace",
            "regex": "(.*)",
            "replacement": "\$1",
            "separator": ";",
            "sourceLabels": [
              "__meta_kubernetes_namespace"
            ],
            "targetLabel": "kubernetes_namespace"
          }
        ]
      }
    ],
    "selector": {
      "matchLabels": {
        "app": "\${APP_NAME}"
      }
    },
    "targetLabels": [
      "app"
    ]
  }
}
)' $filename
END

# yq e -P -i '.objects += ({"apiVersion":"monitoring.coreos.com/v1","kind":"ServiceMonitor","metadata":{"labels":{"k8s-app":"${APP_NAME}-servicemonitor"},"name":"${APP_NAME}-servicemonitor","namespace":"${NAMESPACE}"},"spec":{"endpoints":[{"interval":"30s","port":"${serviceport_name}","scheme":"http","path":"/metrics","relabelings":[{"action":"replace","regex":"(.*)","replacement":"$1","separator":";","sourceLabels":["__meta_kubernetes_namespace"],"targetLabel":"namespace"},{"action":"replace","regex":"(.*)","replacement":"$1","separator":";","sourceLabels":["__meta_kubernetes_namespace"],"targetLabel":"kubernetes_namespace"}]}],"selector":{"matchLabels":{"app":"${APP_NAME}"}},"targetLabels":["app"]}})' dedalus.gates.template.json

local error=$(chmod u+x servicemonitor-build.sh && ./servicemonitor-build.sh 2>&1 > /dev/null)
if [[ $? -ne 0 ]]; then
  error_handler "$error"
else
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "build_servicemonitor - the Service Monitor object was added successfully to the template: $FILE"
fi

}

function template_merge() {
  local filename=$1

  # merge file
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "template_merge - About to update the template within additionals objects..."
  local error=$(yq eval-all -i -e '. as $item ireduce ({}; . *+ $item)' $FILE $filename 2>&1 > /dev/null)
  if [[ $? -ne 0 ]]; then
    error_handler "$error"
  else
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "template_merge - the Service Monitor object was added successfully to the template: $FILE"
  fi
}

# extract /opt/dedalus/templates/*.yml files into local folder
# extract_template_files
#
# ::: METRICS - Discovery the Service Monitor template
#
# The Service Monitor object is already defined within the main template
if $(yq -e e '.objects[] | select(.kind == "ServiceMonitor").metadata.name' $FILE &>/dev/null); then
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "The Service Monitor object is already preset within the: $FILE"
else
  # set to either the user's defined if defined or the default filename and check wheather is a regular file.
  if [[ -f "${TEMPLATE_SVCMONITOR_FILENAME:=dedalus.servicemonitor.yml}" ]]; then
    template_merge "$TEMPLATE_SVCMONITOR_FILENAME"
  else
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "warn" "The variable: 'TEMPLATE_SVCMONITOR_FILENAME' was empty or the specified file was not found: $TEMPLATE_SVCMONITOR_FILENAME"
    # The Service Monitor object is not already defined therefore a default settings will be added stricly if the 'service' object expose the port number 8080
    error=$(yq -e e '.objects[] | select(.kind == "Service").spec.ports[]| select(.port == "8080").port' $FILE 2>&1 > /dev/null)
    if [[ $? -ne 0 ]]; then
      error_handler "$error"
    else
      printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "warn" "The Service Monitor has NOT been set. THE DEFAULT ONE WILL BE CREATED!"
      serviceport_name=$(yq -e e '.objects[] | select(.kind == "Service").spec.ports[]| select(.port == "8080").name' $FILE)
      build_servicemonitor "$FILE" "$serviceport_name"
    fi
  fi
fi
# ::: METRICS - END
