# ============================================================================
# Smart Git Commit - Fixed Version (No Pager Stuck)
# ============================================================================

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Message = "",

    [Parameter(Mandatory = $false)]
    [Alias("y")]
    [switch]$Yes,

    [Parameter(Mandatory = $false)]
    [Alias("p")]
    [switch]$Push,

    [Parameter(Mandatory = $false)]
    [Alias("a")]
    [switch]$All,

    [Parameter(Mandatory = $false)]
    [Alias("f")]
    [string]$FilePattern = "",

    [Parameter(Mandatory = $false)]
    [Alias("n")]
    [switch]$NoFix
)

# Colors
$green = "Green"
$red = "Red"
$yellow = "Yellow"
$cyan = "Cyan"
$gray = "Gray"

# Helper functions
function Write-Green { Write-Host "[OK] $args" -ForegroundColor $green }
function Write-Red { Write-Host "[ERROR] $args" -ForegroundColor $red }
function Write-Yellow { Write-Host "[WARNING] $args" -ForegroundColor $yellow }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor $cyan }
function Write-Detail { Write-Host "  $args" -ForegroundColor $gray }

# Function to run git without pager
function Git-NoPager {
    param([string]$Command, [string[]]$Arguments = @())
    
    # Disable all pagers
    $env:GIT_PAGER = ""
    $env:PAGER = "cat"
    
    # Build the full command
    $fullCmd = "git $Command " + ($Arguments -join " ")
    
    # Execute and capture output
    $output = & git $Command @Arguments 2>&1
    
    # Return the output as array of strings
    return @($output)
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host ""
    Write-Host "Smart Git Commit" -ForegroundColor $cyan
    Write-Host "Fixes Cursor issues, commits intelligently" -ForegroundColor $gray
    Write-Host ""

    # Step 1: Validate Environment
    Write-Info "Step 1: Checking environment..."
    
    # Check git
    try { 
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $gitVersion) {
            Write-Red "Git not found or not in PATH"
            Write-Detail "Download from: https://git-scm.com/downloads"
            exit 1
        }
    } 
    catch {
        Write-Red "Git not found. Install git first."
        exit 1
    }
    
    # Check git repo
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if (-not $gitRoot) {
        Write-Red "Not in a git repository."
        Write-Detail "Navigate to a git repository and try again."
        exit 1
    }
    
    Write-Detail "Repository: $(Split-Path $gitRoot -Leaf)"
    $branch = git branch --show-current 2>$null
    if ($branch) {
        Write-Detail "Branch: $branch"
    }

    # Step 2: Analyze Git Status
    Write-Info "Step 2: Analyzing changes..."
    
    $statusLines = @(git status --porcelain)
    if (-not $statusLines -or $statusLines.Count -eq 0) {
        Write-Green "No changes to commit"
        exit 0
    }
    
    # Parse status
    $dangerousCount = 0
    $stagedCount = 0
    $unstagedCount = 0
    
    Write-Host ""
    Write-Info "Current Status:"
    
    foreach ($line in $statusLines) {
        if ($line.Length -lt 3) { continue }
        
        $code = $line.Substring(0, 2)
        $file = $line.Substring(3).Trim()
        
        # Remove quotes if present
        if ($file.StartsWith('"') -and $file.EndsWith('"')) {
            $file = $file.Substring(1, $file.Length - 2)
        }
        
        switch ($code) {
            "MM" { 
                Write-Host "  [WARNING] [$code] $file" -ForegroundColor $yellow
                Write-Detail "Staged AND modified (Cursor issue)"
                $dangerousCount++
            }
            "AM" { 
                Write-Host "  [WARNING] [$code] $file" -ForegroundColor $yellow
                Write-Detail "Added but modified after staging (Cursor issue)"
                $dangerousCount++
            }
            "RM" { 
                Write-Host "  [WARNING] [$code] $file" -ForegroundColor $yellow
                Write-Detail "Renamed but modified after staging (Cursor issue)"
                $dangerousCount++
            }
            "M " { 
                Write-Host "  [OK] [$code] $file" -ForegroundColor $green
                Write-Detail "Staged and ready"
                $stagedCount++
            }
            " M" { 
                Write-Host "  [MOD] [$code] $file" -ForegroundColor $yellow
                Write-Detail "Modified but not staged"
                $unstagedCount++
            }
            "??" { 
                Write-Host "  [NEW] [$code] $file" -ForegroundColor $cyan
                Write-Detail "Untracked file"
                $unstagedCount++
            }
            default { 
                Write-Host "  [FILE] [$code] $file" -ForegroundColor $gray
            }
        }
    }
    
    # Summary
    Write-Host ""
    Write-Info "Summary:"
    if ($dangerousCount -gt 0) {
        Write-Host "  [CRITICAL] Cursor issues: $dangerousCount" -ForegroundColor $yellow
    } else {
        Write-Host "  [OK] Cursor issues: $dangerousCount" -ForegroundColor $green
    }
    Write-Host "  [OK] Staged files: $stagedCount" -ForegroundColor $green
    if ($unstagedCount -gt 0) {
        Write-Host "  [MOD] Unstaged files: $unstagedCount" -ForegroundColor $yellow
    } else {
        Write-Host "  [OK] Unstaged files: $unstagedCount" -ForegroundColor $green
    }

    # Step 3: Fix Cursor Issues
    if ($dangerousCount -gt 0 -and -not $NoFix) {
        Write-Info "Step 3: Fixing Cursor staging issues..."
        
        $cursorIssues = $statusLines | Where-Object { $_ -match '^(MM|AM|RM)' }
        
        if (-not $Yes) {
            Write-Yellow "Cursor staged different versions than your working directory."
            Write-Detail "This can cause you to commit old/wrong code."
            
            $choice = Read-Host "Fix by staging current working versions? (Y/N/S=Skip all)"
            
            switch ($choice.ToUpper()) {
                "Y" {
                    # Fix them
                    $fixedCount = 0
                    foreach ($line in $cursorIssues) {
                        $file = $line.Substring(3).Trim()
                        if ($file.StartsWith('"') -and $file.EndsWith('"')) {
                            $file = $file.Substring(1, $file.Length - 2)
                        }
                        git add -- "$file" 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Detail "Fixed: $file"
                            $fixedCount++
                        }
                    }
                    if ($fixedCount -gt 0) {
                        Write-Green "Fixed $fixedCount Cursor issue(s)"
                    }
                }
                "S" {
                    $NoFix = $true
                    Write-Info "Skipping all Cursor fixes for this session."
                }
                default {
                    Write-Yellow "Continuing with potentially wrong staging."
                }
            }
        }
        else {
            # Auto-fix in Yes mode
            $fixedCount = 0
            foreach ($line in $cursorIssues) {
                $file = $line.Substring(3).Trim()
                if ($file.StartsWith('"') -and $file.EndsWith('"')) {
                    $file = $file.Substring(1, $file.Length - 2)
                }
                git add -- "$file" 2>$null
                $fixedCount++
            }
            if ($fixedCount -gt 0) {
                Write-Green "Auto-fixed $fixedCount Cursor issue(s)"
            }
        }
    }

    # Step 4: Stage Files
    Write-Info "Step 4: Staging files..."
    
    if ($FilePattern) {
        Write-Detail "Staging files matching: $FilePattern"
        git add $FilePattern 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Green "Pattern-matched files staged"
        }
        else {
            Write-Yellow "No files matched pattern: $FilePattern"
        }
    }
    elseif ($All) {
        Write-Detail "Staging all changes..."
        git add -A 2>$null
        Write-Green "All changes staged"
    }
    else {
        # Check if we need to stage anything
        $staged = @(git diff --cached --name-only)
        
        if ($staged.Count -eq 0 -and $unstagedCount -gt 0) {
            if (-not $Yes) {
                $choice = Read-Host "Stage all unstaged files? (Y/N)"
                if ($choice -eq 'Y' -or $choice -eq 'y') {
                    git add -A 2>$null
                    Write-Green "All unstaged files staged"
                }
                else {
                    Write-Yellow "Only currently staged files will be committed."
                }
            }
            else {
                git add -A 2>$null
                Write-Green "Auto-staged all files"
            }
        }
        else {
            Write-Info "Using already staged files"
        }
    }

    # Step 5: Show Commit Preview
    Write-Info "Step 5: Commit preview..."
    
    $staged = @(git diff --cached --name-only)
    if ($staged.Count -eq 0) {
        Write-Red "No files staged for commit"
        Write-Detail "Use -All to stage all files or -FilePattern to stage specific files"
        exit 1
    }
    
    Write-Host ""
    Write-Info "Ready to commit $($staged.Count) file(s):"
    $staged | Select-Object -First 5 | ForEach-Object {
        Write-Host "  [OK] $_" -ForegroundColor $green
    }
    if ($staged.Count -gt 5) {
        Write-Host "  ... and $($staged.Count - 5) more" -ForegroundColor $gray
    }
    
    # Show diff summary only - SOLUTION 4: Removed full diff option to prevent clutter
    Write-Host ""
    Write-Info "Changes summary:"
    $diffOutput = git --no-pager diff --cached --stat 2>$null
    Write-Host $diffOutput

    # Step 6: Get Commit Message
    Write-Info "Step 6: Commit message..."
    
    if ([string]::IsNullOrWhiteSpace($Message)) {
        if (-not $Yes) {
            Write-Host ""
            Write-Host "Enter commit message (empty line to finish):" -ForegroundColor $cyan
            Write-Detail "Tip: Start with feat:, fix:, chore:, docs:, test:, refactor:, style:, perf:"
            
            $lines = @()
            while ($true) {
                $line = Read-Host "  "
                if ([string]::IsNullOrEmpty($line)) { break }
                $lines += $line
            }
            
            $Message = $lines -join "`n"
            
            if ([string]::IsNullOrWhiteSpace($Message)) {
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $Message = "Update: $timestamp"
                Write-Detail "Using default: $Message"
            }
        }
        else {
            # Auto-generate message in Yes mode
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $Message = "Update: $timestamp"
            Write-Detail "Auto-generated message: $Message"
        }
    }
    
    Write-Host ""
    Write-Host "Commit message:" -ForegroundColor $cyan
    Write-Host $Message -ForegroundColor $green

    # Step 7: Confirm & Commit
    Write-Info "Step 7: Confirm commit..."
    
    if (-not $Yes) {
        Write-Host ""
        $confirm = Read-Host "Proceed with commit? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Yellow "Commit cancelled."
            exit 0
        }
    }
    
    # Actually commit
    git commit -m $Message
    
    if ($LASTEXITCODE -eq 0) {
        $commitHash = git rev-parse --short HEAD 2>$null
        if ($commitHash) {
            Write-Green "Committed successfully! ($commitHash)"
        }
        else {
            Write-Green "Committed successfully!"
        }
        
        # Step 8: Push if requested
        if ($Push) {
            Write-Info "Step 8: Pushing to remote..."
            
            if ($branch) {
                if (-not $Yes) {
                    $pushConfirm = Read-Host "Push to remote? (Y/N)"
                    if ($pushConfirm -eq 'Y' -or $pushConfirm -eq 'y') {
                        git push 2>&1 | ForEach-Object {
                            if ($_ -match "error|rejected|fatal") {
                                Write-Host $_ -ForegroundColor $red
                            }
                            else {
                                Write-Host $_ -ForegroundColor $cyan
                            }
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Green "Pushed successfully!"
                        }
                    }
                }
                else {
                    git push 2>&1 | ForEach-Object {
                        if ($_ -match "error|rejected|fatal") {
                            Write-Host $_ -ForegroundColor $red
                        }
                        else {
                            Write-Host $_ -ForegroundColor $cyan
                        }
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Green "Pushed successfully!"
                    }
                }
            }
            else {
                Write-Red "Cannot push from detached HEAD state."
            }
        }
        
        # Final status
        Write-Host ""
        Write-Info "Final status:"
        git status --short
        
    }
    else {
        Write-Red "Commit failed"
        Write-Detail "Check git status for more information"
        exit 1
    }
}
catch {
    Write-Red "Error: $_"
    exit 1
}