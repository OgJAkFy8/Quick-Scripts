
#Is there a machine Cert?
$hasCert = Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object
#Is it a DoD Cert?
$hasDodCert = Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object -Property PSComputerName, Subject | Select-String -Pattern DoD
#Will it be expiring in the next 90 days or is it expired?
$certExpiring = Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object -Property PSComputerName, Subject, @{n=’ExpireInDays’;e={($_.notafter – (Get-Date)).Days}} | Where-Object {$_.ExpireInDays -lt 90}  
#Whats my DNS Name?
$DNSName = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
# csrScript function partially borrowed and from https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/certificates/GenerateCertificateSigningRequest(CSR).ps1
#Generate CSR
function csrScript{
mkdir c:\csr
#######################
# Setting the variables
#######################
$UID = [guid]::NewGuid()
$files = @{}
$files['settings'] = "$($Env:path = $env:path +";c:\")\CSR\$($UID)-settings.inf";
$files['csr'] = "$($Env:path = $env:path +";c:\")\CSR\$(([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname).req"
$CN = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
#########################
# Create the settings.inf
#########################
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
$settingsInf = $settingsInf.Replace("{{CN}}",$CN)
# Save settings to file in temp
$settingsInf > $files['settings']
# Done, we can start with the CSR
Clear-Host
#################################
# CSR TIME
#################################
# Display summary
Write-Host "Certificate information
Common name: $CN
Signature algorithm: SHA256
Key algorithm: RSA
Key size: 2048
"
certreq -new $files['settings'] $files['csr'] > $null
# Output the CSR
$CSR = Get-Content $files['csr']
Write-Output $CSR
Write-Host "
"
#Export CSR to share drive
Copy-Item $files['csr'] -Destination '<UNC Path>\AutoCSR'
}

#LastCheck looks for a previously created CSR. If none is found, creates a new CSR.
Function LastCheck{

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
