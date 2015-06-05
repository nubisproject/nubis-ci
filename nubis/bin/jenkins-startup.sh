#!/bin/sh

# Bootstrap the update service, oterwise, it's on a schedule, so make sure we are
# updated from boot time
wget -O /tmp/default.js http://updates.jenkins-ci.org/update-center.json
sed '1d;$d' /tmp/default.js > /tmp/default.json
curl -X POST -H "Accept: application/json" -d @/tmp/default.json http://localhost:8080/updateCenter/byId/default/postBack

AWS_ACCOUNT_ID=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId'`
AWS_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region'`

#XXX: Needs to be configurable/discovered
NUBIS_AMI_BUCKET="nubis-amis"

# Stop jenkins for reconfiguration
service jenkins stop

# shell parse our userdata
eval `curl -fq http://169.254.169.254/latest/user-data`

# Create the job directories
mkdir -p /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build
mkdir -p /var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment

# Drop main configurations
cp /etc/nubis.d/jenkins-config.xml /var/lib/jenkins/config.xml
cp /etc/nubis.d/jenkins-location.xml /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml
cp /etc/nubis.d/jenkins-s3bucketpublisher.xml /var/lib/jenkins/hudson.plugins.s3.S3BucketPublisher.xml

# Drop project configuration for jenkins
cp /etc/nubis.d/jenkins-build-config.xml /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml

# Drop promotion configuration
mkdir -p /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed
cp /etc/nubis.d/jenkins-build-promotion-deployed-config.xml /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed/config.xml
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed/config.xml

# Fix Location Config
perl -pi -e "s[%%NUBIS_PROJECT_URL%%][$NUBIS_PROJECT_URL]g" /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml

## General Config
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml

## Configure S3 plugin
perl -pi -e "s[%%NUBIS_CI_BUCKET%%][$NUBIS_CI_BUCKET]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml 
perl -pi -e "s[%%NUBIS_CI_BUCKET_REGION%%][$NUBIS_CI_BUCKET_REGION]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml 

# Drop deployment configuration for jenkins
cp /etc/nubis.d/jenkins-deployment-config.xml /var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml

# Make sure jenkins owns this stuff
chown -R jenkins:jenkins /var/lib/jenkins

if [ -f /etc/default/jenkins ]; then
  if [ "$NUBIS_CI_PASSWORD" ]; then
    JENKINS_ARGS="--argumentsRealm.passwd.admin=$NUBIS_CI_PASSWORD  --argumentsRealm.roles.admin=admin"
    perl -pi -e"s[^JENKINS_ARGS=\"(.*)\"][JENKINS_ARGS=\"\$1 $JENKINS_ARGS\"]g" /etc/default/jenkins
  fi
fi

cat <<EOF | tee /opt/nubis-builder/secrets/variables.json
{
  "variables": {
    "aws_account_id": "$AWS_ACCOUNT_ID",
    "aws_region": "$AWS_REGION",
    "aws_instance_s3_bucket": "$NUBIS_AMI_BUCKET",
    "aws_x509_cert_path": "/full/path/to/secrets/aws.crt.pem",
    "aws_x509_key_path": "/full/path/to/secrets/aws.key.pem",
    "iam_instance_profile": "",
    "iam_instance_role": ""
  }
}
EOF

# Manually fix our confd stuff (missing confd puppet support)
find /etc/confd/conf.d -type f -name '*.toml' | xargs --verbose sed -i -e "s/%%NUBIS_CI_NAME%%/$NUBIS_CI_NAME/g"
service confd reload

# Finally, start jenkins for good
service jenkins start
