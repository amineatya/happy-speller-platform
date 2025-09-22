import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
import hudson.util.SecretBytes
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

// Read from environment variables for security
def giteaToken = System.getenv('GITEA_TOKEN') ?: args[0]
def minioUser  = System.getenv('MINIO_USER') ?: args[1] 
def minioPass  = System.getenv('MINIO_PASS') ?: args[2]
def kubeB64    = System.getenv('KUBE_CONFIG_B64') ?: args[3]

def gitea = new StringCredentialsImpl(
  CredentialsScope.GLOBAL, 'gitea-token', 'Gitea API token',
  Secret.fromString(giteaToken)
)
upsert('gitea-token', gitea)

def minio = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL, 'minio-creds', 'MinIO access credentials',
  minioUser, minioPass
)
upsert('minio-creds', minio)

byte[] kubeBytes = kubeB64.decodeBase64()
def kube = new FileCredentialsImpl(
  CredentialsScope.GLOBAL, 'kubeconfig', 'Kubernetes config file',
  'config', SecretBytes.fromBytes(kubeBytes)
)
upsert('kubeconfig', kube)

println '✅ All done.'