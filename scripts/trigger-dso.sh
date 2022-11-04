#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Console step increment
i=1

# Variables
API_DOMAIN="${API_DOMAIN}"
GITLAB_PROJECT_ID="${GITLAB_PROJECT_ID}"

# Declare script helper
TEXT_HELPER="\nThis script aims to send a request through DSO api to trigger pipelines.


Following flags are available:

  -a  Api gateway url.

  -g  GitLab trigger token

  -k  DSO api manager consummer key.

  -s  DSO api manager consummer secret.

  -h  Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts ha:g:k:s: flag; do
  case "${flag}" in
    a)
      API_DOMAIN=${OPTARG};;
    g)
      GITLAB_TRIGGER_TOKEN=${OPTARG};;
    k)
      CONSUMER_KEY=${OPTARG};;
    s)
      CONSUMER_SECRET=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

if [ -z ${API_DOMAIN} ] || [ -z ${GITLAB_TRIGGER_TOKEN} ] || [ -z ${CONSUMER_KEY} ] || [ -z ${CONSUMER_SECRET} ]; then
  echo "\nArgument(s) missing, you don't specify consumer key, consumer secret or gitlab trigger token."
  print_help
  exit 0
fi


printf "$\n${red}${i}.${no_color} Retrieve DSO api access token.\n\n"
i=$(($i + 1))

CONSUMER_CREDENTIALS=$(echo "${CONSUMER_KEY}:${CONSUMER_SECRET}" | tr -d '\n' | base64)
TOKEN=$(curl -s -X POST ${API_DOMAIN}/oauth2/token \
  -d "grant_type=client_credentials" \
  -H "Authorization: Basic ${CONSUMER_CREDENTIALS}" \
  | jq -r '.access_token')


printf "\n${red}${i}.${no_color} Send request to DSO api.\n\n"
i=$(($i + 1))

URL="${API_DOMAIN}/gitlab/v4/projects/${GITLAB_PROJECT_ID}/trigger/pipeline?ref=main&token=${GITLAB_TRIGGER_TOKEN}"
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "accept: application/json" \
  "${URL}" --form "variables[GIT_BRANCH_DEPLOY]=${BRANCH:-main}" \
  | jq '.'
