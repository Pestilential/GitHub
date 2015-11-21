<#
NOTES:

    Change
        $SharePath, $Domain,
    Add
        Set a default for $PermissionToRemove

#>

## Read and store input

Param (
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    $MatterNumber,

    ## share created on another person's HDD where I store information.
    ## e.g. \\pcname\myname or C:\Temp
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    $SharePath = ("\\pcname\myname"),

    ## Whether it be 'Builtin', the hostname or domain name 'contoso'
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    $Domain = "Domain",

    ## Needs to be exactly like 'BUILTIN\Users' or 'Domain\Username'
    ## I dont know what 'everyone' looks like, but im sure you can figure that out.
    [Parameter(Mandatory=$True)]
    [ValidateNotNull()]
    $PermissionToRemove
)

$Users,$Num = @(),0

## Loop de loop.
Write-Host " 
    Enter the name of each user to be added to $SharePath\$Matternumber
    Press empty enter when done. 
" -ForegroundColor Yellow

DO {
    $Num++
    $Input = Read-Host "Username $Num"
    IF($Input -ne ''){ 
        $Users += $Input 
    }
} UNTIL ($Input -eq '')

## Display entered Usernames
$Users

## Check for Folder and Create the folder on the share if it doesnt exist.
IF(!(Test-Path $SharePath\$Matternumber)){
    $Folder = mkdir $SharePath\$Matternumber
}

## Display the current AcL for the folder.
Get-Acl $Folder

## Get the ACL to read now. and update later.
$AcL = Get-Acl -Path $Folder

## This will find the access and build the exact object.
$ACE = $AcL.Access | Where-Object {$_.IdentityReference -eq $PermissionToRemove}

Write-Host "Removing $PermissionToRemove"
$AcL.RemoveAccessRuleAll($ACE) ## Remove the group located from the above command.

Write-Host "Removing Inhertiance"
$AcL.SetAccessRuleProtection($True, $True) ## Disable security inheritance on $Folder

## Update the ACL for the folder
(Get-Item $Folder).SetAccessControl($AcL)

## Add Users with READ only access
$ColRights = [System.Security.AccessControl.FileSystemRights]::"Read"
$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::"ContainerInherit","ObjectInherit" 
$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
$ObjType = [System.Security.AccessControl.AccessControlType]::Allow

ForEach($User in $Users){
    ## I like to clear these kinds of things just in case there are any errors creating the variable.
    Remove-Variable ObjACE,ObjUser,ObjACL -ErrorAction SilentlyContinue

    $ObjUser = New-Object System.Security.Principal.NTAccount("$Domain\$User")
    $ObjACE = New-Object System.Security.AccessControl.FileSystemAccessRule($ObjUser,$ColRights,$InheritanceFlag,$PropagationFlag,$ObjType)
    
    IF($ObjACE){
        $ObjACL = Get-ACL -Path $Folder
        $ObjACL.AddAccessRule($ObjACE) 
        Write-Host "Adding $Domain\$User with $($ColRights.ToString())"
        (Get-Item $Folder).SetAccessControl($ObjACL)
    } ELSE {
        Write-Host "Could not add $Domain\$User for some reason =/ "
    }
}

Write-Host "`n Folder created and users added" -ForegroundColor Yellow
Read-Host "Enter to close"
