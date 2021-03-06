﻿

$MyLocalMachineCert = 'Cert:\LocalMachine\My'
function Get-ItemsExpireringInXDays
{
  param
  (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Data to filter')]
    $InputObject
  )
  process
  {
    if ($InputObject.ExpireInDays -lt 90)
    {
      $InputObject
    }
  }
}

# Is there a machine Cert?
$hasCert = Get-ChildItem -Path $MyLocalMachineCert | Select-Object

#Is it a DoD Cert?
$hasDodCert = Get-ChildItem -Path $MyLocalMachineCert | Select-Object -Property PSComputerName, Subject | Select-String -Pattern DoD

#Will it be expiring in the next 90 days or is it expired?
$certExpiring = Get-ChildItem -Path $MyLocalMachineCert | Select-Object -Property PSComputerName, Subject, @{n='ExpireInDays';e={($_.notafter - (Get-Date)).Days}} | Get-ItemsExpireringInXDays  

#Whats my DNS Name?
$DNSName = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname


# csrScript function partially borrowed and from https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/certificates/GenerateCertificateSigningRequest(CSR).ps1
#Generate CSR
function New-csrScript{
  
  try
  {
    $csrFolder = "$env:HOMEDRIVE\csr"
    New-Item -ItemType Directory -Path $csrFolder
  
    #######################  Setting the variables   #######################
    $UID = [guid]::NewGuid()
    ﻿
    #Is there a machine Cert?
    $MachineCertLocation = 'Cert:\LocalMachine\My'
    $hasCert = Get-ChildItem -Path $MachineCertLocation | Select-Object
  
    #Is it a DoD Cert?
    $hasDodCert = Get-ChildItem -Path $MachineCertLocation | Select-Object -Property PSComputerName, Subject | Select-String -Pattern DoD
  
    #Will it be expiring in the next 90 days or is it expired?
    $certExpiring = Get-ChildItem -Path $MachineCertLocation | Select-Object -Property PSComputerName, Subject, @{n='ExpireInDays';e={($_.notafter - (Get-Date)).Days}} | Get-ItemsExpireringInXDays  
  
    #Whats my DNS Name?
    $DNSName = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
  
  
    # csrScript function partially borrowed and from https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/certificates/GenerateCertificateSigningRequest(CSR).ps1
    #Generate CSR
    function script:csrScript{
      $csrFolder = "$env:HOMEDRIVE\csr"
      New-Item -ItemType Directory -Path $csrFolder
  
      #######################  Setting the variables    #######################
      $UID = [guid]::NewGuid()
      $files = @{}
      $files['settings'] = ('{0}\CSR\{1}-settings.inf' -f ($Env:path = $env:path +';c:\'), ($UID))

      $files['csr'] = "$($Env:path = $env:path +';c:\')\CSR\$(([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname).req"
      $CN = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
    
    
      ##########################   Create the settings.inf    #########################
      $settingsInf = "
        [Version]
        Signature=`"`$Windows NT`$
        [NewRequest]
        KeyLength = 2048
        Exportable = TRUE
        MachineKeySet = TRUE
        SMIME = FALSE
        RequestType = PKCS10
        ProviderName = `"Microsoft Strong Cryptographic Provider`"
        ProviderType = 1
        HashAlgorithm = sha256
        ;Variables
        Subject = `"CN={{CN}}`"
        ;Certreq info
        ;http://technet.microsoft.com/en-us/library/dn296456.aspx
        ;CSR Decoder
        ;https://certlogik.com/decoder/
        ;https://ssltools.websecurity.symantec.com/checker/views/csrCheck.jsp
      "
      $settingsInf = $settingsInf.Replace('{{CN}}',$CN)
    
      # Save settings to file in temp
      $settingsInf > $files['settings']
    
      # Done, we can start with the CSR
      Clear-Host
    
    
      ################################# CSR TIME     #################################
      # Display summary
      Write-Host ('Certificate information 
          Common name: {0}
          Signature algorithm: SHA256
          Key algorithm: RSA
      Key size: 2048' -f $CN)
      & "$env:windir\system32\certreq.exe" -new $files['settings'] $files['csr'] > $null
      # Output the CSR
      $CSR = Get-Content -Path $files['csr']
      Write-Output -InputObject $CSR
      Write-Host '
      '
      #Export CSR to share drive
      Copy-Item -Path $files['csr'] -Destination '<UNC Path>\AutoCSR'
    }

    #LastCheck looks for a previously created CSR. If none is found, creates a new CSR.
    Function script:LastCheck{

      if ((Get-ChildItem -Path '<UNC Path>\*.req') -match $DNSName) {
        exit
      }
      Else{
        csrScript
      }
    }


    #Call function if there is no machine cert.
    if ($hasCert -eq $null){
      LastCheck
    }
    
    #Call function if there is no DoD cert
    else{
      if ($hasDodCert -eq $null){
        LastCheck
      }
      else{
  
        #Call function if the cert is 90 days or less from expiration
        if ($certExpiring -eq $null){
            
          exit
        }
        else{
          LastCheck
        } 
      }
    } 

    $files = @{}
    $files['settings'] = "$($Env:path = $env:path +';c:\')\CSR\$($UID)-settings.inf"

    $files['csr'] = "$($Env:path = $env:path +';c:\')\CSR\$(([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname).req"
    
    $CN = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
  
  
    ##########################  Create the settings.inf   #########################
    $settingsInf = "
      [Version]
      Signature=`"`$Windows NT`$
      [NewRequest]
      KeyLength = 2048
      Exportable = TRUE
      MachineKeySet = TRUE
      SMIME = FALSE
      RequestType = PKCS10
      ProviderName = `"Microsoft Strong Cryptographic Provider`"
      ProviderType = 1
      HashAlgorithm = sha256
      ;Variables
      Subject = `"CN={{CN}}`"
      ;Certreq info
      ;http://technet.microsoft.com/en-us/library/dn296456.aspx
      ;CSR Decoder
      ;https://certlogik.com/decoder/
      ;https://ssltools.websecurity.symantec.com/checker/views/csrCheck.jsp
    "
    $settingsInf = $settingsInf.Replace('{{CN}}',$CN)
    # Save settings to file in temp
    $settingsInf > $files['settings']
    # Done, we can start with the CSR
    Clear-Host
  
  
    ##################################   CSR TIME   #################################
    # Display summary
    Write-Host ('Certificate information
        Common name: {0}
        Signature algorithm: SHA256
        Key algorithm: RSA
        Key size: 2048
    ' -f $CN)
    & "$env:windir\system32\certreq.exe" -new $files['settings'] $files['csr'] > $null
    # Output the CSR
    $CSR = Get-Content -Path $files['csr']
    Write-Output -InputObject $CSR
    Write-Host "`n"
  
    #Export CSR to share drive
    Copy-Item -Path $files['csr'] -Destination '<UNC Path>\AutoCSR'
  }
  # NOTE: When you use a SPECIFIC catch block, exceptions thrown by -ErrorAction Stop MAY LACK
  # some InvocationInfo details such as ScriptLineNumber.
  # REMEDY: If that affects you, remove the SPECIFIC exception type [System.Management.Automation.CommandNotFoundException] in the code below
  # and use ONE generic catch block instead. Such a catch block then handles ALL error types, so you would need to
  # add the logic to handle different error types differently by yourself.
  catch [System.Management.Automation.CommandNotFoundException]
  {
    # get error record
    [Management.Automation.ErrorRecord]$e = $_

    # retrieve information about runtime error
    $info = New-Object -TypeName PSObject -Property @{
      Exception = $e.Exception.Message
      Reason    = $e.CategoryInfo.Reason
      Target    = $e.CategoryInfo.TargetName
      Script    = $e.InvocationInfo.ScriptName
      Line      = $e.InvocationInfo.ScriptLineNumber
      Column    = $e.InvocationInfo.OffsetInLine
    }
    
    # output information. Post-process collected info, and log info (optional)
    $info
  }

}

<#LastCheck looks for a previously created CSR. If none is found, creates a new CSR.
Function LastCheck{

  if ((Get-ChildItem -Path '<UNC Path>\*.req') -match $DNSName) {
    
    exit
  }
    
  Else{
    csrScript
  }
}
#>

#Call function if there is no machine cert.
if ($hasCert -eq $null){

  LastCheck

}

#Call function if there is no DoD cert
else{

  if ($hasDodCert -eq $null){
     
    LastCheck
     
  }

  else{

    #Call function if the cert is 90 days or less from expiration
    if ($certExpiring -eq $null){
            
      exit
    }

    else{

      LastCheck
        
    } 
  }
} 