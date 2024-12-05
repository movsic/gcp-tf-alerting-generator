set -u
if [[ -z "$PROJECT_ID" ]]; then
    echo "Must provide PROJECT_ID variable in environment" 1>&2
    exit 1
fi

ACCESS_TOKEN=$(gcloud auth print-access-token)

CONFIG_FILE=config.txt
OUTPUT_FILE=config.yaml

> ${OUTPUT_FILE}

while IFS= read -r LINE; do
    echo "LINE: ${LINE}"
    METRIC_ID=$(echo $LINE | cut -d: -f1)
    METRIC_ID=$(echo $METRIC_ID | tr -d \# | tr -d ' ')
    ALERT_DESCRIPTION=$(echo $LINE | cut -d: -f2 | xargs)
    
    echo "METRIC_ID: $METRIC_ID"
    echo "ALERT_DESCRIPTION: $ALERT_DESCRIPTION"

    IS_COMMENTED_LINE=""

    METRIC_DESCRIPTOR=$(curl -s \
    "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/metricDescriptors/${METRIC_ID}" \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Accept: application/json" \
    --compressed)

    METRIC_NAME=$(echo ${METRIC_DESCRIPTOR} | jq ".name")
    METRIC_DISPLAY_NAME=$(echo ${METRIC_DESCRIPTOR} | jq ".displayName")
    METRIC_DESCRIPTION=$(echo ${METRIC_DESCRIPTOR} | jq ".description")
    RESOURCE_TYPE=$(echo ${METRIC_DESCRIPTOR} | jq ".monitoredResourceTypes[0]")
    METRIC_KIND=$(echo ${METRIC_DESCRIPTOR} | jq  ".metricKind")
    VALUE_TYPE=$(echo ${METRIC_DESCRIPTOR} | jq  ".valueType")

    MONITORED_RESOURCE_DESCRIPTOR=$(curl -s \
    "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/monitoredResourceDescriptors/${RESOURCE_TYPE}" \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Accept: application/json" \
    --compressed)

    MONITORED_RESOURCE_NAME=$(echo ${METRIC_DESCRIPTOR} | jq ".displayName")
    MONITORED_RESOURCE_DESCRIPTION=$(echo ${METRIC_DESCRIPTOR} | jq ".description")

    if [[ ${LINE} == \#* ]]; then
        IS_COMMENTED_LINE="# "
    fi

    echo "${IS_COMMENTED_LINE}- description: \"${ALERT_DESCRIPTION}\"" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  metric_id: \"${METRIC_ID}\"" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  resource_type: ${RESOURCE_TYPE}"  >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  metric_kind: ${METRIC_KIND}" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  value_type: ${VALUE_TYPE}" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  severity: \"warning\"" >> ${OUTPUT_FILE}
    #The comparison to apply between the time series (indicated by filter and aggregation) and the threshold (indicated by threshold_value). The comparison is applied on each time series, with the time series on the left-hand side and the threshold on the right-hand side. Only COMPARISON_LT and COMPARISON_GT are supported currently.
    echo "${IS_COMMENTED_LINE}  comparison: \"COMPARISON_GT\"" >> ${OUTPUT_FILE}
    #The amount of time that a time series must fail to report new data to be considered failing.
    echo "${IS_COMMENTED_LINE}  duration: \"60s\"" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  threshold: \"1\"" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  aligners: \"1\"" >> ${OUTPUT_FILE}
    echo "${IS_COMMENTED_LINE}  - aligner: \"ALIGN_PERCENT_CHANGE\"" >> ${OUTPUT_FILE} #ALIGN_PERCENT_CHANGE
    echo "${IS_COMMENTED_LINE}    alignment_period: \"86400s\"" >> ${OUTPUT_FILE} #86400s
    echo "${IS_COMMENTED_LINE}  documentation: \"documentation\"" >> ${OUTPUT_FILE}
    echo >> ${OUTPUT_FILE}

done < "${CONFIG_FILE}"
