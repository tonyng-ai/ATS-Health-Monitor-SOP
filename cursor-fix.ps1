# ============================================================================
# Cursor Git Fix - Complete Solution
# Version: 4.1 (Sanitized & Optimized)
#
# ONE COMMAND: .\cursor-fix.ps1
# SAVE THIS IN YOUR PROJECT ROOT FOLDER
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Message = "",

    [Parameter(Mandatory = $false)]
    [switch]$Yes,

    [Parameter(Mandatory = $false)]
    [switch]$Push,

    [Parameter(Mandatory = $false)]
    [switch]$SkipStagingCheck
)

# Colors for output
$green = "Green"
$red = "Red"
$yellow = "Yellow"
$cyan = "Cyan"

# Helper functions
function Write-Green { Write-Host "✅ $args" -ForegroundColor $green }
function Write-Red { Write-Host "❌ $args" -ForegroundColor $red }
function Write-Yellow { Write-Host "⚠️  $args" -ForegroundColor $yellow }
function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor $cyan }

# Validate we're in a git repository
function Test-GitRepository {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Main function - fixes Cursor's staging issues
function Fix-CursorIssues {
    Write-Info "Checking for Cursor staging problems..."

    # Get git status in porcelain format for reliable parsing
    $status = git status --porcelain

    if (-not $status) {
        Write-Green "No changes to commit"
        return $true
    }

    # Find ALL Cursor issues (MM = Modified in both, AM = Added to index/Mod in worktree, RM = Renamed & Modified)
    # This detects when the staged code does NOT match the code on disk
    $cursorIssues = $status | Where-Object { $_ -match '^(MM|AM|RM)' }

    if (-not $cursorIssues) {
        Write-Green "No Cursor staging issues found"
        return $true
    }

    Write-Yellow "Found $($cursorIssues.Count) file(s) with staging mismatches:"

    foreach ($file in $cursorIssues) {
        # Extract filename (handle Git's quoting)
        $rawName = $file.Substring(3).Trim()
        if ($rawName.StartsWith('"') -and $rawName.EndsWith('"')) {
            $rawName = $rawName.Substring(1, $rawName.Length - 2)
        }
        
        Write-Host "  🚨 $rawName" -ForegroundColor $yellow
    }

    Write-Host ""
    Write-Yellow "PROBLEM: The staged version doesn't match your working directory."
    Write-Host "  Cursor may have staged an older or partial version." -ForegroundColor $red
    
    Write-Info "This usually happens when:"
    Write-Host "  1. Cursor staged partial changes" -ForegroundColor $cyan
    Write-Host "  2. You edited after Cursor staged" -ForegroundColor $cyan
    Write-Host "  3. The staged version is different from what you see" -ForegroundColor $cyan

    if (-not $Yes) {
        $choice = Read-Host "`nReplace staged version with your current working version? (Y/N)"
        if ($choice -ne 'Y' -and $choice -ne 'y') {
            Write-Yellow "Skipping fix. You might commit the wrong version."
            return $false
        }
    }

    # Fix each file
    Write-Info "`nSyncing staged files with working directory..."
    $fixedCount = 0
    $failedCount = 0

    foreach ($file in $cursorIssues) {
        # Extract filename safely
        $fileName = $file.Substring(3).Trim()
        
        # Remove quotes if present
        if ($fileName.StartsWith('"') -and $fileName.EndsWith('"')) {
            $fileName = $fileName.Substring(1, $fileName.Length - 2)
        }
        
        # FIXED: Use proper quoting for files with spaces/special characters
        # Use -- to handle filenames that start with dash
        git add -- "$fileName" 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Green "Synced: $fileName"
            $fixedCount++
        }
        else {
            Write-Red "Failed: $fileName"
            $failedCount++
        }
    }

    if ($fixedCount -gt 0) {
        Write-Green "Successfully synced $fixedCount file(s)."
    }
    
    if ($failedCount -gt 0) {
        Write-Red "Failed to sync $failedCount file(s). Check file permissions."
    }

    return $true
}

# Show diff preview to understand what's being committed
function Show-DiffPreview {
    $staged = git diff --cached --name-only
    
    if (-not $staged) {
        return
    }
    
    Write-Info "`nDiff preview (what will be committed):"
    
    # Show a brief diff summary, disabling pager to prevent script hanging
    $env:GIT_PAGER = ''
    git diff --cached --stat 2>$null
    
    if (-not $Yes) {
        $viewDiff = Read-Host "`nView full diff? (Y/N)"
        if ($viewDiff -eq 'Y' -or $viewDiff -eq 'y') {
            git diff --cached --no-color 2>$null
        }
    }
}

