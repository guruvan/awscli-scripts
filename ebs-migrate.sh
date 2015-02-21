#!/bin/bash -x
#
# Set etcd value at /disks/$VOL in unit
# Check etcd value when starting the unit
# If there's a value then we must check the attach state
# and ensure the other host is down or at least 
# has the volume umounted

source /tmp/instance-id.env
my_instance="${INSTANCE_ID}"
test -z "${VOL}" && echo "VOL not set - exiting" && die 3


die () {
 exit "${1}"
}



check_state () {
  state=$(aws ec2 describe-volumes --volume-id "${VOL}" |python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["State"]')
  echo "$(date) Found $VOL is currently: $state"
} 

check_attach () {
      a_state=$(aws ec2 describe-volumes --volume-id "${VOL}"|python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["Attachments"][0]["State"]')
      case ${a_state} in
         attached) echo "$(date) Volume attached"
                   check_use
                 ;;
        attaching) echo "$(date) Volume currently attaching..."
                   sleep 10
                   check_volume
                 ;;
         detached) echo "$(date) Volume is detached"
                   attach_vol
                 ;;
        detaching) echo "$(date) Volume is detaching..."
                   sleep 10
                   check_volume
                 ;;
             busy) echo "$(date) Volume is Busy..."
                   sleep 10
                   check_volume
                 ;;
                *) echo "$(date) Unknown ERR"
                   echo "Attachment State is ${a_state}"
                   exit 99
                 ;;
      esac
}

check_etcd () {
      e_instance=$(etcdctl ls --recursive /disks|grep "${VOL}")
      test -z "${e_instance}" echo "$(date) etcd says: ${VOL} last attached at /disks/${e_instance}"
      u_instance=$(etcdctl get /disks/"${VOL}"  |python -c 'import sys, json; print json.load(sys.stdin)["instance"]')
      echo "$(date) etcd says: ${VOL} last attached at /disks/${e_instance} to ${u_instance}"
}

check_use () {
      a_instance=$(aws ec2 describe-volumes --volume-id "${VOL}"|python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["Attachments"][0]["InstanceId"]')
      a_device=$(aws ec2 describe-volumes --volume-id "${VOL}" |python -c 'import sys, json; print json.load(sys.stdin)["Volumes"][0]["Attachments"][0]["Device"]')
  if [ "${a_instance}" = "$my_instance" ]
  then
    echo "$(date) DISK $VOL already attached to requesting instance $instance at ${a_device}"
    exit 0
    else
      # maybe here we ping, then if responding, ssh to other host and make sure $VOL isn't mounted
      echo "$(date) Attempting to detach: $VOL from ${a_instance} device ${a_device}"
      aws ec2 detach-volume --instance-id "${a_instance}" --volume-id "${VOL}"
      sleep 10
      check_volume
  fi 

}


attach_vol () {
 # for now, just bail and the next ExecStartPre line 
 # will take care of attaching the volume
 echo "$(date) Ready to attach"
 exit 0
}

#possible states:
# - creating | available | in-use | deleting | deleted | error

#possible attachment status
# - attaching | attached | detaching | detached | busy

check_volume () {

  check_state

  case ${state} in 
    available) echo "$(date) Volume is available"
               attach_vol
               ;;
       in-use) echo "$(date) Volume in-use"
               check_attach
	       ;;
            *) echo "$(date) Volume is not usable"
               exit 9
               ;;
  esac

}

x=0
while true 
do
  check_volume
  sleep 10
  x=$((x+1))
  if [ "$x" -ge 20 ]
  then
    if [ "${a_state}" = "busy" ] 
    then 
      x=0
      aws ec2 detach-volume --instance-id "${a_instance}" --volume-id "${VOL}" --force
      sleep 30
      check_volume
    fi
    echo "$(date) Unable to make $VOL available" 
    exit 3
  fi 
done
