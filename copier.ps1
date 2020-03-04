$GLOBAL:files = @()

function prepare( $destination )
{
    if( -not $destination )
    {
        throw "Destination not defined"
    }

    $GLOBAL:files = ls -Force -Recurse -File | select fullname, length, lastwritetime
    foreach( $file in $GLOBAL:files )
    {
        $destinationFolder = $file.FullName -replace [regex]::escape($pwd), $destination -replace "[^\\]*$"
        $file | Add-Member -MemberType NoteProperty -Name DestinationFolder -Value $destinationFolder -Force
    }
}

function store($file = "copier.csv")
{
    $GLOBAL:files | ConvertTo-Csv > $file
}

function restore($file = "copier.csv")
{
    $GLOBAL:files = Import-Csv $file
}

function copier
{
    $GLOBAL:lastCopiedIndex = -1
    $foldersCreated = @{}

    try
    {
        for( $i=0; $i -lt $GLOBAL:files.length; $i += 1 )
        {
            $percent = ($i + 1) * 100.0 / $GLOBAL:files.length
            $file = $GLOBAL:files[$i]
            Write-Progress -Activity "Copy in progress" -Status "$percent% сomplete:" -PercentComplete $percent

            # Making sure destination folder exists
            $folderAlreadyCreated = ($foldersCreated[$file.DestinationFolder]) -or (Test-Path $file.DestinationFolder)
            if( -not $folderAlreadyCreated )
            {
                mkdir $file.DestinationFolder
            }

            # Copy operation
            copy -Path $file.FullName -Destination $file.DestinationFolder -Force -ea Stop
            $GLOBAL:lastCopiedIndex = $i
        }
    }
    catch
    {
        "Error on copying file: $($GLOBAL:files[$GLOBAL:lastCopiedIndex+1])"
        "Last copied index was: $GLOBAL:lastCopiedIndex"
    }
    finally
    {
        "Sucessfully copied files: $($GLOBAL:lastCopiedIndex+1)"
        $start = $GLOBAL:lastCopiedIndex+1
        $end = $GLOBAL:files.length-1
        if( $start -le $end )
        {   
            $GLOBAL:files = $GLOBAL:files[$start..$end]
        }
        else
        {
            $GLOBAL:files = @()
        }
        "Files left to copy: $($GLOBAL:files.length)"
    }
}

<#

# Copy huge folder to destination
# Performance notes
cd <folder to copy>
prepare E:\archive
store
copier

# In case it was interrupted on error save state
store

# In case it was interrupted on error resume copy
restore
copier

#>

