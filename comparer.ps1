function Get-HashGroups
{
    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { sha1 $_.FullName } | where{ $_.Count -gt 1 }
    $hashGroups
}

function sha1( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.SHA1]::Create().ComputeHash($stream))
    $stream.Close()
}

function md5( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.MD5]::Create().ComputeHash($stream))
    $stream.Close()
}


$hashGroups = Get-HashGroups

$hashGroups | sort {$_.Group[0].Length * $_.Count} -Descending

# take first 10%
$i = $h | foreach {$_.Group[0].Length * $_.Count / 1Mb } | select

# output
$g | foreach {$_.Group.Lenght * $_.Count} -Descending

