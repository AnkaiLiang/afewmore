#!/bin/sh

catalog="/data"
num=10
verbose="false"

log()
{
	if [ "$verbose" = "true" ];
	then
		echo $@ 
	fi
}

iferr()
{
	if [ $? != 0 ];
	then 
		echo $@ >&2
		exit 1;
	fi
}
usage() 
{
	echo "Usage: \n          afewmore [-hv] [-d dir] [-n num] instance"
}
getInfo()
{
	((cat temp.txt | grep "\"$1\"") || (echo "Fail to get the $1 info." >&2; exit 1;))\
	 | tr ":\"," " "  | awk '{print $2}' | uniq | grep -v "^$"
#	delete the null line

}
getAllInfo()
{
	InstanceId=$1
	aws ec2 describe-instances --filters "Name=instance-id,Values=${InstanceId}" > temp.txt
	PublicDnsName=$(getInfo PublicDnsName)
	ImageId=$(getInfo ImageId)
	InstanceType=$(getInfo InstanceType)
	KeyName=$(getInfo KeyName)
	GroupName=$(getInfo GroupName)
	PublicDnsName=$(getInfo PublicDnsName)
	iferr "Fail to get the info for ${InstanceId}. Please check instance-id and its state."
}

while getopts ":d:n:hv" arg; 
do
	case ${arg} in
		h)
			cat ./afewmore.1.txt
			exit 0
			;;
		d)
			catalog=${OPTARG}
			if [[ $catalog == -* ]];
			then
				echo "-d's argument is not a valid path" >&2
				usage
				exit 1;
			fi
			;;
		n)	
			if [[ $OPTARG =~ ^[0-9]*$ ]]
			then
				num=${OPTARG}
			else
				echo "-n's argument is not a number." >&2
				usage
				exit 1;
			fi
			;;
		v)
			verbose="true"
			;;
		\?)
			echo "Unkonw argument: -$OPTARG" >&2
			usage
			exit 1
			;;
		:)
      		echo "Option -$OPTARG requires an argument." >&2
      		usage
     		exit 1
     		;;
	esac
done

shift $((OPTIND-1)) # shift the instance id arguments to $1
if [ -z $1 ];
then
	echo "Requires an instance id to point out which instance will be replicated." >&2
	usage
	exit 1
fi

log "Arguments format is correct." 
log "Tring to acquire target instance's info..."

# get the info for origin instance

targetId=$1
getAllInfo $targetId
targetPublicDns=${PublicDnsName}


log "done."
log "Target instance info: InstanceId=${InstanceId}, PublicDnsName=${PublicDnsName}, InstanceType=${InstanceType},\
 ImageId=${ImageId}, KeyName=${KeyName}, GroupName=${GroupName}"
log "Tring to ssh to target instance..." 

## get the username according to image-id

aws ec2 describe-images --filters "Name=image-id, Values=${ImageId}" > temp.txt
ImageName=$(getInfo Name)
username=$(cat UsernameTable | awk -F ":" -v pat="${ImageName}" 'pat ~ $1 { print $2 }' | head -1)
if [ -z ${username} ]
then
	username="root"
fi

## check can we log into target instance and the directory is exist

if ssh -o StrictHostKeyChecking=no ${username}@${targetPublicDns} :;
then 
	log "successful ssh to the target instance"
	log "username=${username}, ImageName=${ImageName}"
else 
	echo "Fail to ssh to the target instance" >&2
	exit 1
fi

if ssh -o StrictHostKeyChecking=no ${username}@${targetPublicDns} test -e ${catalog};
then
	log "${catalog} exists"
else 
	echo "${catalog} does not exists, please check the directory path" >&2
	exit 1
fi

## catch the public key for target Instance

log "Trying to get the rsa public key for target instance ${targetId}"
rsa=$(ssh -o StrictHostKeyChecking=no ${username}@${targetPublicDns} "(test -e ~/.ssh/id_rsa || ssh-keygen -f ~/.ssh/id_rsa -q -P '');\
 cat ~/.ssh/id_rsa.pub";)
iferr "Fail to get rsa public key"
log "rsa=${rsa}"
log "done"


# create ${num} new instance. 

log "Trying to create ${num} new instances..."

aws ec2 run-instances --image-id ${ImageId} --count ${num} --instance-type\
 ${InstanceType} --key-name ${KeyName} --security-groups ${GroupName} > temp.txt
iferr "Fail to create new instances, plase check awscli configuration and network"

log "done."
log "Instances pending..."
getInfo InstanceId > listInstanceId.txt
sleep 40s

## Deal with each new Instance
for line in $(cat listInstanceId.txt)
do
	aws ec2 describe-instances --filters "Name=instance-id,Values=${line}" > temp.txt
	state=$(getInfo Name)
	while [ "${state}" != "running" ];
	do
		sleep 5s
		aws ec2 describe-instances --filters "Name=instance-id,Values=${line}" > temp.txt
		state=$(getInfo Name) # loop until state = running
	done
	
	newPublicDnsName=$(getInfo PublicDnsName)
	iferr "Fail to get newPublicDnsName for instance ${line}"
	log "newPublicDnsName=${newPublicDnsName}"

	log "Testing ssh to new instance ${line}..."

	ssh -o StrictHostKeyChecking=no -o LogLevel=quiet ${username}@${newPublicDnsName} :
	while [ $? != 0 ];
	do
		sleep 5s
		ssh -o StrictHostKeyChecking=no -o LogLevel=quiet ${username}@${newPublicDnsName} :
	done
	log "done"

	log "Copying rsa public key into instance ${line}..."
	ssh -o StrictHostKeyChecking=no -o LogLevel=quiet ${username}@${newPublicDnsName} "echo ${rsa} >> ~/.ssh/authorized_keys"
	iferr "Fail to copy rsa public key into instance ${line}"
	log "done"

	log "Prepare the directory on new instance ${line}"
	newcatalog="${catalog%/?*}"
	ssh -o StrictHostKeyChecking=no -o LogLevel=quiet ${username}@${newPublicDnsName} "test -e ${newcatalog:="/"} || mkdir -p ${newcatalog}"
	iferr "Fail to create directory path on instance ${line}"
	log "Ready. newcatalog=$newcatalog"


	log "Running scp from ${username}@${targetPublicDns}:${catalog} to ${username}@${newPublicDnsName}:${newcatalog}..."
	ssh -o StrictHostKeyChecking=no ${username}@${targetPublicDns}\
	 "scp -r -q -p -o StrictHostKeyChecking=no ${catalog} ${username}@${newPublicDnsName}:${newcatalog}"
	iferr "Fail to copy directory content form ${targetId} to ${line}"
	log "done."
done


cat listInstanceId.txt
log "Success."

rm temp.txt
exit 0




