# Ensure script is running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator."
    exit
}

# Set directory paths
$baseDir = "C:\Program Files\WiggleVpn"
$opensslDir = Join-Path -Path $baseDir -ChildPath "OpenSSL"
$certPath = Join-Path -Path $baseDir -ChildPath "MySPC.crt"
$pfxPath = Join-Path -Path $baseDir -ChildPath "MySPC.pfx"

# Prompt user for certificate information
Write-Output "Enter certificate information:"
$country = Read-Host "Country Name (2 letter code) [GB]"  # Default value is GB
$state = Read-Host "State or Province Name (full name) [East Sussex]"  # Default value is East Sussex
$locality = Read-Host "Locality Name (eg, city)"  # Default value is blank
$organization = Read-Host "Organization Name (eg, company) [Internet Widgits Pty Ltd]"  # Default value is Internet Widgits Pty Ltd
$organizationalUnit = Read-Host "Organizational Unit Name (eg, section)"  # Default value is blank
$commonName = Read-Host "Common Name (e.g. server FQDN or YOUR name) [Wiggle]"  # Default value is Wiggle
$emailAddress = Read-Host "Email Address []"  # Default value is blank

# Prompt user to enter password for PFX file
Write-Output "Enter password for PFX file:"
$pfxPassword = Read-Host -Prompt "Password" -AsSecureString

# Ensure directories exist
$dirsToCreate = @($baseDir, $opensslDir)
foreach ($dir in $dirsToCreate) {
    if (!(Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force
    }
}

# Generate RSA key and CSR using OpenSSL
Write-Output "Generating RSA private key and Certificate Signing Request (CSR) using OpenSSL..."
$command = @"
openssl req -new -newkey rsa:2048 -nodes -keyout "$baseDir\MySPC.key" -out "$baseDir\MySPC.req" -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalUnit/CN=$commonName/emailAddress=$emailAddress"
"@
Invoke-Expression $command

# Generate certificate (CRT) from CSR
Write-Output "Generating certificate (CRT) using OpenSSL..."
$command = @"
openssl x509 -req -in "$baseDir\MySPC.req" -signkey "$baseDir\MySPC.key" -out "$baseDir\MySPC.crt" -days 365
"@
Invoke-Expression $command

# Create PKCS#12 (PFX) file using OpenSSL
Write-Output "Creating PKCS#12 (PFX) file using OpenSSL..."
$command = @"
openssl pkcs12 -export -out "$baseDir\MySPC.pfx" -inkey "$baseDir\MySPC.key" -in "$baseDir\MySPC.crt" -password pass:$pfxPassword
"@
Invoke-Expression $command

# Import PFX file into Windows Keystore
function Import-PFXCertificate {
    Write-Output "Importing PFX file into Windows Keystore..."
    $certStoreLocation = "Cert:\LocalMachine\My"

    # Convert SecureString password to plaintext
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassword))

    Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation $certStoreLocation -Password $plainPassword
}

try {
    # Main script execution
    Import-PFXCertificate
    Write-Output "Certificate imported successfully."
} catch {
    Write-Error "Failed to import the certificate: $_"
    exit 1
}
