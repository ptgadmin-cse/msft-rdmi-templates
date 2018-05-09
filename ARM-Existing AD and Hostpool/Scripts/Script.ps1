﻿[cmdletbinding()]
param(
    [parameter(mandatory = $true)]
    [string]$RDBrokerURL,

    [parameter(mandatory = $true)]
    [string]$InitializeDBSecret,

    [parameter(mandatory = $true)]       
    [string]$HostPoolName,

    [parameter(mandatory = $true)]       
    [int]$MaxSessionLimit,

    [parameter(mandatory = $true)] 
    [string]$Hours,

   
    [parameter(mandatory = $true)]       
    [string]$DelegateAdminUsername,

    [parameter(mandatory = $true)]       
    [string]$DelegateAdminpassword,

    
    [parameter(mandatory = $true)] 
    [string]$DomainAdminUsername,

    [parameter(mandatory = $true)] 
    [string]$DomainAdminPassword,

    
    [parameter(mandatory = $true)] 
    [string]$SxSStackInstaller,

    [parameter(mandatory = $true)] 
    [string]$AgentInstaller
    )


$CheckRegistery=Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent
$SessionHostName=(Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
if(!$CheckRegistery){
Import-Module .\PowershellModules\Microsoft.RDInfra.RDPowershell.dll
$Securepass=ConvertTo-SecureString -String $DelegateAdminpassword -AsPlainText -Force
$Credentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList($DelegateAdminUsername, $Securepass)

$DAdminSecurepass=ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
$domaincredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList($DomainAdminUsername, $DAdminSecurepass)



#Setting RDS Context
Set-RdsContext -DeploymentUrl $RDBrokerURL -Credential $Credentials
#Getting RDS Tenant
$GetTenant=Get-RdsTenant
$TenantName=$GetTenant.TenantName
$HPName=Get-RdsHostPool -TenantName $TenantName -Name $HostPoolName -ErrorAction SilentlyContinue
if(!$HPName){
$Registered=Export-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName
.\DeployAgent.ps1 -ComputerName $SessionHostName -AgentInstaller $AgentInstaller -SxSStackInstaller $SxSStackInstaller -InitializeDBSecret $InitializeDBSecret -AdminCredentials $domaincredentials -TenantName $TenantName -PoolName $HostPoolName -RegistrationToken $Registered.Token -StartAgent
Set-RdsSessionHost -TenantName $TenantName -HostPoolName $HostPoolName -Name $SessionHostName -AllowNewSession $true -MaxSessionLimit $MaxSessionLimit
}
Else
{
$Hostpool=New-RdsHostPool -TenantName $TenantName -Name $HostPoolName -Description $Description -FriendlyName $FriendlyName
$ToRegister=New-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName -ExpirationHours $Hours
.\DeployAgent.ps1 -ComputerName $SessionHostName -AgentInstaller $AgentInstaller -SxSStackInstaller $SxSStackInstaller -InitializeDBSecret $InitializeDBSecret -AdminCredentials $domaincredentials -TenantName $TenantName -PoolName $HostPoolName -RegistrationToken $ToRegister.Token -StartAgent
Set-RdsSessionHost -TenantName $TenantName -HostPoolName $HostPoolName -Name $SessionHostName -AllowNewSession $true -MaxSessionLimit $MaxSessionLimit
}
}