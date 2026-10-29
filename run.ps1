# =========================================================================
# Mn Checker -- Universal Remote Bootstrapper (PowerShell Edition)
# สั่งรันบนเครื่องไหนก็ได้ผ่านคำสั่งเดียว: irm https://raw.githubusercontent.com/MONXYZ-ss/MnChecker/main/run.ps1 | iex
# โหมดตรวจเช็คชั่วคราว (Portable Mode) - ปลอดภัย ไม่ฝังระบบ ไม่รันค้างตอนเปิดคอมใหม่!
# =========================================================================

$ErrorActionPreference = "Stop"

# --- CONFIGURATION ---
$ScriptUrl = "https://raw.githubusercontent.com/MONXYZ-ss/MnChecker/main/run.ps1"
$DefaultDownloadUrl = "https://raw.githubusercontent.com/MONXYZ-ss/MnChecker/main/MnChecker.exe"
$DownloadUrl = if ($env:MN_URL) { $env:MN_URL } else { $DefaultDownloadUrl }

$InstallDir = "$env:LOCALAPPDATA\MnChecker"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
$LocalScript = "$InstallDir\run.ps1"
$TargetExe = "$InstallDir\MnChecker.exe"
$TaskName = "MnChecker_Daemon"

# Flags
$StopFlag = ($args -contains "-Stop") -or ($env:MN_STOP -eq "1")
$UninstallFlag = ($args -contains "-Uninstall") -or ($env:MN_UNINSTALL -eq "1")
$StatusFlag = ($args -contains "-Status") -or ($env:MN_STATUS -eq "1")
$PersistFlag = ($args -contains "-Install") -or ($args -contains "-Persist") -or ($args -contains "-Daemon") -or ($env:MN_PERSIST -eq "1")

# 1. Administrator Self-Elevation Check (ต้องใช้สิทธิ์ Administrator เพื่อเข้าถึงไฟล์ระบบ)
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host ""
    Write-Host "   ======================================================================" -ForegroundColor Red
    Write-Host "     [!] Mn Checker จำเป็นต้องใช้สิทธิ์ Administrator เพื่อตรวจเช็คไฟล์ระบบ" -ForegroundColor Yellow
    Write-Host "     [*] กำลังขอสิทธิ์ผู้ดูแลระบบ (UAC)... กรุณากด Yes บนหน้าต่างที่เด้งขึ้นมา" -ForegroundColor Cyan
    Write-Host "   ======================================================================" -ForegroundColor Red
    Write-Host ""

    # Download clean copy of script to persistent file to avoid iex recursion loop
    $ElevatedSuccess = $false
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $WebClient.DownloadFile($ScriptUrl, $LocalScript)
        if (Test-Path $LocalScript) {
            Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$LocalScript`"") -Verb RunAs
            $ElevatedSuccess = $true
        }
    } catch { }

    if (-not $ElevatedSuccess) {
        # Fallback elevation directly through irm
        Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -Command `"irm $ScriptUrl | iex`"") -Verb RunAs
    }
    return
}

# --- Command Handler: Stop ---
if ($StopFlag) {
    Write-Host " [*] กำลังสั่งหยุดการทำงานของเซิร์ฟเวอร์ Mn Checker..." -ForegroundColor Yellow
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
            ($_.Name -match "^(python|MnChecker)" -and ($_.CommandLine -like "*gxchecker*" -or $_.Name -like "*MnChecker*")) -and $_.ProcessId -ne $PID 
        } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
        $OldPort = Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
        if ($OldPort) {
            foreach ($p in $OldPort) { if ($p -gt 0 -and $p -ne $PID) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } }
        }
    } catch { }
    Write-Host " [OK] สั่งหยุดการทำงานเรียบร้อย!" -ForegroundColor Green
    return
}

