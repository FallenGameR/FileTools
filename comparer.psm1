$SCRIPT:nativeMethods = Add-Type -PassThru -Name "Win32Api" -MemberDefinition @"
    [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
    public static extern long StrFormatByteSize( long fileSize, System.Text.StringBuilder buffer, int bufferSize );
"@
$SCRIPT:hashGroups = @()

function md5( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.MD5]::Create().ComputeHash($stream))
    $stream.Close()
}

function hash
{
    function size( [Int64] $length )
    {
        $sb = New-Object Text.StringBuilder 16
        $SCRIPT:nativeMethods::StrFormatByteSize( $length, $sb, $sb.Capacity ) | Out-Null
        $sb.ToString()
    }

    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { md5 $_.FullName } | where{ $_.Count -gt 1 }
    $SCRIPT:hashGroups = $hashGroups |
        select `
            Count,
            @{ Name = "Hash";  Expression = {$_.Name} },
            @{ Name = "Extra"; Expression = {$_.Group[0].Length * ($_.Count - 1)} },
            @{ Name = "Size";  Expression = {size ($_.Group[0].Length * ($_.Count - 1)) } },
            @{ Name = "Files"; Expression = {$_.Group} } |
        sort Extra -Descending
}

function get( [string] $hash )
{
    if( $hash )
    {
        $SCRIPT:hashGroups | where{ $_.Hash -eq $hash }
    }
    else
    {
        $SCRIPT:hashGroups
    }
}

function files( [string] $hash )
{
    get $hash | take Files | take FullName
}

function stat( [string] $folder )
{
    $stat = if( -not $folder ) { pwd } else { $folder }

    $files = ls $stat 2>$null | where{ -not $_.PSIsContainer } 
    
# calculate md5 for each file
# find how many repetitions there are for each file
# output in a table
}

function update
{
    $SCRIPT:hashGroups | foreach{ $_.Files = @($_.Files | where{ Test-Path $_.FullName }) }
    $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $_.Files.Length -gt 1 }
}

<#
start
get
get -files
get <hash>
get <hash> -files
delete ...
update
get
#>
