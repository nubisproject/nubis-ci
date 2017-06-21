#!/bin/bash

# Bootstrap the update service, oterwise, it's on a schedule, so make sure we are
# updated from boot time
wget -O /tmp/default.js http://updates.jenkins-ci.org/update-center.json
sed '1d;$d' /tmp/default.js > /tmp/default.json
curl -X POST -H "Accept: application/json" -d @/tmp/default.json http://localhost:8080/updateCenter/byId/default/postBack

AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')

# shell parse our userdata
eval "$(curl -fq http://169.254.169.254/latest/user-data)"

## BACKUPS
## Important to do first, so that what we generate can overwrite what we are restoring from
## Otherwise no way to change generated files as part of upgrades

# Prepare our backup dump directory
BACKUP_DIR=/mnt/jenkins

mkdir $BACKUP_DIR
chown jenkins:jenkins $BACKUP_DIR

# Pull latest backups
su - jenkins -c "s3cmd --quiet sync --exclude=.initial-sync s3://$(nubis-metadata NUBIS_CI_BUCKET)/ $BACKUP_DIR/"
su - jenkins -c "touch $BACKUP_DIR/.initial-sync"

# Build our latest backup chain with incrementals

# List all backups in proper order
ALL_BACKUPS=$(find $BACKUP_DIR -maxdepth 1 -type d   -name 'FULL*' -o -name 'DIFF*' | sort -t- -k2)

# Find the last full backup
LAST_FULL=$(basename "$(echo "$ALL_BACKUPS" | grep FULL | tail -n1)")

# And all following incrementals
INCREMENTALS=$(echo "$ALL_BACKUPS" | sed -e "0,/$LAST_FULL/d" | xargs -n1 basename)

# Recover from latest backup (full + incrementals)
for BACKUP in $LAST_FULL $INCREMENTALS; do
  echo "Restoring from $BACKUP_DIR/$BACKUP/"
  su - jenkins -c "rsync -av $BACKUP_DIR/$BACKUP/ /var/lib/jenkins/"
done

## BACKUP END

# Create the job directories
mkdir -p "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build"
mkdir -p "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment"

# Security (http://jenkins-ci.org/security-144)
mkdir -p /var/lib/jenkins/secrets
echo false > /var/lib/jenkins/secrets/slave-to-master-security-kill-switch
chown root:root /var/lib/jenkins/secrets/slave-to-master-security-kill-switch
chmod 644 /var/lib/jenkins/secrets/slave-to-master-security-kill-switch

# Drop main configurations
cp /etc/nubis.d/jenkins-config.xml /var/lib/jenkins/config.xml
cp /etc/nubis.d/jenkins-proxy.xml /var/lib/jenkins/proxy.xml
cp /etc/nubis.d/jenkins-location.xml /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml
cp /etc/nubis.d/jenkins-s3bucketpublisher.xml /var/lib/jenkins/hudson.plugins.s3.S3BucketPublisher.xml
cp /etc/nubis.d/jenkins-thinBackup.xml /var/lib/jenkins/thinBackup.xml
cp /etc/nubis.d/jenkins-ssh.xml /var/lib/jenkins/org.jenkinsci.main.modules.sshd.SSHD.xml

# Drop project configuration for jenkins
cp /etc/nubis.d/jenkins-build-config.xml "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

# Drop promotion configuration
mkdir -p "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed"
cp /etc/nubis.d/jenkins-build-promotion-deployed-config.xml "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed/config.xml"
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/promotions/Deployed/config.xml"

# Fix Location Config
perl -pi -e "s[%%NUBIS_PROJECT_URL%%][$NUBIS_PROJECT_URL]g" /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml

# Default Git Branches
if [ "$NUBIS_GIT_BRANCHES" == "" ]; then
  NUBIS_GIT_BRANCHES="**"
fi

## General Config
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"
perl -pi -e "s[%%NUBIS_GIT_BRANCHES%%][$NUBIS_GIT_BRANCHES]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

## Configure S3 plugin
perl -pi -e "s[%%NUBIS_CI_BUCKET%%][$NUBIS_CI_BUCKET]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"
perl -pi -e "s[%%NUBIS_CI_BUCKET_REGION%%][$NUBIS_CI_BUCKET_REGION]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

# Drop deployment configuration for jenkins
cp /etc/nubis.d/jenkins-deployment-config.xml "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"
perl -pi -e "s[%%NUBIS_GIT_BRANCHES%%][$NUBIS_GIT_BRANCHES]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# Discover available regions
  # All regions according to AWS (US only), with our own first

  # XXX: packer doesn't support us-east-2 yet
  REGIONS=($AWS_REGION $(aws --region "$AWS_REGION" ec2 describe-regions | jq -r '.Regions[] | .RegionName' | grep -E "^us-" | grep -v "$AWS_REGION" | grep -v us-east-2 | sort))

  # build a XML chunk
  for region in ${REGIONS[*]}; do
    REGIONS_STRING="$REGIONS_STRING<string>$region</string>"
  done
