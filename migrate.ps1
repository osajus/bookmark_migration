Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
$error.clear()
Clear-Host

function Read-Chrome($item, $parent, $EdgeData) {
    <#
    .SYNOPSIS
        Iterates through the Chrome bookmark list and checks against ones in Edge
    .PARAMETER item
        The current item being iterated through during a foreach loop of the $ChromeData.roots.bookmark_bar.children objects
    .PARAMETER parent
        The parent of the current node.  On first call, this will be blank. e.g. ""
    .PARAMETER EdgeData
        The converted Edge bookmark file as a custom object
    .EXAMPLE
        foreach ($item in $ChromeData.roots.bookmark_bar.children){
            Read-Chrome $item "" $EdgeData
        }
    #>

    if ($parent -eq "") { 
        # If we are in the bookmark_bar root, set that
        $currentFolder = $EdgeData.roots.bookmark_bar
    } else {
        # Otherwise, set which child node we are currently on
        $currentFolder = $currentFolder.children | Where-Object { $_.name -eq $parent}
    }

    # Check if it exists in Edge
    if (Get-Edge $item $currentFolder) {
        Write-Host -ForegroundColor Green "$($item.name) exists. Skipping"
    } else {
        Write-host -ForegroundColor Yellow "$($item.name) missing... adding to Edge"
        # Add the bookmark to the EdgeData custom object
        $currentFolder.children += $item
    }
    
    # We've encountered a node with children.  Iterate through those with a recursive call
    if ($item.type -eq 'folder') {
        foreach ($subfolder in $item.children) {
            Read-Chrome $subfolder $item.name $EdgeData
        }
    }
}

function Get-Edge($item, $currentFolder) {
    <#
    .SYNOPSIS
        Checks the Edge bookmark list to see if the item exists
    .PARAMETER item
        The item to be checked
    .PARAMETER currentFolder
        The current node to check inside of
    #>
    if ($item.type -eq 'folder') {
        $exists = $currentFolder.children | Where-Object {$_.name -eq $item.name}
    } else {
        $exists = $currentFolder.children | Where-Object {$_.url -eq $item.url}
    }
    # TODO: Change this to a bool return
    return $exists
}




$defaultChromeFileLocation = Get-Content '%localappdata%\Google\Chrome\User Data\Default\Bookmarks' | ConvertFrom-Json
$defaultEdgeFileLocation = Get-Content '%localappdata%\Microsoft\Edge\User Data\Default\Bookmarks' | ConvertFrom-Json
$defaultToFileLocation = '%localappdata%\Google\Chrome\User Data\Default\Bookmarks'

if(!($ChromeFileLocation = Read-Host -Prompt "Chrome Bookmark Location [$defaultChromeFileLocation]")) { $ChromeFileLocation = $defaultChromeFileLocation}
if(!($EdgeFileLocation = Read-Host -Prompt "Edge Bookmark Location [$defaultEdgeFileLocation]")) { $EdgeFileLocation = $defaultEdgeFileLocation}
if(!($ToFileLocation = Read-Host -Prompt "Final Bookmark Output Location [$defaultToFileLocation]")) { $ToFileLocation = $defaultToFileLocation}

# Convert the JSON bookmark lists into a PS Custom Object
$ChromeData = Get-Content $ChromeFileLocation | ConvertFrom-Json
$EdgeData = Get-Content $EdgeFileLocation | ConvertFrom-Json



# Begin iterating through the Chrome bookmark objects
foreach ($item in $ChromeData.roots.bookmark_bar.children){
    Read-Chrome $item "" $EdgeData
}

# Remove the checksum from the Edge bookmark then convert the PS Custom Object to the JSON file.
$EdgeData.psobject.Properties.Remove('checksum')
try {
    # TODO: add logic to make sure this exists first.
    Move-Item -Path $ToFileLocation -Destination ("$($ToFileLocation)$(Get-Date -Format "MMddyy").bak") -Force
    $EdgeData | ConvertTo-Json -Depth 100 | Set-Content $ToFileLocation
}
catch {
    Write-Host $Error
}
