# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Get env vars
$statsConnSecretName = $env:secretNameP2svpnstatsconn
$kvName = $env:kvName
$p2sgw = $env:p2sGwName
$resourcegroup = env:p2sgwResourceGroup
# read kv secrets
$secret = Get-AzKeyVaultSecret -VaultName $kvName -Name $statsConnSecretName -AsPlainText
# extract vpn info to storage 
Get-AzP2sVpnGatewayDetailedConnectionHealth -Name $p2sgw -resourcegroupname $resourcegroup -outputblobsasurl $secret

# Write an information log with the current time.
Write-Host "P2S VPN GW Info function ran! TIME: $currentUTCtime"
