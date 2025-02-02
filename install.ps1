# install.ps1

# Define paths
$installDir = "$env:USERPROFILE\WiFiAutoLogin"
$scriptName = "wifi_auto_login_realtime.ps1"
$scriptPath = Join-Path $installDir $scriptName
$credentialsFile = Join-Path $installDir "credentials.txt"
$credentialIndexFile = "$env:USERPROFILE\.credential_index"
$logFile = Join-Path $installDir "wifi_auto_login_log.txt"

# Create installation folder
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Create the main worker script
$workerScript = @'
# wifi_auto_login_realtime.ps1
# Polls for connectivity loss and auto-rotates credentials to log in via the campnet portal.

# Configuration
$credentialsFile = "$env:USERPROFILE\WiFiAutoLogin\credentials.txt"
$credentialIndexFile = "$env:USERPROFILE\.credential_index"
$loginURL = "https://10.1.0.10:8090/login.xml"
$logFile = "$env:USERPROFILE\WiFiAutoLogin\wifi_auto_login_log.txt"

function Log-Message {
    param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp: $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
}

function Show-Notification {
    param([string]$message)
    # Use .NET to show a balloon tip (requires adding Windows Forms)
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = "WiFi Auto-Login"
    $notify.BalloonTipText = $message
    $notify.Visible = $true
    $notify.ShowBalloonTip(5000)
    Start-Sleep -Seconds 5
    $notify.Dispose()
}

function Get-NextCredentials {
    if (-not (Test-Path $credentialIndexFile)) {
        Set-Content -Path $credentialIndexFile -Value "0"
    }
    $index = [int](Get-Content $credentialIndexFile)
    $lines = Get-Content $credentialsFile
    if ($lines.Count -eq 0) {
        Log-Message "No credentials found in $credentialsFile"
        return $null
    }
    if ($index -ge $lines.Count) {
        $index = 0
    }
    $credLine = $lines[$index]
    # Split CSV: expected format: Name,username,password
    $parts = $credLine -split ","
    if ($parts.Count -lt 3) {
        Log-Message "Invalid credential format: $credLine"
        return $null
    }
    # Update index for next call
    $next = ($index + 1) % $lines.Count
    Set-Content -Path $credentialIndexFile -Value $next

    return @{
        Name = $parts[0].Trim();
        Username = $parts[1].Trim();
        Password = $parts[2].Trim()
    }
}

function Login {
    $creds = Get-NextCredentials
    if ($creds -eq $null) { return }
    $username = $creds.Username
    $password = $creds.Password
    # Get current time in ms since epoch
    $a = [int]((Get-Date).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalMilliseconds)
    
    # Prepare form fields
    $form = @{
        mode        = "191"
        username    = $username
        password    = $password
        a           = $a
        producttype = "0"
    }

    try {
        # Send POST request. Ignore cert errors similar to curl -k.
        $response = Invoke-WebRequest -Uri $loginURL -Method POST -Body $form -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
        if ($response.Content -match "LIVE") {
            Show-Notification "Logged in successfully with ID: $username"
        }
        else {
            Show-Notification "Login failed for ID: $username"
            Log-Message "Login failed for ID: $username. Response: $($response.Content)"
        }
    }
    catch {
        Show-Notification "Error during login for ID: $username"
        Log-Message "Error during login: $_"
    }
}

function Is-Connected {
    try {
        # Use Microsoft's connectivity test URL.
        $resp = Invoke-WebRequest -Uri "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 10
        if ($resp.Content -match "Microsoft") {
            return $true
        }
    }
    catch {
        # Ignore errors
    }
    return $false
}

# Main loop
while ($true) {
    if (-not (Is-Connected)) {
        Log-Message "Connectivity lost; triggering auto-login..."
        Login
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Seconds 5
}
'@

Set-Content -Path $scriptPath -Value $workerScript -Encoding UTF8

# Ensure credentials file exists; if not, create a sample.
if (-not (Test-Path $credentialsFile)) {
    "Name1,username1,password1" | Out-File -FilePath $credentialsFile -Encoding utf8
}

# Create/Update Scheduled Task to run the worker script at logon.
$taskName = "WiFiAutoLogin"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Register the task (if it exists, overwrite)
try {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "$env:USERNAME" -RunLevel Highest
    Write-Output "✅ WiFi Auto-Login installed successfully! Scheduled Task '$taskName' created."
}
catch {
    Write-Output "❌ Failed to create Scheduled Task. Error: $_"
}
