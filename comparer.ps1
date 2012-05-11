$SCRIPT:nativeMethods = Add-Type -PassThru -Name "Win32Api" -MemberDefinition @"
    [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
    public static extern long StrFormatByteSize( long fileSize, System.Text.StringBuilder buffer, int bufferSize );
"@

function Get-HashGroups
{
    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { md5 $_.FullName } | where{ $_.Count -gt 1 }
    $hashGroups |
        select `
            Count,
            @{ Name = "Hash";  Expression = {$_.Name} },
            @{ Name = "Extra"; Expression = {$_.Group[0].Length * ($_.Count - 1)} },
            @{ Name = "Size";  Expression = {Get-FileSize ($_.Group[0].Length * ($_.Count - 1)) } },
            @{ Name = "Files"; Expression = {$_.Group} } |
        sort Extra -Descending
}

function md5( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.MD5]::Create().ComputeHash($stream))
    $stream.Close()
}

function Get-FileSize( [Int64] $length )
{
    $sb = New-Object Text.StringBuilder 16
    $SCRIPT:nativeMethods::StrFormatByteSize( $length, $sb, $sb.Capacity ) | Out-Null
    $sb.ToString()
}

$hashGroups = Get-HashGroups

