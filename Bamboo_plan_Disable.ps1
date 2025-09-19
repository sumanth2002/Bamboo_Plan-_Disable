# Define Bamboo credentials and target projects
$id            = 'admin'
$Password      = 'password'
$projectKeys   = @("PROJECT_KEY1", "PROJECT_KEY2", "PROJECT_KEY3")

# Total counters across all projects
$totalMainEnabled    = 0
$totalMainDisabled   = 0
$totalBranchEnabled  = 0
$totalBranchDisabled = 0

# Base URL and headers
$BambooUrl  = 'https://bamboo.com'
$authHeader = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${id}:${Password}")))"
$headers    = @{ Accept = 'application/json'; Authorization = $authHeader }

foreach ($projectkey in $projectKeys) {
    # Reset per-project counters
    $projectMainPlans      = 0
    $projectMainEnabled    = 0
    $projectMainDisabled   = 0
    $projectBranchPlans    = 0
    $projectBranchEnabled  = 0
    $projectBranchDisabled = 0
    $disableCount          = 0  # Track disables for batching

    Write-Host "`n=== Project $projectkey ==="

    # Fetch all plans in project
    $resp = Invoke-RestMethod -Uri "$BambooUrl/rest/api/latest/project/$projectkey/?expand=plans.plan&max-result=5000" `
               -Method Get -Headers $headers
    $plans = @($resp.plans.plan)
    if (-not $plans) {
        Write-Warning "No plans found for project $projectkey"
        continue
    }

    # Iterate main plans
    foreach ($plan in $plans) {
        $planKey = $plan.key
        $projectMainPlans++
        if ($plan.enabled -eq 'true') {
            $projectMainEnabled++
            Write-Host "$planKey is in Enabled status" -ForegroundColor Red
            Invoke-RestMethod -Uri "$BambooUrl/rest/api/latest/plan/$planKey/enable" -Method Delete -Headers $headers
            Write-Host "$planKey has been Disabled" -ForegroundColor Yellow
            $projectMainDisabled++
            $disableCount++
            if ($disableCount % 50 -eq 0) {
                Write-Host "Sleeping 2 seconds after 50 disables" -ForegroundColor Cyan
                Start-Sleep -Seconds 2
            }
        } else {
            Write-Host "$planKey is already Disabled" -ForegroundColor Green
        }

        # Fetch 
        $branchResp = Invoke-RestMethod -Uri "$BambooUrl/rest/api/latest/plan/$planKey/branch.json?expand=branches.branch&max-results=5000" `
                          -Method Get -Headers $headers
        $branches = @($branchResp.branches.branch)
        foreach ($b in $branches) {
            $branchKey = $b.key
            $projectBranchPlans++
            if ($b.enabled -eq 'true') {
                $projectBranchEnabled++
                Write-Host "  --> $branchKey is in Enabled status" -ForegroundColor Red
                Invoke-RestMethod -Uri "$BambooUrl/rest/api/latest/plan/$branchKey/enable" -Method Delete -Headers $headers
                Write-Host "  --> $branchKey has been Disabled" -ForegroundColor Yellow
                $projectBranchDisabled++
                $disableCount++
                if ($disableCount % 50 -eq 0) {
                    Write-Host "Sleeping 2 seconds after 50 batch"
                    Start-Sleep -Seconds 2
                }
            } else {
                Write-Host "  --> $branchKey is already Disabled" -ForegroundColor Green
            }
        }
    }

    # Per-project summary
    Write-Host "`nSummary for project $projectkey"
    Write-Host "  Main plans total         : $projectMainPlans"
    Write-Host "  Main plans in enabled status       : $projectMainEnabled"
    Write-Host "  Main plans disabled      : $projectMainDisabled"
    Write-Host "  Branch plans total       : $projectBranchPlans"
    Write-Host "  Branch plans enabled     : $projectBranchEnabled"
    Write-Host "  Branch plans disabled    : $projectBranchDisabled"

 
    $totalMainEnabled    += $projectMainEnabled
    $totalMainDisabled   += $projectMainDisabled
    $totalBranchEnabled  += $projectBranchEnabled
    $totalBranchDisabled += $projectBranchDisabled
}

# Final summary
Write-Host "`n=== Overall Summary ===" 
Write-Host "Total main plans in enabled status   : $totalMainEnabled"
Write-Host "Total main plans disabled   : $totalMainDisabled"
Write-Host "Total branch plans enabled  : $totalBranchEnabled"
Write-Host "Total branch plans disabled : $totalBranchDisabled"