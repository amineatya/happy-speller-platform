import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
import jenkins.model.Jenkins

def store  = Jenkins.instance.getExtensionList(
  com.cloudbees.plugins.credentials.SystemCredentialsProvider
)[0].getStore()
def domain = Domain.global()

def upsert = { String id, Credentials cred ->
  def existing = CredentialsProvider.lookupCredentials(
      Credentials.class, Jenkins.instance, null, (List)null
  ).find { it.id == id }
  if (existing) {
    store.updateCredentials(domain, existing, cred)
    println "Updated credentials: ${id}"
  } else {
    store.addCredentials(domain, cred)
    println "Created credentials: ${id}"
  }
}

// Your provided credentials
def giteaToken = '9b407fc263328ce9f89b41721d80b48a306ece8d'
def minioUser  = 'minioadmin'
def minioPass  = 'FiXKggTsc4gnR'

// Create Gitea token credential
def gitea = new StringCredentialsImpl(
  CredentialsScope.GLOBAL, 'gitea-token', 'Gitea API token',
  Secret.fromString(giteaToken)
)
upsert('gitea-token', gitea)

// Create MinIO credentials
def minio = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL, 'minio-creds', 'MinIO access credentials',
  minioUser, minioPass
)
upsert('minio-creds', minio)

println '✅ Gitea and MinIO credentials created successfully!'
println 'ℹ️  Note: You still need to manually add the kubeconfig file credential through the Jenkins UI.'
println 'ℹ️  Go to: Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials'
println 'ℹ️  Choose "Secret file" and upload your kubeconfig file with ID: kubeconfig'