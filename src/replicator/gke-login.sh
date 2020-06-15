#!/usr/bin/env bash

set -eu

# $CLUSTER   = The name of the GKE cluster (e.g. gke_beamery-staging_europe-west4_devops)
# $REGION    = The GCP region of the GKE cluster (e.g. europe-west4)
# $PROJECT   = The GCP project of th GKE cluster (e.g. beamery-staging)

CLUSTER=${1}
REGION=${2}
PROJECT=${3}

echo ${CLUSTER}
echo ${REGION}
echo ${PROJECT}

gcloud beta container clusters get-credentials "${CLUSTER}" --region "${REGION}" --project "${PROJECT}"
