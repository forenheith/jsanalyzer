$groupRules = @(
  [pscustomobject]@{
    Package = 'dhtmlxScheduler'
    Condition = '(?i)[\\/](?:jsplugins[\\/])?dhtmlxScheduler[\\/]|[\\/]dhtmlxscheduler[^\\/]*\.js$'
    MainFileName = 'dhtmlxscheduler.js'
    MainFilePattern = '(?i)[\\/]dhtmlxscheduler\.js$'
  }
)

$allFiles = Get-ChildItem -File -Recurse -Force -ErrorAction SilentlyContinue |
Where-Object {
  $_.FullName -match '\.js$' -and
  $_.FullName -notmatch '[\\/](lang|locale|locales|i18n)[\\/]'
} | Select-Object -ExpandProperty FullName

$used = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
$result = New-Object System.Collections.Generic.List[object]

foreach ($rule in $groupRules) {
  $members = $allFiles | Where-Object { $_ -imatch $rule.Condition }
  if ($members) {
    foreach ($m in $members) { $null = $used.Add($m) }
    $rep = $null
    if ($rule.MainFilePattern) { $rep = $members | Where-Object { $_ -imatch $rule.MainFilePattern } | Sort-Object Length | Select-Object -First 1 }
    if (-not $rep -and $rule.MainFileName) { $rep = $members | Where-Object { [IO.Path]::GetFileName($_) -ieq $rule.MainFileName } | Select-Object -First 1 }
    if (-not $rep) { $rep = $members | Sort-Object { ($_ -split '[\\/]').Length }, Length | Select-Object -First 1 }
    $display = if ($rule.MainFileName) { $rule.MainFileName } else { [IO.Path]::GetFileName($rep) }
    $null = $result.Add([PSCustomObject]@{ Package = $rule.Package; Display = $display; Path = $rep; Count = $members.Count })
  }
}

$left = $allFiles | Where-Object { -not $used.Contains($_) }
$others = $left | ForEach-Object { [PSCustomObject]@{ Package = [IO.Path]::GetFileName($_); Display = [IO.Path]::GetFileName($_); Path = $_; Count = 1 } }
$final = $result + $others
$final | Sort-Object Display | Select-Object Package,Display,Path,Count
