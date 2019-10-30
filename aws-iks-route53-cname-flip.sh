#!/bin/bash
# set -x
# Allows for weighted routing for services between AWS and IKS targets

#sample input=acciksqal; first 3 = service, middle 3 = IKS or AWS, last 3 = env
input=$1
service=${input:0:3}
dc=${input:3:3}
env=${input:6:3}

#defaults
region="us-west-2"
horizontalLine=`printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -`
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
aws_user=route53-updater


case "${dc}" in
  "aws")
    AWS_WEIGHT=100
    IKS_WEIGHT=0
    ;;
  "iks")
    AWS_WEIGHT=0
    IKS_WEIGHT=100
    ;;
  *)
    echo "Location '${dc}' not found...quitting"
    exit 1
    ;;
esac

case "${env}" in
  "qal"|"prf")
    env="qa"
  ;;
  "e2e")
    env="e2e"
  ;;
  "prd")
    env="prd"
  ;;
   *)
      echo "Enviroment '${env}' not found...quitting"
      exit 1
    ;;
esac

isPCI=`cat /fds_aws_cloudformation/ha/lookups.json | jq -r ".${service}.pci"`
be=`cat /fds_aws_cloudformation/ha/lookups.json | jq -r ".${service}.be"`

if [[ ${isPCI} == 'true' ]]; then
  location="fds${env}pci"
#  hosted_zone_id=Z37G5M8QQZ5Q0M
   hosted_zone_id=Z22UGBJEXQ0XJC
elif [[ ${isPCI} == 'false' ]]; then
  location="fds${env}"
  hosted_zone_id=Z1SUYWP0DLZU1M
fi

# echo "location is $location"

profile="cfao-${location}"

function refreshToken() {
  # echo "input is $1"
  cd /fds_aws_cloudformation/$1; make ott-getkey; cd -
}


function execParams() {
  echo $'\n'$'\n'$horizontalLine
  echo "Received the following parameters"
  echo "==============================================="
  echo "service        : '$service'"
  echo "dc             : '$dc'"
  echo "env            : '$env'"
  echo "is PCI         : '$isPCI'"
  echo "key loc        : '/fds_aws_cloudformation/$location'"
  echo "hosted_zone_id : '$hosted_zone_id'"
  echo "aws profile    : '$profile'"
  echo "be             : '$be'"
  if [[ ${AWS_WEIGHT} -ge 50 ]]; then
    color=${green}
  elif [[ ${AWS_WEIGHT} -lt 50 ]]; then
    color=${red}
  fi
  echo ${color}"AWS Traffic    : '${AWS_WEIGHT}'"${reset}
  if [[ ${IKS_WEIGHT} -ge 50 ]]; then
    color=${green}
  elif [[ ${IKS_WEIGHT} -lt 50 ]]; then
    color=${red}
  fi
  echo ${color}"IKS Traffic    : '${IKS_WEIGHT}'"${reset}
  echo $horizontalLine
}


# function genJson() {
#
# }

refreshToken ${location}
execParams

# aws route53 list-resource-record-sets --hosted-zone-id Z22UGBJEXQ0XJC | grep -A 5 "hosteddataservice-wgt-prf.fdsqapci.a.intuit.com"
# aws route53 list-resource-record-sets --hosted-zone-id ${hosted_zone_id} --profile $aws_user | grep -A 5 $be
# aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}${dc}perfone.json
# aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}${dc}perfzero.json

if [[ ${dc} == "iks" ]]; then 
  # echo "This means we need enable '${service}' in '${dc}' and disable in AWS"
  aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}${dc}${env}one.json
  aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}aws${env}zero.json
else
  # echo "This means we need to enable '${service}' in '${dc}' and disable in IKS"
  aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}${dc}${env}one.json
  aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --profile $aws_user --change-batch file:///fds_aws_cloudformation/ha/${service}iks${env}zero.json
fi 

#update_stack_cmd --stack-name $STACK \
#                 --template-body file://$(dirname $0)/../base/route53-weighted-cname.yml \
#                 --parameters \
#                   ParameterKey=Route53ZoneName,ParameterValue=${R53_DOMAIN} \
#                   ParameterKey=TemporaryCname,ParameterValue=${HDS_CNAME} \
#                   ParameterKey=IksWsiEndpoint,ParameterValue=${HDS_IKS} \
#                   ParameterKey=AwsWsiEndpoint,ParameterValue=${HDS_AWS} \
#                   ParameterKey=IksTrafficWeight,ParameterValue=${IKS_WEIGHT} \
#                   ParameterKey=AwsTrafficWeight,ParameterValue=${AWS_WEIGHT} \
#                 --capabilities CAPABILITY_IAM

#wait_for_stack_complete "$STACK"
