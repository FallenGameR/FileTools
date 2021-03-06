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
        $item.Files | % FullName | ac $file
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
            $item

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
    $files = ls -Recurse 2>$null | where{ -not $psitem.PSIsContainer }
    $sameLength = $files | group Length | where Count -gt 1 | % Group
    $hashGroups = $sameLength | group { md5 $psitem.FullName } | where Count -gt 1 
    if( -not $hashGroups ) { return }

    $SCRIPT:hashGroups = $hashGroups | 
        foreach{
            $item = New-Object Unduplicator.HashGroup -Property @{ Hash = $psitem.Name; Files = $psitem.Group }
            recalc $item
            $item
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
        $SCRIPT:hashGroups | where Hash -eq $hash
    }
    else
    {
        $limit = [int] $hash
        $SCRIPT:hashGroups | select -first $limit
    }
}

function file
{
# argument could be:
# - hash: return files that belong to hash
# - empty: return duplicate files that belong to current folder
# - folder: return duplicate files that belong to specified path

    function lsx( [string] $folder )
    {
        $folder = if( -not $folder ) { pwd } else { $folder }
        $files = ls -LiteralPath $folder 2>$null         

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
    
    if( $args.Count -eq 0 )
    {
        return lsx (pwd)
    }

    $hash = $args[0]
    if( isHash $hash )
    {
        return get $hash | take Files | take FullName
    }
   
    lsx ($args -join " ")
}

function update( [string] $prefix )
{
#arguments
# empty - update all hash groups
# file path - update hash groups that start with that prefix

    $updateFiles = 
    {
        $originalLength = $psitem.Files.Count
        $psitem.Files = @($psitem.Files | where{ Test-Path $psitem.FullName })
        $updatedLength = $psitem.Files.Count 

        if( $originalLength -ne $updatedLength )
        {
            recalc $psitem
        }
    }

    if( $prefix )
    {
        $SCRIPT:hashGroups | where{ $psitem.Files | where{ $psitem.FullName.StartsWith($prefix) } } | foreach $updateFiles
    }
    else
    {
        $SCRIPT:hashGroups | foreach $updateFiles
    }

    $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $psitem.Files.Length -gt 1 } | sort Extra -Descending
}

function exclude( [string] $hash )
{
#arguments:
# hash - exclude selected hash 
# folder - exclude paths that start with that prefix

    $excludeFiles = 
    {
        $originalLength = $psitem.Files.Count
        $psitem.Files = @($psitem.Files | where{ -not $psitem.FullName.StartsWith($hash) } ) 
        $updatedLength = $psitem.Files.Count 

        if( $originalLength -ne $updatedLength )
        {
            recalc $psitem
        }
    }

    if( isHash $hash )
    {
        $SCRIPT:hashGroups = $SCRIPT:hashGroups | where Hash -ne $hash
    }
    else
    {
        $SCRIPT:hashGroups | foreach $excludeFiles
        $SCRIPT:hashGroups = $SCRIPT:hashGroups | where{ $psitem.Files.Length -gt 1 } | sort Extra -Descending
    }
}

<#

# Calculate file hashes
# On folder with 174Gb in 29k files and 650 folder took 5 minutes
cd <folder to cleanup>
hash 

get
get 5
get <hash>
get <hash> | % files
delete ...

# takes seconds
update <path prefix>
get 5
#>