perl -pi -e"s[%%REGIONS%%][$REGIONS_STRING]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# Owner e-mail
sed -i -e"s/%%NUBIS_CI_EMAIL%%/$NUBIS_CI_EMAIL/g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# Fix permissions for sudo and user groups
SUDO_PERMISSIONS=""
IFS=,; for sudo in $NUBIS_SUDO_GROUPS; do
  SUDO_PERMISSIONS="$SUDO_PERMISSIONS
  <permission>hudson.model.Hudson.Administer:$sudo</permission>"
done

USER_PERMISSIONS=""
IFS=,; for user in $NUBIS_USER_GROUPS; do
USER_PERMISSIONS="$USER_PERMISSIONS
    <permission>hudson.model.Hudson.Read:$user</permission>
    <permission>hudson.model.Item.Build:$user</permission>
    <permission>hudson.model.Item.Cancel:$user</permission>
    <permission>hudson.model.Item.Discover:$user</permission>
    <permission>hudson.model.Item.Read:$user</permission>
    <permission>hudson.model.Item.ViewStatus:$user</permission>
    <permission>hudson.model.Item.Workspace:$user</permission>
    <permission>hudson.model.View.Read:$user</permission>"
done

perl -pi -e "s[%%NUBIS_SUDO_PERMISSIONS%%][$SUDO_PERMISSIONS]g" /var/lib/jenkins/config.xml
perl -pi -e "s[%%NUBIS_USER_PERMISSIONS%%][$USER_PERMISSIONS]g" /var/lib/jenkins/config.xml

# Slack
NUBIS_CI_SLACK_TOKEN=$(nubis-secret get ci/slack_token)
SLACK_NOTIFIER=""
if [ "$NUBIS_CI_SLACK_TOKEN" != "" ]; then
  echo "Enabling Slack in $NUBIS_CI_SLACK_DOMAIN/$NUBIS_CI_SLACK_CHANNEL"
  cp /etc/nubis.d/jenkins-slack.xml /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_TOKEN%%][$NUBIS_CI_SLACK_TOKEN]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_CHANNEL%%][$NUBIS_CI_SLACK_CHANNEL]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_DOMAIN%%][$NUBIS_CI_SLACK_DOMAIN]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml

 read -r -d '' SLACK_NOTIFIER <<EOF
    <jenkins.plugins.slack.SlackNotifier plugin="slack@2.0.1">
      <teamDomain></teamDomain>
      <authToken></authToken>
      <room></room>
      <startNotification>true</startNotification>
      <notifySuccess>true</notifySuccess>
      <notifyAborted>true</notifyAborted>
      <notifyNotBuilt>true</notifyNotBuilt>
      <notifyUnstable>true</notifyUnstable>
      <notifyFailure>true</notifyFailure>
      <notifyBackToNormal>true</notifyBackToNormal>
      <notifyRepeatedFailure>false</notifyRepeatedFailure>
      <includeTestSummary>false</includeTestSummary>
      <commitInfoChoice>NONE</commitInfoChoice>
      <includeCustomMessage>true</includeCustomMessage>
      <customMessage>environment:\\\$environment</customMessage>
    </jenkins.plugins.slack.SlackNotifier>
EOF
fi

# Set or erase the Slack Notifier section of the job configs
perl -pi -e "s[%%SLACK_NOTIFIER%%][$SLACK_NOTIFIER]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

# Make sure jenkins owns this stuff
chown -R jenkins:jenkins /var/lib/jenkins

cat <<EOF | tee /opt/nubis-builder/secrets/variables.json
{
  "variables": {
    "aws_region": "$AWS_REGION",
    "ami_regions": "$(IFS=, ; echo "${REGIONS[*]}")"
  }
}
EOF

# Retrieve and install the SSL certs for Consul in stage/prod in our trusted SSL store
for e in stage prod; do
  unicreds --region "$AWS_REGION" get "nubis/$e/ssl/public-cacert" -E "environment:$e" -E "region:$AWS_REGION" -E service:nubis > /usr/local/share/ca-certificates/consul-public-$e.crt
done
update-ca-certificates

# Manually fix our confd stuff (missing confd puppet support)
find /etc/confd/conf.d -type f -name '*.toml' -print0 | xargs -0 --verbose sed -i -e "s/%%NUBIS_CI_NAME%%/$NUBIS_CI_NAME/g"
service confd reload

# Finally, start jenkins for good
service jenkins start
