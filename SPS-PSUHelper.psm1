Class PSUServer {
    [String] ${RepositoryPath}
    [PSUPS1File] ${Branding}
    [PSUPS1File] ${PublishedFolders}
    PSUServer() {}
    PSUServer([String] ${RepositoryPath}) {
        $this.RepositoryPath = $RepositoryPath
        $this.Branding = [PSUPS1File]::new("$($RepositoryPath)\.universal\Branding.ps1")
        $this.PublishedFolders = [PSUPS1File]::new("$($RepositoryPath)\.universal\PublishedFolders.ps1")
    }
}
Class PSUPS1File {
    [String] ${Path}
    [String] ${Name}
    [Boolean] ${Exists}
    [String] ${Content}
    [Microsoft.PowerShell.Commands.FileHashInfo] ${Hash}
    PSUPS1File(){}
    PSUPS1File([String] ${Path}){
        $this.Path = $Path
        if (Test-Path -Path $Path) {
            $this.Exists = $true
            $this.Name = (Get-Item -Path $Path).BaseName
            $this.Content = Get-Content -Path $Path -Raw
            $this.Hash = Get-FileHash -Path $Path
        }Else{
            $this.Exists = $false
        }
    }
}
Function New-PSUBrandingContent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position = 1)]
        [String] ${Path}
    )
    Try {
        [XML] $PSUServerConfiguration = Get-Content -Path $Path -ErrorAction Stop
    }Catch {
        Throw "Unable to get the content of the file $($Path)"
    }
    $BrandingNode = $PSUServerConfiguration.SelectSingleNode('//Branding')
    if ($BrandingNode) {
        # Build the splat
        [System.Collections.Generic.List[String]] $BrandingPropertiesStrings = @() 
        # Build the splat when the node is not empty
        $BrandingFileName = 'Branding.ps1'
        # Get the Properties
        $BrandingProperties = $BrandingNode | Get-Member -MemberType Property | Where-Object Name -ne '#comment'  | Select-Object -ExpandProperty 'Name'
        ForEach ($Property in $BrandingProperties) {
            $Value = $BrandingNode.$Property
            $String = "    $($Property) = '$($Value)'"
            $BrandingPropertiesStrings.Add($String)
        }
        $Message = "'Loading $($BrandingFileName)'"
        $BrandingContent = @"
Try{
    Write-PSULog -Level 'Debug' -Message $Message -Feature 'Scripts' -Resource 'Initialisation'
}Catch{
    Write-Host $Message
}            
`$BrandingSplat = @{
$($BrandingPropertiesStrings -join "`n")
}
New-PSUBranding @BrandingSplat
"@
        Return $BrandingContent
    }
}
Function New-PSUPublishedFoldersContent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position = 1)]
        [String] ${Path}
    )
    Try {
        [XML] $PSUServerConfiguration = Get-Content -Path $Path -ErrorAction Stop
    }Catch {
        Throw "Unable to get the content of the file $($Path)"
    }
    $PublishedFoldersNode = $PSUServerConfiguration.SelectSingleNode('//PublishedFolders')
    if ($PublishedFoldersNode) {
        $PublishedFoldersFileName = 'PublishedFolders.ps1'
        $Message = "'Loading $($PublishedFoldersFileName)'"
        $PublishedFoldersContent = @"
Try{
    Write-PSULog -Level 'Debug' -Message $Message -Feature 'Scripts' -Resource 'Initialisation'
}Catch{
    Write-Host $Message
}
"@
        $FolderCount = 0
        ForEach ($Folder in $PublishedFoldersNode | Select-Object -ExpandProperty 'Folder') {
            $FolderCount++
            [System.Collections.Generic.List[String]] $ThisFolderSplatList = @()
            $FolderProperties = $Folder | Get-Member -MemberType Property | Select-Object -ExpandProperty 'Name'
            ForEach ($Property in $FolderProperties) {
                $Value = $Folder.$Property
                if ($Value -match 'true|false') {
                    # the value is a boolean
                    $Value = [Boolean]::Parse($Value)
                    $String = "    $($Property) = `$$($Value)"
                }Else{
                    $String = "    $($Property) = '$($Value)'"
                }
                $ThisFolderSplatList.Add($String)
            }
            $ThisFolderContent = @"
`$FolderSplat$FolderCount = @{
$($ThisFolderSplatList -join "`n")
}
New-PSUPublishedFolder @FolderSplat$FolderCount
"@
            $PublishedFoldersContent = @"
$PublishedFoldersContent
$ThisFolderContent
"@
        }
        Return $PublishedFoldersContent
    }
}
Function Publish-PSUServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,Position = 1)]
        [String] ${Path}
    )
    <#
    .SYNOPSIS
    This will deploy the default files to the PSU server Path based on a xml declaration
    
    .DESCRIPTION
    This will deploy the default files to the PSU server Path based on a xml declaration
    
    .PARAMETER Path
    The declaration file path
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    BEGIN {
        Write-Verbose "Begin $($PSCmdlet.MyInvocation.MyCommand)"
        # Find the Powershell universal path
        # Get the powershell Universal Service
        $PSUServiceName = 'PowerShellUniversal'
        Try {
            $PSUService = Get-Service -Name $PSUServiceName -ErrorAction Stop
        }Catch {
            Throw "The service $($PSUServiceName) is not installed"
        }
        $PSUServiceBinaryPath = $PSUService | Select-Object -ExpandProperty 'BinaryPathName'
        # Extract the app settings path
        $PSUBinaryRegex = '^(?<ServerPath>"?.*"?)\s--appsettings\s(?<AppSettingPath>"?.*"?)$'
        $RegexResult = $PSUServiceBinaryPath | Select-String -Pattern $PSUBinaryRegex -AllMatches
        if ($RegexResult) {
            $ServerPath = $RegexResult.Matches.Groups | Where-Object Name -eq 'ServerPath' | Select-Object -ExpandProperty 'Value'
            $AppSettingPath = $RegexResult.Matches.Groups | Where-Object Name -eq 'AppSettingPath' | Select-Object -ExpandProperty 'Value'
            $AppSettingPath = $AppSettingPath -replace '"',''
            $ServerPath = $ServerPath -replace '"',''
        }Else{
            Throw "Unable to extract the app settings and the path from the service binary path"
        }
        
        # Get the content of appsettings.json
        Try {
            $AppSettings = Get-Content -Path $AppSettingPath -Raw -ErrorAction Stop | ConvertFrom-Json
        }Catch{
            Throw "Unable to get the content of the appsettings.json file"
        }
        # extract the repository path
        $RepositoryPathSTR = $AppSettings | Select-Object -ExpandProperty 'Data' | Select-Object -ExpandProperty 'RepositoryPath'
        $RepositoryPath = [System.Environment]::ExpandEnvironmentVariables($RepositoryPathSTR)
        #Read the current configuration
        $CurrentPSUServer = [PSUServer]::new($RepositoryPath) 
    }
    PROCESS {
        Write-Verbose "Process $($PSCmdlet.MyInvocation.MyCommand)"
        # Process the file
        #region Branding
        # Process the branding
        $BrandingContent = New-PSUBrandingContent -Path $Path
        $BrandingFileName = 'Branding.ps1'
        if ($BrandingContent) {
            $CurrentContent = $CurrentPSUServer | Select-Object -ExpandProperty 'Branding'  -ErrorAction Ignore | Select-Object -ExpandProperty 'Content' -ErrorAction Ignore
            if ((-not $CurrentContent) -or ($BrandingContent.Trim() -ne $CurrentContent.trim())) {
                # The Branding is different rewrite the file
                Write-Verbose "Rewriting the file $($BrandingFileName)"
                $BrandingPath = "$($RepositoryPath)\.universal\$($BrandingFileName)"
                $BrandingContent | Set-Content -Path $BrandingPath -Force
            }Else{
                Write-Verbose "The file $($BrandingFileName) do not need to be rewritten"
            }
        }Else{
            Write-Verbose "The Branding content is empty remove the file if exist"
            if ($CurrentPSUServer.Branding.Exists) {
                Remove-Item -Path "$($RepositoryPath)\.universal\$($BrandingFileName)" -Force
            }
        }
        #region Published Folders
        # Process the Published Folders
        $PublishedFoldersContent = New-PSUPublishedFoldersContent -Path $Path
        $PublishedFoldersFileName = 'PublishedFolders.ps1'
        if ($PublishedFoldersContent) {
            $CurrentContent = $CurrentPSUServer | Select-Object -ExpandProperty 'PublishedFolders' -ErrorAction Ignore | Select-Object -ExpandProperty 'Content' -ErrorAction Ignore
            if ((-not $CurrentContent) -or ($PublishedFoldersContent.Trim() -ne $CurrentContent.trim())) {
                # The PublishedFolders is different rewrite the file
                Write-Verbose "Rewriting the file $($PublishedFoldersFileName)"
                $PublishedFoldersPath = "$($RepositoryPath)\.universal\$($PublishedFoldersFileName)"
                $PublishedFoldersContent | Set-Content -Path $PublishedFoldersPath -Force
            }Else{
                Write-Verbose "The file $($PublishedFoldersFileName) do not need to be rewritten"
                if ($CurrentPSUServer.PublishedFolders.Exists) {
                    Remove-Item -Path "$($RepositoryPath)\.universal\$($PublishedFoldersFileName)" -Force
                }
            }
        }
        #endregion Published Folders
    }
    END {
        Write-Verbose "End $($PSCmdlet.MyInvocation.MyCommand)"
    }
}