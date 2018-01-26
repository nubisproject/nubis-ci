// Groovy Script to retrieve New Relic API keys from unicreds
// and store it as a Jenkins Secret Credential for use in
// deployment jobs

import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret;

domain = Domain.global()
store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

def newrelic_api_key_name = "NEWRELIC_API_KEY"

// Lookup old credentials for possibly updating them
def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
  org.jenkinsci.plugins.plaincredentials.StringCredentials.class,
  Jenkins.instance
)

// old gets set to the current credentials for newrelic, if they exists
def old = creds.findResult { it.id == newrelic_api_key_name ? it : null }

def newrelic_api_key

// prepare to invoke nubis-secret
def nubis_secret_cmd = "nubis-secret get ci/newrelic_api_key";
def outputStream = new StringBuffer();

// do the deed and guard against failure
try {
  def proc = nubis_secret_cmd.execute();
  proc.waitForProcessOutput(outputStream, System.err);
  newrelic_api_key = outputStream.toString().trim();
} catch (all) { 
  println "Failed executing ${nubis_secret_cmd} : ${all}"
}

// default to some value, to be certain
if (!newrelic_api_key) {
  newrelic_api_key = "<unset>"
}

// Prepare the encrypted credentials
plain = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  newrelic_api_key_name,
  "Newrelic API Key",
  hudson.util.Secret.fromString(newrelic_api_key)
)

// If an existing one, update it
if ( old ) {
  println "Updating NewRelic API Key ${old.id}"
  store.updateCredentials(domain, old, plain)
}
// otherwise, create it new
else {
  println "Storing NewRelic API Key ${newrelic_api_key_name}"
  store.addCredentials(domain, plain)
}


