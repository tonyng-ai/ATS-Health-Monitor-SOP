# Check-Screenshots.ps1
# Verifies all required screenshots exist for ATS Health Monitor documentation

$requiredScreenshots = @(
    @{ Figure = 1;  File = "ats-health-monitor-overview.png";          Desc = "Main Dashboard Overview" },
    @{ Figure = 2;  File = "ats-health-monitor-console-startup.png";   Desc = "Console Startup Output" },
    @{ Figure = 3;  File = "ats-health-monitor-navigation-tabs.png";   Desc = "Navigation Tabs" },
    @{ Figure = 4;  File = "ats-health-monitor-tab-overview.png";      Desc = "System Overview Tab" },
    @{ Figure = 5;  File = "ats-health-monitor-tab-positions.png";     Desc = "Positions Tab" },
    @{ Figure = 6;  File = "ats-health-monitor-tab-fix.png";           Desc = "FIX Protocol Tab" },
    @{ Figure = 7;  File = "ats-health-monitor-tab-pro.png";           Desc = "Pro Dashboard Tab" },
    @{ Figure = 8;  File = "ats-health-monitor-tab-email.png";         Desc = "Email Monitor Tab" },
    @{ Figure = 9;  File = "ats-health-monitor-tab-database.png";      Desc = "Database Monitor Tab" },
    @{ Figure = 10; File = "ats-health-monitor-tab-atslog.png";        Desc = "ATS Log Monitor Tab" },
    @{ Figure = 11; File = "ats-health-monitor-tab-stp-orders.png";    Desc = "STP Orders Tab" },
    @{ Figure = 12; File = "ats-health-monitor-tab-history.png";       Desc = "Order History Tab" },
    @{ Figure = 13; File = "ats-health-monitor-tab-health.png";        Desc = "System Health Tab" },
    @{ Figure = 14; File = "ats-health-monitor-tab-debug.png";         Desc = "Debug Dashboard Tab" },
    @{ Figure = 15; File = "ats-health-monitor-tab-setup.png";         Desc = "Setup/Configuration Tab" },
    @{ Figure = 16; File = "ats-health-monitor-login-page.png";        Desc = "RBAC Login Page" },
    @{ Figure = 17; File = "ats-health-monitor-user-session.png";      Desc = "User Session Info" },
    @{ Figure = 18; File = "ats-health-monitor-telegram-alert.png";    Desc = "Telegram Alert Example" },
    @{ Figure = 19; File = "ats-health-monitor-api-response.png";      Desc = "API Response Example" },
    @{ Figure = 20; File = "ats-health-monitor-test-results.png";      Desc = "Test Script Results" },
    @{ Figure = 21; File = "ats-health-monitor-go-test.png";           Desc = "Go Unit Test Output" }
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ATS Health Monitor - Screenshot Checklist" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$found = 0
$missing = 0

foreach ($screenshot in $requiredScreenshots) {
    $filePath = Join-Path $PSScriptRoot $screenshot.File
    $exists = Test-Path $filePath

    if ($exists) {
        $fileInfo = Get-Item $filePath
        $size = "{0:N0} KB" -f ($fileInfo.Length / 1KB)
        Write-Host "[OK]     " -ForegroundColor Green -NoNewline
        Write-Host "Figure $($screenshot.Figure): $($screenshot.Desc)" -NoNewline
        Write-Host " ($size)" -ForegroundColor DarkGray
        $found++
    } else {
        Write-Host "[MISSING]" -ForegroundColor Red -NoNewline
        Write-Host " Figure $($screenshot.Figure): $($screenshot.Desc)"
        Write-Host "         -> $($screenshot.File)" -ForegroundColor Yellow
        $missing++
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Required:  $($requiredScreenshots.Count)" -ForegroundColor White
Write-Host "  Found:           $found" -ForegroundColor Green
Write-Host "  Missing:         $missing" -ForegroundColor $(if ($missing -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($missing -eq 0) {
    Write-Host "[SUCCESS] All screenshots are present!" -ForegroundColor Green
} else {
    Write-Host "[ACTION REQUIRED] Please capture the missing screenshots." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To capture screenshots:" -ForegroundColor Cyan
    Write-Host "  1. Start ATS Health Monitor: .\ATS-Health-Monitor.exe -web -port 8080"
    Write-Host "  2. Open browser to http://localhost:8080"
    Write-Host "  3. Use Win+Shift+S to capture each screen"
    Write-Host "  4. Save PNG files to: $PSScriptRoot"
}

Write-Host ""

# Return exit code for CI/CD
exit $missing

