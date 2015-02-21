#!/bin/bash -x
check_state () {
state=$(aws ec2 describe-volumes --volume-id ${VOL} |python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["State"]')
} 
x=0
source /tmp/instance-id.env
my_instance=${INSTANCE_ID}
while true 
do
  check_state
  if [ "${state}" != "available" ]
  then
    u_instance=$(etcdctl ls --recursive /disks|grep $VOL)
  elif [ "${state}" = "attached" ] 
    then
      a_instance=$(aws ec2 describe-volumes --volume-id vol-ca1bbec5|python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["Attachments"][0]["InstanceId"]')
  if [ "${u_instance}X" != "X" ] 
  then
      instance=$(etcdctl get /disks/$VOL  |python -c 'import sys, json; print json.load(sys.stdin)["instance"]')
      aws ec2 detach-volume --instance-id $instance --volume-id $VOL
  fi
  if [ "${a_instance}" = "$my_instance" ]
  then
    echo "$(date) DISK $VOL already attached to requesting instance $instance"
    exit 0
    else
      aws ec2 detach-volume --instance-id $a_instance --volume-id $VOL
  fi 
    x=$((x+1))
  if [ "$x" -ge 50 ]
  then
    echo "$(date) Unable to make $VOL available" 
    exit 3
  fi 
  else break
  sleep 10  
 fi
done


