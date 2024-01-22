#####
#
# Purpose:   Migrates Source bookmarks to Destination that don't already exist
# Includes:
#            Install-Module -Name SqlServer
#            
# Updated:  01/22/2024
#
#####

# Clear any session variables so they don't persist and mess anythig up.  Then clear the terminal
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
$error.clear()
Clear-Host

function Read-Source($item, $parent, $DestinationData) {
    <#
    .SYNOPSIS
        Iterates through the Source bookmark list and checks against ones in Destination
    .PARAMETER item
        The current item being iterated through during a foreach loop of the $SourceData.roots.bookmark_bar.children objects
    .PARAMETER parent
        The parent of the current node.  On first call, this will be blank. e.g. ""
    .PARAMETER DestinationData
        The converted Destination bookmark file as a custom object
    .EXAMPLE
        foreach ($item in $SourceData.roots.bookmark_bar.children){
            Read-Source $item "" $DestinationData
    .OUTPUTS
        null
        }
    #>

    if ($parent -eq "") { 
        # If we are in the bookmark_bar root, set that
        $currentFolder = $DestinationData.roots.bookmark_bar
    } else {
        # Otherwise, set which child node we are currently on
        $currentFolder = $currentFolder.children | Where-Object { $_.name -eq $parent}
    }

    # Check if it exists in Destination path
    if (Get-Destination $item $currentFolder) {
        Write-Host -ForegroundColor Green "$($item.name) exists."
    } else {
        Write-host -ForegroundColor Yellow "$($item.name) missing... adding"
        # Add the bookmark to the DestinationData custom object
        $currentFolder.children += $item
    }
    
    # We've encountered a node with children (AKA Folder).  Iterate through those with a recursive call to this function
    # Pass the item's name so we know the parent node to attach this child to.
    if ($item.type -eq 'folder') {
        foreach ($subfolder in $item.children) {
            Read-Source $subfolder $item.name $DestinationData
        }
    }
    return $null
}

function Get-Destination($item, $currentFolder) {
    <#
    .SYNOPSIS
        Checks the Destination bookmark list to see if the item exists
    .PARAMETER item
        The item to be checked
    .PARAMETER currentFolder
        The current node to check inside of
    .OUTPUTS 
        True or False 
    #>
    if ($item.type -eq 'folder') {
        # Matching folders based on bookmark name
        if ($null -eq ($currentFolder.children | Where-Object {$_.name -eq $item.name})) {
            return $false
        } else {
            return $true
        }
    } else {
        # Matching bookmarks based on the URL
        if ($null -eq ($currentFolder.children | Where-Object {$_.url -eq $item.url})) {
            return $false
        } else {
            return $true
        }
        
    }
    return $exists
}


$defaultSourceFileLocation = "$($ENV:LOCALAPPDATA)\Google\Source\User Data\Default\Bookmarks"
$defaultDestinationFileLocation = "$($ENV:LOCALAPPDATA)\Microsoft\Destination\User Data\Default\Bookmarks"
$defaultWriteFileLocation = $defaultDestinationFileLocation

# Prompt the user for the path's to use.  Provide a default for ease
if(!($SourceFileLocation = Read-Host -Prompt "Source Bookmark Location [$defaultSourceFileLocation]")) { $SourceFileLocation = $defaultSourceFileLocation}
if(!($DestinationFileLocation = Read-Host -Prompt "Destination Bookmark Location [$defaultDestinationFileLocation]")) { $DestinationFileLocation = $defaultDestinationFileLocation}
if(!($WriteFileLocation = Read-Host -Prompt "Final Bookmark Output Location [$defaultWriteFileLocation]")) { $WriteFileLocation = $defaultWriteFileLocation}

if (-not [System.IO.File]::Exists($WriteFileLocation)) {
    # If there is no bookmarks file in the existing location, just copy the source file and we're done
    try {
        Copy-Item -Path $defaultSourceFileLocation -Destination $WriteFileLocation
        Write-Host "Entire file copied.  Done"
    }
    catch {
        Write-Host "Unable to copy file."
    }
    break
} else {
    # Convert the JSON bookmark lists into PS Custom Objects
    try {
        $SourceData = Get-Content $SourceFileLocation | ConvertFrom-Json
    }
    catch {
        Write-Host "Source File cannot be found or opened: " $Error
        break
    }

    try {
        $DestinationData = Get-Content $DestinationFileLocation | ConvertFrom-Json
    }
    catch {
        Write-Host "Destination File cannot be found or opened: " $Error
        break
    }


    # Begin iterating through the Source bookmark objects
    foreach ($item in $SourceData.roots.bookmark_bar.children){
        Read-Source $item "" $DestinationData
    }

    # Remove the checksum from the Destination bookmark then convert the PS Custom Object to the JSON file.
    $DestinationData.psobject.Properties.Remove('checksum')


    # Back up the existing bookmarks folder, if it exists.
    try {
        if ([System.IO.File]::Exists($WriteFileLocation)) {
            Move-Item -Path $WriteFileLocation -Destination ("$($WriteFileLocation)$(Get-Date -Format "MMddyy").bak") -Force
        } 
    }
    catch {
        Write-Host "Cannot write to output file:  " $Error
        break
    }

    # Write the final output to the bookmarks file.
    try {
        $DestinationData | ConvertTo-Json -Depth 100 | Set-Content $WriteFileLocation
    }
    catch {
        Write-Host "Cannot write to output file: " $Error
    }
}
