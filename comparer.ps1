function Get-HashGroups
{
    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { if( $_.Length -gt 100Kb ) { git.exe hash-object $_.FullName } else { Get-Md5 $_.FullName } } | where{ $_.Count -gt 1 }
    $hashGroups
}


git cant handle cyrilic letters in paths. try implement sha1 implementation in .net



$hashGroups = Get-HashGroups

$hashGroups | sort {$_.Group[0].Length * $_.Count} -Descending

# take first 10%
$i = $h | foreach {$_.Group[0].Length * $_.Count / 1Mb } | select

# output
$g | foreach {$_.Group.Lenght * $_.Count} -Descending

