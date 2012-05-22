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

function save( [string] $file )
{
    $null | sc $file

    foreach( $item in $SCRIPT:hashGroups )
    {
        $item.Hash | ac $file    
        $item.Files | take FullName | ac $file
        "" | ac $file   
    }
}

function load( [string] $file )
{
    $text = gc $file
    $hash = ""
    $files = @()

    $SCRIPT:hashGroups = foreach( $line in $text )
    {
        if( -not $hash )
        {
            $hash = $line
            continue
        }

        if( (-not $line) -and ($files.Count -gt 1) )
        {
            $item = New-Object Unduplicator.HashGroup -Property @{ Hash = $hash; Files = $files }
            recalc $item 
            $hash = ""
            $files = @()
            continue
        }
      
        if( Test-Path $line )
        { 
            $files += gi $line
        }
    }
}

function recalc( $item )
{
    $files = $item.Files
    $extra = $files[0].Length * ($files.Count - 1)

    $item.Count = $files.Count
    $item.Extra = $extra
    $item.Size = size $extra

    $item
}

function md5( [string] $absolutePath )
{
    $stream = New-Object IO.FileStream ($absolutePath, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    [Convert]::ToBase64String([Security.Cryptography.MD5]::Create().ComputeHash($stream))
    $stream.Close()
}

function size( [Int64] $length )
{
    $sb = New-Object Text.StringBuilder 16
    [Unduplicator.NativeMethods]::StrFormatByteSize( $length, $sb, $sb.Capacity ) | Out-Null
    $sb.ToString()
}

function hash
{
    $files = ls -Recurse 2>$null | where{ -not $_.PSIsContainer }
    $sameLength = $files | group Length | where{ $_.Count -gt 1 } | take Group
    $hashGroups = $sameLength | group { md5 $_.FullName } | where{ $_.Count -gt 1 }
    if( -not $hashGroups ) { return }

    $SCRIPT:hashGroups = $hashGroups | 
        foreach{
            $item = New-Object Unduplicator.HashGroup -Property @{ Hash = $_.Name; Files = $_.Group }
            recalc $item
        } |
        sort Extra -Descending
}

function isHash( [string] $hash )
{
    $hash -and ($hash.Length -eq 24) -and $hash.EndsWith("==")
}

function get( [string] $hash )
{
# argument could be:
# - empty: return all hash groups
# - number: return N hash groups
# - hash: get particular hash group by hash

    if( -not $hash )
    {
        $SCRIPT:hashGroups
    }
    elseif( isHash $hash )
    {
        $SCRIPT:hashGroups | where{ $_.Hash -eq $hash }        
    }
    else
    {
        $limit = [int] $hash
        $SCRIPT:hashGroups | select -first $limit
    }
}

function file( [string] $hash )
{
# argument could be:
# - hash: return files that belong to hash
# - empty: return duplicate files that belong to current folder
# - folder: return duplicate files that belong to specified path

    function lsx( [string] $folder )
    {
        $folder = if( -not $folder ) { pwd } else { $folder }
        $files = ls $folder 2>$null 

        foreach( $file in $files )
        {
            if( -not $file.PSIsContainer )
            {
                $hash = md5 $file.FullName
                $group = get $hash

                New-Object Unduplicator.DuplicatedFile -Property @{
                    Length = $file.Length
                    Count = if( $group ) { $group.Files.Length } else { 1 }
                    Name = $file.FullName
                }
            }
            else
            {
                New-Object Unduplicator.DuplicatedFile -Property @{
                    Length = 0
                    Count = 0
                    Name = $file.FullName
                }
            }
        }
    }

    if( isHash $hash )
    {
        return get $hash | take Files | take FullName
    }
   
    if( -not $hash )
    {
        lsx (pwd)
    }
    else
    {
        lsx $hash
    }    
}

function update( [string] $prefix )
{
#arguments
# empty - update all hash groups
# file path - update hash groups that start with that prefix

    if( $prefix )
    {
        $SCRIPT:hashGroups | where{ $_.Files | where{ $_.FullName.StartsWith($prefix) } } | foreach{ $_.Files = @($_.Files | where{ Test-Path $_.FullName }) }
    }
    else
    {
        $SCRIPT:hashGroups | foreach{ $_.Files = @($_.Files | where{ Test-Path $_.FullName }) }
    }

    $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $_.Files.Length -gt 1 } | sort Extra -Descending
}

function exclude( [string] $hash )
{
#arguments:
# hash - exclude selected hash 
# folder - exclude paths that start with that prefix

    if( isHash $hash )
    {
        $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $_.Hash -ne $hash }
    }
    else
    {
        $SCRIPT:hashGroups | foreach{ $_.Files = @($_.Files | where{ -not $_.FullName.StartsWith($hash) } ) }
        $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $_.Files.Length -gt 1 } | sort Extra -Descending
    }
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

