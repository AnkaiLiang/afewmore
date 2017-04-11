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
	if [ $? = 1 ] 
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
	grep "\"$1\"" < temp.txt >tempGrepRes.txt
	if [ $? != 0 ]
	then
		echo "Fail to get the $1 info." >&2
		exit 1;
	fi
#	res=`awk '{print $2}' <<< ${temp} | uniq`
	tr -d "\:\","  < tempGrepRes.txt | awk '{print $2}' | uniq
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
	iferr "Fail to get the info for ${InstanceId}. Please check instance-id and its state." >&2
}

while getopts ":d:n:hv" arg; do
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
if [ -z $1 ]
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

#Description=$(aws ec2 describe-images --filters "Name=image-id, Values=${ImageId}"\
# | grep "\"Description\"" | awk -F ":" '{print $2}' | tr -d "\"")
aws ec2 describe-images --filters "Name=image-id, Values=${ImageId}" > temp.txt
ImageName=$(getInfo Name)
username=$(cat UsernameTable | awk -F ":" -v pat="$ImageName" 'pat ~ $1 { print $2 }')
if [ -z $username ]
then
	username="root"
fi

username=123;

if ssh $username@$PublicDnsName :;
then echo successful
	 log "username=$username, ImageName=$ImageName"
else echo Fail
fi

rm temp.txt
rm tempGrepRes.txt
exit 0




