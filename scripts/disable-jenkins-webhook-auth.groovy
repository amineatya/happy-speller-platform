// Groovy script to disable Jenkins Git webhook token requirement
// Run this in Jenkins Script Console: http://192.168.50.247:8080/script

// Disable access token requirement for Git notifyCommit webhook
System.setProperty("hudson.plugins.git.GitStatus.NOTIFY_COMMIT_ACCESS_CONTROL", "disabled-for-polling")

println "✅ Git webhook access control set to 'disabled-for-polling'"
println "🔧 This allows unauthenticated webhook requests for polling"
println "🔒 But still requires authentication for immediate builds"
println ""
println "📋 Webhook URLs you can now use:"
println "   http://192.168.50.247:8080/git/notifyCommit?url=http://192.168.50.130:3000/amine/happy-speller-platform.git"
println ""
println "🎯 Configure your Gitea webhook to:"
println "   URL: http://192.168.50.247:8080/git/notifyCommit?url=http://192.168.50.130:3000/amine/happy-speller-platform.git"
println "   Method: GET or POST"
println "   Secret: (leave empty)"