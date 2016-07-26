#!/bin/bash -e

usage(){
  echo -e "\n$0: environment [a,b] [region]\n"
  echo -e "Switches one of paasA/B to live elbs and deregisters the other."
  exit 1
}

[ $# -lt 2 ] && usage

if [ $# -gt 2 ]; then
  REGION="$3"
else
  REGION=${AWS_DEFAULT_REGION}
fi

if [ "x${REGION}x" == "xx" ]; then
  echo "Error: Either specify the aws region for ${ENVIRONMENT} or ensure AWS_DEFAULT_REGION is set."
  exit
fi

if [ "x${AWS_ACCESS_KEY_ID}x" == "xx" ] || [ "x${AWS_SECRET_ACCESS_KEY}x" == "xx" ]; then
  echo "Error: Ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set."
  exit 1
fi

STACK_ID=`echo "$2" | tr '[:upper:]' '[:lower:]'`

case $STACK_ID in
  a)
    OTHER_STACK_ID="b"
    ;;
  b)
    OTHER_STACK_ID="a"
    ;;
  *)
    usage
    ;;
esac

ENVIRONMENT=${1}

if echo "${ENVIRONMENT}" | grep -qi "prod"; then
  echo ""
  read -p "WARNING: Selected environment ${ENVIRONMENT} contains the word \"prod\". Continue (y/n)?" yn
  echo ""
  case $yn in
    [Yy]*)
      ;;
    [Nn]*) 
      exit
      ;;
  esac
fi

ansible-playbook -i inventory/ elb-register.yaml --limit=${REGION} --limit="tag_Environment_${ENVIRONMENT}:&tag_Role_k8_loadbalancer" -e region=${REGION} -e bitesize_environment=${ENVIRONMENT} -e stack_id=${STACK_ID} -e elb=live -e state=present

[ ! $? -eq 0 ] && echo "Error: Adding stack ${STACK_ID} to live elb for ${ENVIRONMENT}: $rc." && exit 1

ansible-playbook -i inventory/ elb-register.yaml --limit=${REGION} --limit="tag_Environment_${ENVIRONMENT}:&tag_Role_k8_loadbalancer" -e region=${REGION} -e bitesize_environment=${ENVIRONMENT} -e stack_id=${OTHER_STACK_ID} -e elb=live -e state=absent

[ ! $? -eq 0 ] && echo "Error: Removing stack ${OTHER_STACK_ID} from live elb for ${ENVIRONMENT}: $rc." && exit 1

ansible-playbook -i inventory/ elb-register.yaml --limit=${REGION} --limit="tag_Environment_${ENVIRONMENT}:&tag_Role_k8_loadbalancer" -e region=${REGION} -e bitesize_environment=${ENVIRONMENT} -e stack_id=${STACK_ID} -e elb=prelive -e state=absent

[ ! $? -eq 0 ] && echo "Error: emoving stack ${STACK_ID} from prelive elb for ${ENVIRONMENT}: $rc." && exit 1