# --- Command Handler: Uninstall ---
if ($UninstallFlag) {
    Write-Host " [*] กำลังถอนการติดตั้งระบบ 24/7..." -ForegroundColor Yellow
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch { }
    try {
        Get-Process -Name "*MnChecker*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch { }
    Write-Host " [OK] ถอนการติดตั้งและหยุดการทำงานเรียบร้อย!" -ForegroundColor Green
    return
}

# --- Command Handler: Status ---
if ($StatusFlag) {
    $PortProc = Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    $RunningProc = if ($PortProc) { Get-Process -Id $PortProc -ErrorAction SilentlyContinue } else { $null }
    if ($RunningProc) {
        Write-Host " [OK] Mn Checker กำลังทำงานอยู่หลังบ้านตลอดเวลา (ACTIVE 24/7)" -ForegroundColor Green
        Write-Host "      - Process ID: $($RunningProc.Id)" -ForegroundColor White
        Write-Host "      - Web URL: http://127.0.0.1:8787" -ForegroundColor Cyan
    } else {
        Write-Host " [X] Mn Checker ยังไม่ได้ทำงาน" -ForegroundColor Red
    }
    return
}

Clear-Host
Write-Host ""
Write-Host "   ======================================================================" -ForegroundColor Red
Write-Host "     [+] Mn Checker - Forensic & Anti-Cheat Inspection Suite" -ForegroundColor White
Write-Host "     [+] Engine: 42 Forensic Modules (Hardcore & Absence Detection)" -ForegroundColor Cyan
Write-Host "     [+] Mode: Portable Clean Check (ไม่ฝังระบบ / ไม่รันออโต้ตอนเปิดคอม)" -ForegroundColor Green
Write-Host "   ======================================================================" -ForegroundColor Red
Write-Host ""

# 2. Acquire Standalone Binary
if (-not (Test-Path $TargetExe)) {
    # Check if a copy exists locally in script or dist directory
    $FoundLocal = $false
    $LocalSources = @(
        "$PSScriptRoot\MnChecker.exe",
        "$PSScriptRoot\dist\MnChecker.exe",
        "$env:TEMP\MnChecker\MnChecker.exe"
    )
    foreach ($src in $LocalSources) {
        if ($src -and (Test-Path $src)) {
            Copy-Item -Path $src -Destination $TargetExe -Force
            $FoundLocal = $true
            break
        }
    }

    if (-not $FoundLocal) {
        Write-Host " [*] กำลังดาวน์โหลด MnChecker Standalone Package (22 MB)..." -ForegroundColor Cyan
        $DownloadSources = @(
            $DownloadUrl,
            "https://raw.githubusercontent.com/MONXYZ-ss/MnChecker/main/MnChecker.exe",
            "https://github.com/MONXYZ-ss/MnChecker/releases/latest/download/MnChecker.exe",
            "https://github.com/MONXYZ-ss/MnChecker/raw/main/MnChecker.exe",
            "http://127.0.0.1:8787/MnChecker.exe"
        ) | Select-Object -Unique

        $DownloadSuccess = $false
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

        foreach ($url in $DownloadSources) {
            if (-not $url) { continue }
            try {
                Write-Host " [*] กำลังเชื่อมต่อ: $url" -ForegroundColor Gray
                $WebClient.DownloadFile($url, $TargetExe)
                if ((Test-Path $TargetExe) -and ((Get-Item $TargetExe).Length -gt 1048576)) {
                    $DownloadSuccess = $true
                    Write-Host " [OK] ดาวน์โหลดตัวเอนจิ้นสำเร็จ ($([math]::Round((Get-Item $TargetExe).Length / 1MB, 2)) MB)!" -ForegroundColor Green
                    break
                }
            } catch { }
        }

        if (-not $DownloadSuccess) {
            Write-Host " [!] ไม่สามารถดาวน์โหลดไฟล์ MnChecker.exe ได้จากทุกช่องทาง" -ForegroundColor Red
            Write-Host " [!] โปรดตรวจสอบว่าได้อัปโหลด MnChecker.exe ขึ้น GitHub Repo MONXYZ-ss/MnChecker แล้วหรือไม่" -ForegroundColor Yellow
            return
        }
    }
}

# 3. Stop any stale process on port 8787
try {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
        ($_.Name -match "^(python|MnChecker)" -and ($_.CommandLine -like "*gxchecker*" -or $_.Name -like "*MnChecker*")) -and $_.ProcessId -ne $PID 
    } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    $OldPort = Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
    if ($OldPort) {
        foreach ($p in $OldPort) { if ($p -gt 0 -and $p -ne $PID) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } }
    }
} catch { }

# 4. Clean up any existing auto-start / Task Scheduler persistence (DEFAULT: NO AUTO-START ON BOOT)
# ป้องกันไม่ให้ฝังในเครื่องคนอื่นเวลาเปิดคอมใหม่
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
} catch { }

if ($PersistFlag) {
    Write-Host " [*] กำลังลงทะเบียน Auto-Start 24/7 (Admin Host Mode)..." -ForegroundColor Cyan
    try {
        $Action = New-ScheduledTaskAction -Execute $TargetExe -WorkingDirectory $InstallDir
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
        $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host " [OK] เปิดใช้งาน Auto-Start ตอนเปิดเครื่องเรียบร้อย" -ForegroundColor Green
    } catch { }
} else {
    Write-Host " [*] โหมดตรวจเช็คปกติ (Portable Mode): ไม่ฝังระบบ ไม่รันออโต้ตอนเปิดเครื่องใหม่" -ForegroundColor Gray
}

# 5. Launch Background Process for Current Inspection Session Only
Write-Host " [*] กำลังเปิดเอนจิ้น Mn Checker สำหรับการตรวจเช็ค..." -ForegroundColor Cyan
Start-Process -FilePath $TargetExe -WorkingDirectory $InstallDir -WindowStyle Hidden

$TargetUrl = "http://127.0.0.1:8787"
$Ready = $false
for ($i = 0; $i -lt 35; $i++) {
    Start-Sleep -Milliseconds 400
    try {
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $TcpClient.Connect("127.0.0.1", 8787)
        if ($TcpClient.Connected) {
            $TcpClient.Close()
            $Ready = $true
            break
        }
    } catch { }
}

if ($Ready) {
    $LivePid = (Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | Where-Object { $_ -gt 0 }) -join ", "
    Write-Host ""
    Write-Host "   ======================================================================" -ForegroundColor Green
    Write-Host "     [OK] Mn Checker เปิดระบบตรวจเช็คสำเร็จเรียบร้อย!" -ForegroundColor White
    Write-Host "     [*] Process ID: $LivePid | สิทธิ์: Administrator" -ForegroundColor Cyan
    Write-Host "     [*] Web Dashboard: $TargetUrl" -ForegroundColor White
    Write-Host "     [*] ความปลอดภัย: ทำงานเฉพาะรอบนี้ เมื่อกดปิดโปรแกรมจะหยุดทำงาน และไม่รันตอนเปิดคอมใหม่" -ForegroundColor Gray
    Write-Host "   ======================================================================" -ForegroundColor Green
    Write-Host ""
    
    # Automatically open the web browser for the user
    Start-Process $TargetUrl
    Start-Sleep -Seconds 3
} else {
    Write-Host " [!] เซิร์ฟเวอร์ใช้เวลาสตาร์ตนานกว่าปกติ กำลังเปิดเบราว์เซอร์..." -ForegroundColor Yellow
    Start-Process $TargetUrl
}
