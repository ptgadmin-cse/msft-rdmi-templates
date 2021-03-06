﻿param(
    [parameter(mandatory = $true)]
    [string]$RDBrokerURL,

    [parameter(mandatory = $true)]
    [string]$InitializeDBSecret,

    [parameter(mandatory = $true)]       
    [string]$HostPoolName,

    [parameter(mandatory = $false)]       
    [string]$Description,

    [parameter(mandatory = $false)]       
    [string]$FriendlyName,


    [parameter(mandatory = $true)]       
    [int]$MaxSessionLimit,

    [parameter(mandatory = $true)] 
    [string]$Hours,

    [parameter(mandatory = $true)] 
    [string]$fileURI,
   
    [parameter(mandatory = $true)]       
    [string]$DelegateAdminUsername,

    [parameter(mandatory = $true)]       
    [string]$DelegateAdminpassword,

    
    [parameter(mandatory = $true)] 
    [string]$DomainAdminUsername,

    [parameter(mandatory = $true)] 
    [string]$DomainAdminPassword
    )

$computers=Get-ADComputer -Filter 'Name -like "rdsh*"'
$computerlist=$computers.name

$DAdminSecurepass= ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force 
$domaincredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList($DomainAdminUsername, $DAdminSecurepass)


Invoke-Command -ComputerName $computerlist -Credential $domaincredentials -ScriptBlock{
param($RDBrokerURL,$InitializeDBSecret,$HostPoolName,$Description,$FriendlyName,$MaxSessionLimit,$Hours,$fileURI,$DelegateAdminUsername,$DelegateAdminpassword,$DomainAdminUsername,$DomainAdminPassword)
Invoke-WebRequest -Uri $fileURI -OutFile "C:\DeployAgent.zip"
Start-Sleep -Seconds 240
New-Item -Path "C:\DeployAgent" -ItemType directory -Force -ErrorAction SilentlyContinue
Expand-Archive "C:\DeployAgent.zip" -DestinationPath "C:\DeployAgent" -ErrorAction SilentlyContinue
cd "C:\DeployAgent"
$CheckRegistery=Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue
$SessionHostName=(Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
if(!$CheckRegistery){
Import-Module .\PowershellModules\Microsoft.RDInfra.RDPowershell.dll
$Securepass=ConvertTo-SecureString -String $DelegateAdminpassword -AsPlainText -Force
$Credentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList($DelegateAdminUsername, $Securepass)
$DAdminSecurepass=ConvertTo-SecureString -String $DomainAdminPassword -AsPlainText -Force
$domaincredentials=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList($DomainAdminUsername, $DAdminSecurepass)



#Setting RDS Context
Set-RdsContext -DeploymentUrl $RDBrokerURL -Credential $Credentials
write-host "executed success"
#Getting RDS Tenant
#$GetTenant=Get-RdsTenant
#$TenantName=$GetTenant.TenantName
$TenantName="MSFT-Tenant"
$HPName=Get-RdsHostPool -TenantName $TenantName -Name $HostPoolName -ErrorAction SilentlyContinue
if($HPName){
$Registered=Export-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName
.\DeployAgent.ps1 -ComputerName $SessionHostName -AgentInstaller ".\RDInfraAgentInstall\Microsoft.RDInfra.RDAgent.Installer-x64.msi" -SxSStackInstaller ".\RDInfraSxSStackInstall\Microsoft.RDInfra.StackSxS.Installer-x64.msi" -InitializeDBSecret $InitializeDBSecret -AdminCredentials $domaincredentials -TenantName $TenantName -PoolName $HostPoolName -RegistrationToken $Registered.Token -StartAgent $true
Set-RdsSessionHost -TenantName $TenantName -HostPoolName $HostPoolName -Name $SessionHostName -AllowNewSession $true -MaxSessionLimit $MaxSessionLimit
}
Else
{
$Hostpool=New-RdsHostPool -TenantName $TenantName -Name $HostPoolName -Description $Description -FriendlyName $FriendlyName
$ToRegister=New-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName -ExpirationHours $Hours
.\DeployAgent.ps1 -ComputerName $SessionHostName -AgentInstaller ".\RDInfraAgentInstall\Microsoft.RDInfra.RDAgent.Installer-x64.msi" -SxSStackInstaller ".\RDInfraSxSStackInstall\Microsoft.RDInfra.StackSxS.Installer-x64.msi" -InitializeDBSecret $InitializeDBSecret -AdminCredentials $domaincredentials -TenantName $TenantName -PoolName $HostPoolName -RegistrationToken $ToRegister.Token -StartAgent $true
Set-RdsSessionHost -TenantName $TenantName -HostPoolName $HostPoolName -Name $SessionHostName -AllowNewSession $true -MaxSessionLimit $MaxSessionLimit
}
}
#Remove-Item -Path "C:\DeployAgent.zip" -Recurse -force
#Remove-Item -Path "C:\DeployAgent" -Recurse -Force
} -ArgumentList ($RDBrokerURL,$InitializeDBSecret,$HostPoolName,$Description,$FriendlyName,$MaxSessionLimit,$Hours,$fileURI,$DelegateAdminUsername,$DelegateAdminpassword,$DomainAdminUsername,$DomainAdminPassword)
