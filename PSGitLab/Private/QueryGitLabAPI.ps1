function Get-WebRequestResult {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        $Request
    )

    $Response = Invoke-WebRequest @Request
    if ($Response.StatusCode -eq 429) {
        Write-Host "Rate limit hit, waiting before retrying..."
        Start-Sleep -Seconds 60
        $Response = Invoke-WebRequest @Request
    }

    $Response
}

Function QueryGitLabAPI {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,
                   HelpMessage='A hash table used for splatting against Invoke-WebRequest.',
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        $Request,

        [Parameter(Mandatory=$false,
                   HelpMessage='Provide a datatype for the returing objects.',
                   Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectType,

        [Parameter(Mandatory=$false,
                   HelpMessage='Provide API version to use',
                   Position=2)]
        [ValidateNotNullOrEmpty()]
        [string]$Version = 'v4'
    )

    $GitLabConfig = ImportConfig

    if ($GitLabConfig.APIVersion) { $Version = "v$($GitLabConfig.APIVersion)" }

    $Domain = $GitLabConfig.Domain
    if ( $IsWindows -or ( [version]$PSVersionTable.PSVersion -lt [version]"5.99.0" ) ) {
        $Token = DecryptString -Token $GitLabConfig.Token
    } elseif ( $IsLinux -or $IsMacOS ) {
        $Token = $GitLabConfig.Token
    }
    $Headers = @{
        'PRIVATE-TOKEN'=$Token;
    }

    $Request.Add('Headers',$Headers)
    $Request.URI = "$Domain/api/$Version" + $Request.URI
    $Request.UseBasicParsing = $true

    try {
        #https://docs.microsoft.com/en-us/dotnet/api/system.net.securityprotocoltype?view=netcore-2.0#System_Net_SecurityProtocolType_SystemDefault
        if ($PSVersionTable.PSVersion.Major -lt 6 -and [Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
            Write-Verbose "Enabling TLS 1.2"
            [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
        }
    }
    catch {
        Write-Warning -Message 'Adding TLS 1.2 to supported security protocols was unsuccessful.'
    }

    try  {
        $ProgressPreference = 'SilentlyContinue'
        Write-Verbose "URL: $($Request.URI)"
        $webContent = Get-WebRequestResult $Request
        $totalPages = 0
       if ($webContent.Headers.ContainsKey('X-Total-Pages')) {
            $totalPages = $($webContent.Headers['X-Total-Pages'] | Select-Object -Last 1) -as [int]
            Write-Verbose "$($totalPages - 1) more pages to query..."
        }
        if ($webContent.rawcontentlength -eq 0 ) { break; }

        $Results = $webContent.Content | ConvertFrom-Json
        for ($i=1; $i -lt $totalPages; $i++) {
            $newRequest = $Request.PSObject.Copy()
            if ( $newRequest['URI'] -match '\?') {
                $newRequest.URI = $newRequest.URI + "&page=$($i+1)"
            }
            else {
                $newRequest.URI = $newRequest.URI + "?page=$($i+1)"
            }
            $webContent = Get-WebRequestResult $newRequest
            $Results += $webContent.Content | ConvertFrom-Json
        }
    } catch {
        Write-Host $_.Exception.Message
        $GitLabErrorText = "{0} - {1}" -f $webcontent.statuscode,$webcontent.StatusDescription
        Write-Error -Message $GitLabErrorText
    }
    finally {
        $ProgressPreference = 'Continue'
        Remove-Variable -Name newRequest -ErrorAction SilentlyContinue
        Remove-Variable -Name Token
        Remove-Variable -Name Headers
        Remove-Variable -Name Request
    }

    foreach ($Result in $Results) {
        $Result.pstypenames.insert(0,$ObjectType)
        Write-Output $Result
    }

}
