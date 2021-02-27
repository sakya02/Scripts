<#
.SYNOPSIS
This script is used to query Microsoft Graph Rest API for all guest user, if they have been active in the last 30 days and 
check there group membership

.DESCRIPTION
This Script uses Graph API url's to query Guest users, sign-in activity logs and group membership, this script also requires that the 
MSAL.PS module is installed as this is used to generate the graph token use to access the diffrent graph urls.

https://www.powershellgallery.com/packages/MSAL.PS/4.21.0.1

The script is designed to work with certificates so this is a pre-req that Enterprise App for graph is setup, certificate is added and
installed on the local client. 

The script requires the follwoing details to be added 
TennantId (AzureAD) 
ClientID (from the Enterprise app)
ClientCert (Thumprint of the certficate that was uploaded to the Azure Enterprise app)

.EXAMPLE
GuestUserAuditGraph.ps1
#>

## Get token to connect to Graph
Import-Module MSAL.PS
$TenantId = "TenantID"
$ClientId = "AppID" 
$ClientCert = Get-ChildItem "Cert:\currentuser\my\CertTumbprint"
$MSToken = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -ClientCertificate $ClientCert

## Create result array and date variable
$results = @()
$Date = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')

## Query Guest users
$GuestsUrl = "https://graph.microsoft.com/beta/users/?filter=usertype eq 'Guest'"
$users = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($MSToken.AccessToken)"} -Uri $GuestsUrl -Method Get).value

## Loop through Guest users
ForEach ($user in $users){

## Checking guest user for sign-in logs
Write-Host "Checking Logons for Guest user $($User.mail)" -ForegroundColor Green
$LoginUrl = "https://graph.microsoft.com/beta/auditLogs/signIns/?filter=userPrincipalName eq '$($User.mail)' and createdDateTime ge $Date"
$Logins = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($MSToken.AccessToken)"} -Uri $LoginUrl -Method Get).value | 
Select-Object userPrincipalName,ipAddress,tokenIssuerType,resourceDisplayName,createdDateTime

## Checking guest user group membership 
$GuestsUrl = "https://graph.microsoft.com/beta/users/$($User.ID)/memberof"
$Groups = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($MSToken.AccessToken)"} -Uri $GuestsUrl -Method Get).value |
Select-Object displayName | Group-Object displayName

## Create hash table for guest user with sign-in logs
if ($Logins){

$Properties = @{
GuestUser = $user.userPrincipalName
GuestExternalEmail = $user.mail
Active = "Guest Active in Last 30 Days"
LastActiveSigninDate = $Logins[0].createdDateTime
LastAccessResource = $Logins[0].resourceDisplayName
TokenIssuerType = $Logins[0].tokenIssuerType
GroupMembership = $Groups.Name
}

## Add results to the results array
$Results += New-Object psobject -Property $properties
}

## Create hash table for guest user without sign-in logs
else {
$Properties = @{
GuestUser = $user.userPrincipalName
GuestExternalEmail = $user.mail
Active = "Guest has not been Active in Last 30 days"
LastActiveSigninDate = "N/A"
LastAccessResource = "N/A"
TokenIssuerType = "N/A"
GroupMembership = $Groups.Name
    }

## Add results to the results array
$Results += New-Object psobject -Property $properties
    }
}

## Format results 
$results | Select-Object GuestExternalEmail,GuestUser,Active,LastActiveSigninDate,LastAccessResource,TokenIssuerType,GroupMembership