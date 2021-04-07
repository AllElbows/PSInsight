# Script to build all required properties inside Insight

#Turn on script wide verbose for testing
$VerbosePreference = "continue"

#region Required-Modules
function Test-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                write-host "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}

Test-Module PSInsight
Test-Module Microsoft.PowerShell.SecretManagement
#endregion Required-Modules

#region Variables
$Global:InsightApiKey = Get-Secret -Name 'InsightAPI' -AsPlainText
$JSONpath = "C:\Users\Gary.Smith\OneDrive\Scripts\GitHub\Repositories\PSInsight\Examples"

#Import JSON attributes
$MasterJSON = Get-Content -Raw "$JSONpath\MasterSchemaConfig.json" | ConvertFrom-Json
#endregion Variables

# Schema setup
try {
    $HashArguments = @{
        InsightApiKey = $InsightApiKey
    }
    $InsightObjectSchema = Get-InsightObjectSchema @HashArguments | Where { $_.name -like $MasterJSON.Schema.ObjectSchemaName }
    if (!($InsightObjectSchema)) {
        throw 'Object Schema not found'
        # Write-Verbose 'Object Type not found'
    }
    #Write-Verbose 'Object Schema not found'
}
catch {
    $HashArguments = @{
        Name = $SchemaJSON.ObjectSchemaName
        ObjectSchemaKey = $SchemaJSON.ObjectSchemaKey
        Description = $SchemaJSON.ObjectSchemaDescription
        InsightApiKey = $InsightApiKey
    }
    $InsightObjectSchema = New-InsightObjectSchema @HashArguments
    Write-Verbose 'Object Schema has been created'
}

# Create Workstation Object Type
try {
    $HashArguments = @{
        objectschemaID = $InsightObjectSchema.id
        InsightApiKey = $InsightApiKey
    }
    $WorkstationObjectType = Get-InsightObjectTypes @HashArguments | Where { $_.Name -like $WorkstationJSON.Name }
    if (!($WorkstationObjectType)) {
        throw "$($WorkstationJSON.Name) - Object not found"
        Write-Verbose 'Object Type not found'
    }
}
catch {
    $HashArguments = @{
        Name = $WorkstationJSON.Name
        Description = $WorkstationJSON.Description
        IconID = (Get-InsightIcons -InsightApiKey $InsightApiKey | Where { $_.name -like $WorkstationJSON.Icon }).id
        objectSchemaId = $($InsightObjectSchema.id).ToString()
        InsightApiKey = $InsightApiKey
        }
        If ($WorkstationJSON.inherited) {
            $HashArguments.Add('inherited', $WorkstationJSON.inherited)
        }
        If ($WorkstationJSON.abstractObjectType) {
            $HashArguments.Add('abstractObjectType', $WorkstationJSON.abstractObjectType)
        }

    $WorkstationObjectType = New-InsightObjectTypes @HashArguments
    Write-Verbose 'Object Type has been created'
}

#Get existing Attributes
$HashArguments = @{
    ID = $WorkstationObjectType.id
    InsightApiKey = $InsightApiKey
}
$ExistingWorkstationAttributes = Get-InsightObjectTypeAttributes @HashArguments

#Find missing Attributes
$MissingWorkstationAttributes = $WorkstationJSON.Attributes | Where-Object { $ExistingWorkstationAttributes.name -notcontains $_.name }

# Create any missing attributes
foreach ($Attribute in $MissingWorkstationAttributes) {
    $HashArguments = @{
        Name = $Attribute.name
        Type = $Attribute.Type
        DefaultType = $Attribute.DefaultType
        ParentObjectTypeId = $WorkstationObjectType.id
        InsightApiKey = $InsightApiKey
    }

    New-InsightObjectTypeAttributes @HashArguments
    Write-Verbose "$($Attribute.name): Created"
}

# Create links
<# if ($ZoomRoomJSON.Links) {
    
    foreach ($link in $ZoomRoomJSON.Links) {
        $HashArguments = @{
            Name = $link.name
            Type = $link.Type
            TypeValue = $link.TypeValue
            additionalValue = "SHOW_PROFILE"
            Description = $link.description
            parentObjectTypeId = $ObjectType.id
            InsightApiKey = $InsightApiKey
        }
        # additionalValue = 1 will set the link to type dependency
        New-InsightObjectTypeAttributes @HashArguments
    }
} #>

# Get the full list of attributes from the host again with all properties to be used elsewhere if needed.
$HashArguments = @{
    ID = $WorkstationObjectType.id
    InsightApiKey = $InsightApiKey
}
$ZoomRoomAttributes = Get-InsightObjectTypeAttributes @HashArguments



# Build Children
$HashArguments = @{
    objectschemaID = $InsightObjectSchema.id
    InsightApiKey = $InsightApiKey
}
$existingObjectTypes = Get-InsightObjectTypes @HashArguments

foreach ($child in $ZoomRoomJSON.Children) {
    
    if ($existingObjectTypes.name -notcontains $_.name ) {
        $HashArguments = @{
            name = $child.Name
            description = $child.Description
            parentObjectTypeId = $ZoomRoomObjectType.id
            iconID = (Get-InsightIcons -InsightApiKey $InsightApiKey | Where { $_.name -like $child.Icon }).id
            objectSchemaId = $($InsightObjectSchema.id).ToString()
            InsightApiKey = $InsightApiKey
        }
        $ObjectType = New-InsightObjectTypes @HashArguments

        #build attributes
        foreach ($attribute in $child.Attributes) {
            
                $HashArguments = @{
                    Name = $attribute.name
                    Type = $attribute.Type
                    DefaultType = $attribute.DefaultValue
                    ParentObjectTypeId = $ObjectType.id
                    InsightApiKey = $InsightApiKey
                }
                New-InsightObjectTypeAttributes @HashArguments
            
        }

        if ($child.link) {
            $HashArguments = @{
                Name = $child.link.name
                Type = $child.link.Type
                TypeValue = $ZoomRoomObjectType.id
                additionalValue = "1"
                InsightApiKey = $InsightApiKey
                parentObjectTypeId = $ObjectType.id
            }
            # additionalValue = 1 will set the link to type dependency
            New-InsightObjectTypeAttributes @HashArguments
        }
    }
}

#Turn off verbose after script runs. 
$VerbosePreference = "silentlycontinue"







