Function Get-GitLabProjectCommit
{
[OutputType('GitLab.Project.Commit')]
  [cmdletbinding()]
  param(
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [Parameter(ParameterSetName = 'Id')]
    [string]$Id,

    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    #[Parameter(ParameterSetName='Namespace')]
    [string]$Namespace,

    [Alias('Tag')]
    [string]
    $Branch,

    [datetime]
    $After,

    [datetime]
    $Before,

    [string]
    $Sha
  )

  $Project = $null
  switch ($PSCmdlet.ParameterSetName) {
    'Id'
    {
      # we avoid making the API call when the client provides a project ID
      # $Project = Get-GitLabProject -Id $Id
    }
    'Namespace'
    {
      $Project = Get-GitLabProject -Namespace $Namespace
    }
  }

  $Body = @{}

  switch ($PsBoundParameters.Keys) {
    'Branch'
    {
      $Body.Add('ref_name',$Branch)
    }
    'After'
    {
      $Body.Add('since',(Get-Date $After -Format s))
    }
    'Before'
    {
      $Body.Add('until',(Get-Date $Before -Format s))
    }
  }

  $Request = @{
    URI    = "/projects/$($Id)/repository/commits"
    Method = 'GET'
    Body   = $Body
  }

  if ($Sha) {
    $Request.URI = "$($Request.URI)/$Sha"
  }

  QueryGitLabAPI -Request $Request -ObjectType 'GitLab.Project.Commit'
}
