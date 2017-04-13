#!/bin/bash

dir="/data"
spawnnum=10
instanceId="hahah"
needdetail=false


#this function is used in this format: getuserhelper (PublicDnsName)
getuserhelper() 
{
	mes=`ssh -o "StrictHostKeyChecking no" root@$1 uname` 
	wordnum=$(echo $mes | awk '{print NF}')
	if [ $wordnum -gt "1" ]
	then
		echo $mes | sed 's/[^"]*"\([^"]*\)".*/\1/'
	else 
		echo "root"
	fi
}

#this function is used in this format: spawnhelper
spawnhelper() 
{
	addtoknow_hosts	${instanceId} #make the source instance to be a knowen host
	MyImageId=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].ImageId' | sed -e 's/^"//' -e 's/"$//'` 
	SecurityGroupId=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' | sed -e 's/^"//' -e 's/"$//'`
	InstanceType=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].InstanceType' | sed -e 's/^"//' -e 's/"$//'`
	KeyName=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].KeyName' | sed -e 's/^"//' -e 's/"$//'`
	PublicDnsname=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].PublicDnsName' | sed -e 's/^"//' -e 's/"$//'` 
	nums=$spawnnum
	user="$(getuserhelper ${PublicDnsname})"
	echo "user is ${user}"
	while [ $nums -gt "0" ] 
	do
		#todo spawn instance
		spawnandcopyinstance ${MyImageId} ${SecurityGroupId} ${InstanceType} ${KeyName} ${PublicDnsname} ${user}
		((nums--))
	done
	echo "spawn $spawnnum instances successfully"

}

#function used in this format: spawninstance (ImageId, SecurityGroupId, InstanceType, Keyname, PublicDnsname, username)
spawnandcopyinstance()
{
	echo "now in the spawnandcopyinstance"
	sourcePublicDnsname=$5
	user=$6
	spawnInstanceId=`aws ec2 run-instances --image-id $1 --security-group-ids $2 --count 1 --instance-type $3 --key-name $4 --query 'Instances[0].InstanceId' | sed -e 's/^"//' -e 's/"$//'`
	echo "the instance id you spawn is ${spawnInstanceId}"
	addtoknow_hosts	${spawnInstanceId}
	spawnPublicDnsname=`aws ec2 describe-instances --instance-ids ${spawnInstanceId} --query 'Reservations[0].Instances[0].PublicDnsName' | sed -e 's/^"//' -e 's/"$//'`

	echo "now checking the status of instance "
	#todo chek the status of instance, if it is running then perform copy.
	while :
	do
		instancestatus=`aws ec2 describe-instance-status --instance-ids ${spawnInstanceId} --query 'InstanceStatuses[0].InstanceStatus.Status' | sed -e 's/^"//' -e 's/"$//'`
		if [ ${instancestatus} = "ok" ] 
		then
			break
		fi
	done

	#the status of state has already ok, perform copy now
	echo "sourcePublicDnsname is ${sourcePublicDnsname}"
	echo "spawnPublicDnsname is ${spawnPublicDnsname}"
	performcopy ${user} ${sourcePublicDnsname} ${spawnPublicDnsname}
}

performcopy() 
{
	user=$1
	sourcePublicDnsname=$2
	spawnPublicDnsname=$3
	#make a new directory
	echo "ssh ${user}@${spawnPublicDnsname} sudo mkdir -p ${dir}"
	`ssh ${user}@${spawnPublicDnsname} sudo mkdir -p ${dir}`
	#change the owner, use sudo to mkdir, owner is root, change it to ubuntu
	echo "ssh ${user}@${spawnPublicDnsname} sudo chown -R ${user} ${dir}"
	`ssh ${user}@${spawnPublicDnsname} sudo chown -R ${user} ${dir}`
	#give the priority
	echo "ssh ${user}@${spawnPublicDnsname} sudo chmod -R 700 ${dir}"
	`ssh ${user}@${spawnPublicDnsname} sudo chmod -R 700 ${dir}`
	#run scp command, the directory want to copy should be for exmaple /home/ubuntu/data/* to  /home/ubuntu/data/
	echo "scp -3 ${user}@${sourcePublicDnsname}:${dir}/* ${user}@${spawnPublicDnsname}:${dir}"
	`scp -3 ${user}@${sourcePublicDnsname}:${dir}/* ${user}@${spawnPublicDnsname}:${dir}`
}

#function used in this format: addtoknow_hosts(instanceid)
addtoknow_hosts() 
{

	myhostname=`aws ec2 describe-instances --instance-ids $1 --query 'Reservations[0].Instances[0].PublicDnsName' | sed -e 's/^"//' -e 's/"$//'`
	myipaddress=`aws ec2 describe-instances --instance-ids $1 --query 'Reservations[0].Instances[0].PublicIpAddress' | sed -e 's/^"//' -e 's/"$//'`
	`ssh-keygen -R [${myhostname}]`
	`ssh-keygen -R [${myipaddress}]`
	`ssh-keygen -R [${myhostname}],[${myipaddress}]`
	`ssh-keyscan -H [${myhostname}],[${myipaddress}] >> ~/.ssh/known_hosts`
	`ssh-keyscan -H [${myipaddress}] >> ~/.ssh/known_hosts`
	`ssh-keyscan -H [${myhostname}] >> ~/.ssh/known_hosts`
}

echo "afewmore command started!"
lastarg=$#
while [ "$#" -gt "0" ]
do
	if [ "$#" -eq "1" ]
	then
		 instanceId=$1
		 shift
		 break
	fi
	case "$1" in
	-d)
			shift
			dir="$1"
			shift
			;;
	-h)
			echo "-d dir  Copy the contents of this data directory from the orignal source instance to all the new instances.  If not specified, defaults to /data."
			echo "-h  Print a usage statement and exit."
			echo "-n num  Create this many new instances.  If not specified, defaults to 10."
			echo "-v Be verbose."
			shift
			;;
	-n)
			shift
			spawnnum="$1"
			shift
			;;

	-v)
			shift
			;;
	*)
			needdetail=true
			shift
			;;
	esac
done
spawnhelper



