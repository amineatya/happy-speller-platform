import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
import jenkins.model.Jenkins

println "Setting up Jenkins credentials..."

def store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def domain = Domain.global()

// Helper function to add or update credentials
def addOrUpdateCredential = { String id, Credentials cred ->
  def existing = null
  try {
    existing = CredentialsProvider.lookupCredentials(Credentials.class, Jenkins.instance, null, null).find { it.id == id }
  } catch (Exception e) {
    println "Checking existing credentials failed: ${e.message}"
  }
  
  try {
    if (existing) {
      store.updateCredentials(domain, existing, cred)
      println "✅ Updated credential: ${id}"
    } else {
      store.addCredentials(domain, cred)
      println "✅ Created credential: ${id}"
    }
  } catch (Exception e) {
    println "❌ Failed to create/update credential ${id}: ${e.message}"
  }
}

// Create Gitea API Token credential
try {
  def giteaToken = new StringCredentialsImpl(
    CredentialsScope.GLOBAL, 
    'gitea-token', 
    'Gitea API token for repository access',
    Secret.fromString('9b407fc263328ce9f89b41721d80b48a306ece8d')
  )
  addOrUpdateCredential('gitea-token', giteaToken)
} catch (Exception e) {
  println "❌ Failed to create Gitea credential: ${e.message}"
}

// Create MinIO credentials
try {
  def minioCredential = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    'minio-creds',
    'MinIO object storage credentials',
    'minioadmin',
    'FiXKggTsc4gnR'
  )
  addOrUpdateCredential('minio-creds', minioCredential)
} catch (Exception e) {
  println "❌ Failed to create MinIO credential: ${e.message}"
}

println ""
println "🎉 Credential setup complete!"
println ""
println "📋 Next steps:"
println "1. For kubeconfig: Go to Jenkins → Manage Credentials → Global → Add Credentials"
println "2. Choose 'Secret file' and upload your kubeconfig with ID: 'kubeconfig'"
println "3. Run your pipeline - it should now find the gitea-token and minio-creds!"
println ""
println "✅ Ready to test your Jenkins pipeline!"