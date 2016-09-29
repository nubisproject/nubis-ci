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
su - jenkins -c "s3cmd --quiet sync s3://$(nubis-metadata NUBIS_CI_BUCKET)/ $BACKUP_DIR/"

# Build our latest backup chain with incrementals
LAST_FULL=$(basename $(ls -1d $BACKUP_DIR/{FULL,DIFF}* | sort -t- -k2 | grep FULL | tail -n1))
INCREMENTALS=$(ls -1d $BACKUP_DIR/{FULL,DIFF}* | sort -t- -k2  | sed -e "1,/$LAST_FULL/d" | xargs -n1 basename)

# Recover from latest backup
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

## General Config
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

## Configure S3 plugin
perl -pi -e "s[%%NUBIS_CI_BUCKET%%][$NUBIS_CI_BUCKET]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"
perl -pi -e "s[%%NUBIS_CI_BUCKET_REGION%%][$NUBIS_CI_BUCKET_REGION]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml"

# Drop deployment configuration for jenkins
cp /etc/nubis.d/jenkins-deployment-config.xml "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# Discover available regions
  # All regions according to AWS (US only), with our own first
  REGIONS=($AWS_REGION $(aws --region "$AWS_REGION" ec2 describe-regions | jq -r '.Regions[] | .RegionName' | grep -E "^us-" | grep -v "$AWS_REGION" | sort))
  # build a XML chunk
  for region in ${REGIONS[*]}; do
    REGIONS_STRING="$REGIONS_STRING<string>$region</string>"
  done
perl -pi -e"s[%%REGIONS%%][$REGIONS_STRING]g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# Owner e-mail
sed -i -e"s/%%NUBIS_CI_EMAIL%%/$NUBIS_CI_EMAIL/g" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-build/config.xml" "/var/lib/jenkins/jobs/$NUBIS_CI_NAME-deployment/config.xml"

# GitHub Authentication

perl -pi -e"\$admins=join qq(\n), map { qq(<string>\$_</string>) } split(q(,), q($NUBIS_CI_GITHUB_ADMINS)); s[%%NUBIS_CI_GITHUB_ADMINS%%][\$admins]g" /var/lib/jenkins/config.xml
perl -pi -e"\$orgs=join qq(\n), map { qq(<string>\$_</string>) } split(q(,), q($NUBIS_CI_GITHUB_ORGANIZATIONS)); s[%%NUBIS_CI_GITHUB_ORGANIZATIONS%%][\$orgs]g" /var/lib/jenkins/config.xml


# Retrieve secrets with nubis-secret if not in user-data
if [ "$NUBIS_CI_GITHUB_CLIENT_TOKEN" == "" ]; then
  NUBIS_CI_GITHUB_CLIENT_TOKEN=$(nubis-secret get ci/github_oauth_client_id)
fi

if [ "$NUBIS_CI_GITHUB_CLIENT_SECRET" == "" ]; then
  NUBIS_CI_GITHUB_CLIENT_SECRET=$(nubis-secret get ci/github_oauth_client_secret)
fi

perl -pi -e "s[%%NUBIS_CI_GITHUB_CLIENT_TOKEN%%][$NUBIS_CI_GITHUB_CLIENT_TOKEN]g" /var/lib/jenkins/config.xml
perl -pi -e "s[%%NUBIS_CI_GITHUB_CLIENT_SECRET%%][$NUBIS_CI_GITHUB_CLIENT_SECRET]g" /var/lib/jenkins/config.xml

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

# Manually fix our confd stuff (missing confd puppet support)
find /etc/confd/conf.d -type f -name '*.toml' -print0 | xargs -0 --verbose sed -i -e "s/%%NUBIS_CI_NAME%%/$NUBIS_CI_NAME/g"
service confd reload

# Finally, start jenkins for good
service jenkins start
