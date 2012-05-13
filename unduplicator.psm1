$SCRIPT:hashGroups = @()

Add-Type -Language CSharpVersion3 @"
namespace Unduplicator
{
    using System;
    using System.Runtime.InteropServices;

    public static class NativeMethods
    {
        [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
        public static extern long StrFormatByteSize( long fileSize, System.Text.StringBuilder buffer, int bufferSize );
    }
    
    public class HashGroup
    {
        public int Count {get;set;}
        public string Hash {get;set;}
        public ulong Extra {get;set;}
        public string Size {get;set;}
        public object[] Files {get;set;}
    }  

    public class DuplicatedFile
    {
        public ulong Length {get;set;}
        public int Count {get;set;}
        public string Name {get;set;}
    }
}
"@

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
        [Unduplicator.NativeMethods]::StrFormatByteSize( $length, $sb, $sb.Capacity ) | Out-Null
        $sb.ToString()
    }

    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { md5 $_.FullName } | where{ $_.Count -gt 1 }
    if( -not $hashGroups ) { return }

    $SCRIPT:hashGroups = $hashGroups | 
        foreach{
            New-Object Unduplicator.HashGroup -Property @{
                Count = $_.Count
                Hash = $_.Name
                Extra = $_.Group[0].Length * ($_.Count - 1)
                Size = size ($_.Group[0].Length * ($_.Count - 1))
                Files = $_.Group
            }
        } |
        sort Extra -Descending
}

function get( [string] $hash )
{
    if( -not $hash )
    {
        return $SCRIPT:hashGroups
    }

    $limit = -1
    $isLimit = [int]::TryParse( $hash, [ref] $limit )

    if( $isLimit )
    {
        $SCRIPT:hashGroups | select -first $limit
    }
    else
    {
        $SCRIPT:hashGroups | where{ $_.Hash -eq $hash }
    }

# TODO: Check for hash length instead
}

function files( [string] $hash )
{
    get $hash | take Files | take FullName
}

function lsx( [string] $folder )
{
    $folder = if( -not $folder ) { pwd } else { $folder }
    $files = ls $folder 2>$null | where{ -not $_.PSIsContainer } 

    foreach( $file in $files )
    {
        $hash = md5 $file.FullName
        $group = get $hash

        New-Object Unduplicator.DuplicatedFile -Property @{
            Length = $file.Length
            Count = if( $group ) { $group.Files.Length } else { 1 }
            Name = $file.FullName
        }
    }
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
