#!/bin/bash
yum update -y
yum install curl -y 
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
yum install amazon-cloudwatch-agent -y

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
REGION=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region`

export listclustersfile="/tmp/listclusters.json"
export listnodegroupsfile="tmp/listnodegroups.json"
export logfile="/tmp/eksNodeUpdater.log"
export cloudwatchconfig="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
touch $cloudwatchconfig

cat > $cloudwatchconfig <<EOF 
{
        "agent": {
                "run_as_user": "root"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "${logfile}",
                                                "log_group_name": "eksNodeUpdater.log",
                                                "log_stream_name": "eksNodeUpdater.log",
                                                "retention_in_days": 60
                                        }
                                ]
                        }
                }
        }
}
EOF

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:$cloudwatchconfig -s

echo "Begin upgrade process" >> $logfile


aws eks list-clusters >$listclustersfile
clusters=($(jq -r '.clusters' $listclustersfile  | tr -d '[]," ')) 

for i in ${clusters[@]}; do aws eks list-nodegroups --cluster-name $i >$listnodegroupsfile; nodegroups=($(jq -r '.nodegroups' $listnodegroupsfile  | tr -d '[]," '));  for j in ${nodegroups[@]}; do /tmp/eksctl upgrade nodegroup --name=$j --cluster=$i --region=$REGION >>$logfile; done; done

echo "Finished upgrade process" >>$logfile
sleep 20
shutdown now