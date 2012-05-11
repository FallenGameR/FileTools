function Get-HashGroups
{
    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { md5 $_.FullName } | where{ $_.Count -gt 1 }

    $objectGroups = $hashGroups | foreach -begin {$id = 0} -process `
    {
        New-Object PsObject -Property @{
            Id = $id += 1
            Count = $_.Count
            Extra = $_.Group[0].Length * ($_.Count - 1)
            Files = $_.Group
        } | select Id, Count, Extra, Files
    }
}

function md5( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.MD5]::Create().ComputeHash($stream))
    $stream.Close()
}

filter Get-Objects
{
    $count = $_.Count
    $files = $_.Group
    $extra = $_.Group[0].Length * ($_.Count - 1)
    New-Object PsObject -Property @{
        Id = 0
        Count = $count
        Extra = $extra
        Files = $files
    } | select Id, Count, ExtraMb, Files
}

$hashGroups = Get-HashGroups

$hashGroups | sort {$_.Group[0].Length * $_.Count} -Descending


$hashGroups = Get-HashGroups

$hashGroups | sort {$_.Group[0].Length * $_.Count} -Descending

# take first 10%
$i = $h | foreach {$_.Group[0].Length * $_.Count / 1Mb } | select

# output
$g | foreach {$_.Group.Lenght * $_.Count} -Descending

