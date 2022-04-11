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

set -o errexit
set -o pipefail
# set -o nounset

# :::
# ::: METRICS - START
# :::

# oc image extract $TARGET_IMAGE --path /opt/dedalus/templates/*.yml:.  --insecure=true; [[ -f dedalus.template.yml ]]

function extract_template_files() {
  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "Extracting the templates objects..."
  if oc image extract $TARGET_IMAGE --path /opt/dedalus/templates/*.yml:.  --insecure=true &> errors.txt; then
    for f in `find "./" -maxdepth 1 -iname "*.yml" -o -iname "*.yaml"`
    do
      printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "The template file: ${f} has been extracted successfully"
    done
  else
    error=$(<errors.txt)
    error="${error//\"/\'}"
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "err" "$error"
    # scale_down
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

printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "About to update the template within additionals objects..."
chmod u+x servicemonitor-build.sh && ./servicemonitor-build.sh &> errors.txt
if [[ $? -ne 0 ]]; then
    >&2 error=$(<errors.txt)
    error="${error//\"/\'}"
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "err" "$error"
    scale_down
    # return 1
else
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "The Service Monitor object was added successfully to the template: " $filename
fi

}

function create_object() {
  local filename=$1
  # merge file
  yq eval-all '. as $item ireduce ({}; . *+ $item)' dedalus.gates.template.yml file.yml

  printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "About to add the template to the catalog..."
  if oc create -f ./"$filename"  &> errors.txt; then
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "Template added successfully: " $filename
  else
    error=$(<errors.txt)
    error="${error//\"/\'}"
    printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "err" "$error"
    # scale_down
  fi
}

# extract /opt/dedalus/templates/*.yml files into local folder
extract_template_files
#
# ::: METRICS - step 1 - Discovery the Service Monitor template's file name
#
# set to default filename if it found
if [[ -z "$TEMPLATE_SVCMONITOR_FILENAME" && -f dedalus.servicemonitor.yml ]]; then
    create_object "dedalus.servicemonitor.yml"
# set the filename to the user defined
elif [[ -f "$TEMPLATE_SVCMONITOR_FILENAME" ]]; then
    create_object "$TEMPLATE_SVCMONITOR_FILENAME"
else
    #
    # ::: METRICS - step 2 - Discovery wheather the Service Monitor object is already defined within the main template
    #
    # unset SVCMONITOR_FILE
    # printf '{"@timestamp":"%s","level":"%s","message":"%s%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "warn" "The Service Monitor template wasn't found"
    # Check wheather the ServiceMonitor object definition already exists within the main template file
    if $(yq -e e '.objects[] | select(.kind == "ServiceMonitor").metadata.name' $FILE &>/dev/null); then
      printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "info" "The Service Monitor object is already set within the: " $FILE
    else
      #
      # ::: METRICS - step 3 - Build and Append the Service Monitor to the main template automatically
      #
      # it will be added if the service object expose the port number 8080
      if $(yq -e e '.objects[] | select(.kind == "Service").spec.ports[].port' $FILE | grep 8080 &>/dev/null); then
        printf '{"@timestamp":"%s","level":"%s","message":"%s"}\n' "$(date -u +'%FT%T.%3N%:z')" "warn" "The Service Monitor has NOT been set. THE DEFAULT ONE WILL BE CREATED!"
        local serviceport_name=$(yq -e e '.objects[] | select(.kind == "Service").spec.ports[]| select(.port == "8080").name' $FILE)
        build_servicemonitor "$FILE" "$serviceport_name"
        # create_object "dedalus.servicemonitor.default.yml"
      fi
    fi
fi
# ::: METRICS - END
