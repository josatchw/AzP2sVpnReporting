# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Get env vars
# read kv secrets

# Get-AzP2sVpnGatewayDetailedConnectionHealth -Name $p2sgwaue -resourcegroupname $resourcegroup -outputblobsasurl $blobsasaue

# check log 

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"