# Simple commit function
function Do-Commit {
    param([string]$CommitMessage)

    # Check if anything is staged
    $staged = git diff --cached --name-only

    # If nothing staged, check if we should stage all
    if (-not $staged) {
        $unstaged = git status --porcelain | Where-Object { $_ -match '^[ M?RAD]' }

        if ($unstaged) {
            Write-Yellow "No files staged, but you have $($unstaged.Count) unstaged change(s)."

            if (-not $Yes) {
                $choice = Read-Host "Stage all changes and commit? (Y/N)"
                if ($choice -ne 'Y' -and $choice -ne 'y') {
                    Write-Yellow "Commit cancelled"
                    return $false
                }
            }

            git add .
            $staged = git diff --cached --name-only
            Write-Green "All changes staged"
        }
        else {
            Write-Yellow "Nothing to commit"
            return $false
        }
    }

    # Show what will be committed
    Write-Info "`nCommitting $($staged.Count) file(s):"
    $staged | Select-Object -First 5 | ForEach-Object {
        Write-Host "  📦 $_" -ForegroundColor $green
    }
    if ($staged.Count -gt 5) {
        Write-Host "  ... and $($staged.Count - 5) more" -ForegroundColor $green
    }

    # Get commit message
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        Write-Host ""
        $CommitMessage = Read-Host "Enter commit message (Press Enter for default)"

        if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
            
            # Smart default based on file count
            if ($staged.Count -eq 1) {
                $fileName = [System.IO.Path]::GetFileName($staged[0])
                $CommitMessage = "Update: $fileName"
            }
            else {
                $CommitMessage = "Update: $($staged.Count) files"
            }
            
            Write-Info "Using default: $CommitMessage"
        }
    }

    # Show diff preview before committing
    Show-DiffPreview

    # Confirm commit
    if (-not $Yes) {
        Write-Host ""
        $confirm = Read-Host "Commit with message: '$CommitMessage'? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Yellow "Commit cancelled"
            return $false
        }
    }

    # Execute commit
    git commit -m $CommitMessage

    if ($LASTEXITCODE -eq 0) {
        $commitHash = git rev-parse --short HEAD
        Write-Green "`nCommitted! ($commitHash)"
        return $true
    }
    else {
        Write-Red "Commit failed"
        Write-Host "  Run 'git status' to see what went wrong" -ForegroundColor $yellow
        return $false
    }
}

# Push function
function Do-Push {
    Write-Info "Pushing to remote..."

    # Get current branch
    $branch = git branch --show-current
    
    if (-not $branch) {
        Write-Red "Not on any branch (detached HEAD). Cannot push."
        return $false
    }

    # Check if remote exists
    $remote = git remote 2>$null
    if (-not $remote) {
        Write-Red "No remote repository configured."
        Write-Host "  Configure with: git remote add origin <url>" -ForegroundColor $yellow
        return $false
    }

    if (-not $Yes) {
        $choice = Read-Host "Push '$branch' to remote? (Y/N)"
        if ($choice -ne 'Y' -and $choice -ne 'y') {
            Write-Yellow "Push cancelled"
            return $false
        }
    }

    # Try regular push first
    Write-Info "Pushing to $branch..."
    git push

    if ($LASTEXITCODE -eq 0) {
        Write-Green "Pushed successfully!"
        
        # Show if we're ahead
        $upstream = git rev-parse --abbrev-ref "@{upstream}" 2>$null
        if ($upstream) {
            $ahead = git rev-list --count "@{upstream}..HEAD" 2>$null
            if ($ahead -gt 0) {
                Write-Info "You're $ahead commit(s) ahead of $upstream"
            }
        }
        
        return $true
    }
    else {
        Write-Red "Standard push failed"

        # Check if we need to set upstream
        $upstream = git rev-parse --abbrev-ref "@{upstream}" 2>$null
        if (-not $upstream) {
            Write-Yellow "No upstream branch set for $branch."
            
            if (-not $Yes) {
                $setup = Read-Host "Set upstream and push? (Y/N)"
                if ($setup -eq 'Y' -or $setup -eq 'y') {
                    git push --set-upstream origin $branch
                    if ($LASTEXITCODE -eq 0) {
                        Write-Green "Set upstream and pushed successfully!"
                        return $true
                    }
                }
            }
            return $false
        }

        # Try force push if needed
        if (-not $Yes) {
            Write-Yellow "The remote has changes you don't have locally."
            $force = Read-Host "Force push (overwrites remote)? (Y/N)"
            if ($force -eq 'Y' -or $force -eq 'y') {
                git push --force-with-lease
                if ($LASTEXITCODE -eq 0) {
                    Write-Green "Force push successful!"
                    return $true
                }
                else {
                    Write-Red "Force push also failed"
                }
            }
        }
        return $false
    }
}

# ============================================================================
# MAIN PROGRAM
# ============================================================================

try {
    # Check if we're in a git repository
    if (-not (Test-GitRepository)) {
        Write-Red "Not in a git repository."
        Write-Host "  Navigate to a git repository and try again." -ForegroundColor $yellow
        exit 1
    }

    # Show header
    Write-Host ""
    Write-Host "🚀 Cursor Git Fix v4.1" -ForegroundColor Cyan
    Write-Host "Ensures staged code matches your editor" -ForegroundColor Gray
    Write-Host ""

    # Show current git status
    Write-Info "Current status:"
    git status --short

    Write-Host ""

    # STEP 1: Fix Cursor issues (optional)
    if (-not $SkipStagingCheck) {
        $fixResult = Fix-CursorIssues
        if (-not $fixResult -and -not $Yes) {
            $continue = Read-Host "Continue despite staging mismatches? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                Write-Yellow "Exiting due to staging issues"
                exit 1
            }
        }
    }
    else {
        Write-Info "Skipping staging check (SkipStagingCheck flag)"
    }

    # STEP 2: Commit
    Write-Host ""
    $commitResult = Do-Commit -CommitMessage $Message

    # STEP 3: Push if requested
    if ($commitResult -and $Push) {
        Write-Host ""
        Do-Push
    }

    # Show final status
    Write-Host ""
    Write-Info "Done."
}
catch {
    Write-Red "Error: $_"
    Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor $yellow
    exit 1
}
