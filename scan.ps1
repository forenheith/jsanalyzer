param(
  [string]$Root=".",
  [string]$RulesPath="../config/rules.json",
  [string]$ExcludesPath="../config/excludes.json",
  [ValidateSet("table","json","csv")] [string]$Out="table",
  [string]$CsvPath="./scan.csv"
)

function Load-Json($path){if($path -match '^https?://'){(Invoke-WebRequest -Uri $path -UseBasicParsing).Content|ConvertFrom-Json}else{Get-Content $path -Raw|ConvertFrom-Json}}
function MatchAny($s,$arr){foreach($p in $arr){if($s -imatch $p){return $true}}$false}
function SelectRep($members,$mainPattern,$mainName){
  $rep=$null
  if($mainPattern){$rep=$members|Where-Object{$_ -imatch $mainPattern}|Sort-Object Length|Select-Object -First 1}
  if(-not $rep -and $mainName){$rep=$members|Where-Object{[IO.Path]::GetFileName($_) -ieq $mainName}|Select-Object -First 1}
  if(-not $rep){$rep=$members|Sort-Object {($_ -split '[\\/]').Length},Length|Select-Object -First 1}
  $rep
}

$rules=Load-Json $RulesPath|Sort-Object {[int]($_.priority)} -Descending
$ex=Load-Json $ExcludesPath
$all=Get-ChildItem -Path $Root -File -Recurse -Force -ErrorAction SilentlyContinue|Where-Object{
  $_.FullName -imatch '\.js$' -and -not (MatchAny $_.FullName $ex.dirPatterns) -and -not (MatchAny $_.FullName $ex.filePatterns)
}|Select-Object -ExpandProperty FullName

$used=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$res=New-Object System.Collections.Generic.List[object]

foreach($r in $rules){
  $members=$all|Where-Object{$_ -imatch $r.condition}
  if($members){
    foreach($m in $members){$null=$used.Add($m)}
    $rep=SelectRep $members $r.mainFilePattern $r.mainFileName
    $disp=if($r.mainFileName){$r.mainFileName}else{[IO.Path]::GetFileName($rep)}
    $null=$res.Add([pscustomobject]@{Package=$r.package;Display=$disp;Path=$rep;Count=$members.Count})
  }
}

$left=$all|Where-Object{-not $used.Contains($_)}
$others=$left|ForEach-Object{[pscustomobject]@{Package=[IO.Path]::GetFileName($_);Display=[IO.Path]::GetFileName($_);Path=$_;Count=1}}
$final=$res+$others|Sort-Object Display

switch($Out){
  "table" {$final|Format-Table -AutoSize}
  "json" {$final|ConvertTo-Json -Depth 3}
  "csv" {$final|Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8;Write-Host "Saved to $CsvPath"}
}
