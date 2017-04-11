#!/bin/bash
getInfo()
{
  grep "\"$1\"" < temp.txt >tempGrepRes.txt
  if [ $? != 0 ]
  then
    echo "Fail to get the $1 info for ${InstanceId}. Please check instance-id and its state" >&2
    exit 1;
  fi
# res=`awk '{print $2}' <<< ${temp} | uniq`
  tr "\:\"," " " < tempGrepRes.txt | awk '{print $2}' | uniq
}

auto_smart_ssh () {
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect { 
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                " 
    return $?
}

#Description=$(aws ec2 describe-images --filters "Name=image-id, Values=$1"\
# | grep "\"Description\"" | awk -F ":" '{print $2}' | tr -d "\"")
aws ec2 describe-images --filters "Name=image-id, Values=$1" > temp.txt
ImageName=$(getInfo Name)
username=$(cat UsernameTable | awk -F ":" -v pat="$ImageName" 'pat ~ $1 { print $2 }')

cat temp.txt
if [ -z $username ]
then
  username="root"
fi
echo $username $ImageName
PublicDnsName="ec2-34-204-74-70.compute-1.amazonaws.com"

auto_smart_ssh 123 $username@$PublicDnsName :
echo -e "\n---Exit Status: $?"

