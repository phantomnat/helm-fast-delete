#!/usr/bin/env bash
set -euo pipefail

HELM="${HELM_BIN} --host ${TILLER_HOST} --tiller-namespace ${TILLER_NAMESPACE}"
KUBECTL="kubectl"

POSITIONAL=()
FLAG_PURGE="--purge"
NAMESPACE="${TILLER_NAMESPACE}"
SHOW_HELP=0
GRACE_PERIOD=0

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --tiller-namespace)
    TILLER_NAMESPACE="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--namespace)
    NAMESPACE="$2"
    shift # past argument
    shift # past value
    ;;
    --grace-period)
    GRACE_PERIOD="$2"
    shift # past argument
    shift # past value
    ;;
    --no-purge)
    FLAG_PURGE=""
    shift # past argument
    ;;
    --help)
    SHOW_HELP=1
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    # echo "${POSITIONAL}"
    shift # past argument
    ;;
esac
done
# set -- "${POSITIONAL[@]}" # restore positional parameters
# echo "${POSITIONAL}"

if [ "${SHOW_HELP}" -eq 1 ]; then
    echo "Delete helm release incredibly fast

Usage: helm fast-delete {release-name} [FLAGS]

Flags:
    --namespace            specify namespace (default \$TILLER_NAMESPACE)
    --no-purge             remove --purge flag from helm delete
    --grace-period         grace-period parameter for kubectl (default 0)
"
    exit 0
fi
if [ "${#POSITIONAL[@]}" -lt 1 ]; then
    echo 'Release Name required'
    exit 1
fi
if [ "${GRACE_PERIOD}" -lt 0 ]; then
    echo 'invalid --grace-period'
    exit 1
fi

RELEASE_NAME="${POSITIONAL[0]}"
KUBECTL_FLAGS="-l release=${RELEASE_NAME} --grace-period=${GRACE_PERIOD} --force --namespace ${NAMESPACE}"
echo "deleting release name: ${RELEASE_NAME}"

( \
    ${HELM} delete ${FLAG_PURGE} ${RELEASE_NAME} > /dev/null 2>&1 & \
    ${KUBECTL} delete sts ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete deploy ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete job ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete sa ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete cm ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete secret ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete ing ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete svc ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete pdb ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete pod ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete rolebindings ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    ${KUBECTL} delete roles ${KUBECTL_FLAGS} > /dev/null 2>&1 & \
    wait \
);

echo 'waiting for empty pod' && \
( \
    while ! ${KUBECTL} get pod -l "release=${RELEASE_NAME}" 2>&1 | grep "No resources found" > /dev/null 2>&1; do \
        sleep 6 && echo 'still waiting..'; \
        ${KUBECTL} delete pod ${KUBECTL_FLAGS} > /dev/null 2>&1; \
    done \
);

sleep 3
echo 'removing pvc ...'
${KUBECTL} delete pvc -l "release=${RELEASE_NAME}" > /dev/null 2>&1;

echo 'checking all resources have been removed' && \
( \
    while ! ${KUBECTL} get all,ing,pvc,sa,cm,secret,roles,rolebindings -l "release=${RELEASE_NAME}" 2>&1 | grep "No resources found" > /dev/null 2>&1; do \
        sleep 5 && echo 'still waiting..'; \
    done \
) && \
echo "done!";