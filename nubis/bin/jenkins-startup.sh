#!/bin/bash

# Bootstrap the update service, oterwise, it's on a schedule, so make sure we are
# updated from boot time
wget -O /tmp/default.js http://updates.jenkins-ci.org/update-center.json
sed '1d;$d' /tmp/default.js > /tmp/default.json
curl -X POST -H "Accept: application/json" -d @/tmp/default.json http://localhost:8080/updateCenter/byId/default/postBack

AWS_REGION=$(nubis-region)

# shell parse our userdata
eval "$(nubis-metadata)"

## BACKUPS
## Important to do first, so that what we generate can overwrite what we are restoring from
## Otherwise no way to change generated files as part of upgrades

# Prepare our backup dump directory
BACKUP_DIR=/mnt/jenkins

mkdir $BACKUP_DIR
chown jenkins:jenkins $BACKUP_DIR

# Pull latest backups
/usr/local/bin/nubis-ci-backup restore

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
cp /etc/nubis.d/jenkins-dsl-configuration.xml /var/lib/jenkins/javaposse.jobdsl.plugin.GlobalJobDslSecurityConfiguration.xml

# Fix Location Config
perl -pi -e "s[%%NUBIS_PROJECT_URL%%][$NUBIS_PROJECT_URL]g" /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml

# Default Git Branches
if [ "$NUBIS_GIT_BRANCHES" == "" ]; then
  NUBIS_GIT_BRANCHES="**"
fi

# Seed configuration
cp -a /etc/nubis.d/jenkins-seed-config.xml /var/lib/jenkins/jobs/00-seed/config.xml
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" "/var/lib/jenkins/jobs/00-seed/config.xml"

# Discover available regions
# All regions according to AWS (US only), with our own first

# Start with our region
REGIONS=("$AWS_REGION")

# Add all other regions at the end of the arrau
mapfile -O1 -t REGIONS <<< "$(aws --region "$AWS_REGION" ec2 describe-regions | jq -r '.Regions[] | .RegionName' | grep -E "^us-" | grep -v "$AWS_REGION" | grep -v us-east-2 | sort)"

# build a XML chunk
for region in ${REGIONS[*]}; do
  REGIONS_STRING="$REGIONS_STRING<string>$region</string>"
done

# Fix permissions for sudo, oper and user groups
SUDO_PERMISSIONS=""
IFS=,; for sudo in $NUBIS_SUDO_GROUPS; do
  SUDO_PERMISSIONS="$SUDO_PERMISSIONS
  <permission>hudson.model.Hudson.Administer:$sudo</permission>"
done

OPER_PERMISSIONS=""
IFS=,; for oper in $NUBIS_OPER_GROUPS; do
  OPER_PERMISSIONS="$OPER_PERMISSIONS
    <permission>hudson.model.Hudson.Read:$oper</permission>
    <permission>hudson.model.Item.Build:$oper</permission>
    <permission>hudson.model.Item.Cancel:$oper</permission>
    <permission>hudson.model.Item.Discover:$oper</permission>
    <permission>hudson.model.Item.Read:$oper</permission>
    <permission>hudson.model.Item.ViewStatus:$oper</permission>
    <permission>hudson.model.Item.Workspace:$oper</permission>
    <permission>hudson.model.Run.Delete:$oper</permission>
    <permission>hudson.model.Run.Replay:$oper</permission>
    <permission>hudson.model.Run.Update:$oper</permission>
    <permission>hudson.model.View.Read:$oper</permission>"
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
perl -pi -e "s[%%NUBIS_OPER_PERMISSIONS%%][$OPER_PERMISSIONS]g" /var/lib/jenkins/config.xml
perl -pi -e "s[%%NUBIS_USER_PERMISSIONS%%][$USER_PERMISSIONS]g" /var/lib/jenkins/config.xml

# Slack
NUBIS_CI_SLACK_TOKEN=$(nubis-secret get ci/slack_token)

if [ "$NUBIS_CI_SLACK_TOKEN" != "" ]; then
  echo "Enabling Slack in $NUBIS_CI_SLACK_DOMAIN/$NUBIS_CI_SLACK_CHANNEL"
  cp /etc/nubis.d/jenkins-slack.xml /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_TOKEN%%][$NUBIS_CI_SLACK_TOKEN]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_CHANNEL%%][$NUBIS_CI_SLACK_CHANNEL]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
  perl -pi -e "s[%%NUBIS_CI_SLACK_DOMAIN%%][$NUBIS_CI_SLACK_DOMAIN]g" /var/lib/jenkins/jenkins.plugins.slack.SlackNotifier.xml
fi

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
systemctl reload-or-restart confd

# Finally, start jenkins for good
service jenkins start
