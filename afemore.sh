#!/bin/sh

catalog="/data"
num=10
verbose="false"

usage() 
{
	echo "Usage: \n          afewmore [-hv] [-d dir] [-n num] instance"
}
getInfo()
{
	grep "$1" < temp.txt >tempGrepRes.txt
	if [ $? != 0 ]
	then
		echo "Can not get the $1 info for ${InstanceId}. Please check instance-id and its state" >&2
		exit 1;
	fi
#	res=`awk '{print $2}' <<< ${temp} | uniq`
	awk '{print $2}' < tempGrepRes.txt | uniq&
}
getAllInfo()
{
	InstanceId=$1
	aws ec2 describe-instances --filters "Name=instance-id,Values=${InstanceId}" | tr "\:\"" " " > temp.txt
	PublicDnsName=`getInfo PublicDnsName`
	ImageId=`getInfo ImageId`
	InstanceType=`getInfo InstanceType`
	KeyName=`getInfo KeyName`
	GroupName=`getInfo GroupName`
	PublicDnsName=`getInfo PublicDnsName`
	InstanceId=`getInfo InstanceId`
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

if [ "$verbose" = "true" ];
then 
	echo "Arguments format is correct." >&1
	echo "Tring to acquire target instance's info..." >&1
fi

originId=$1
getAllInfo $originId

if [ "$verbose" = "true" ];
then 
echo "done." >&1
echo "Target instance info: InstanceId=${InstanceId},PublicDnsName=${PublicDnsName},InstanceType=${InstanceType},\
ImageId=${ImageId},KeyName=${KeyName},GroupName=${GroupName}" >&1
fi
#grep '$1' <<< $metadata
#echo $metadata

rm temp.txt
rm tempGrepRes.txt
exit 0




