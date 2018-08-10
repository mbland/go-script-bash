function Find-Bash {
  @(
    , 'bash' # PATH
    , "${ENV:ProgramFiles}/Git/bin/bash" # Git
    , "${ENV:SystemDrive}/msys64/usr/bin/bash" # MSYS2
    , "${ENV:SystemDrive}/cygwin64/bin/bash" # Cygwin
    , "${ENV:LocalppData}/Lxss/bin/bash" # Linux Subsystem
  ) | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } `
    | ForEach-Object { (Get-Command $_).Source } `
    | Select-Object -First 1
}

function Execute-Bash($Bash_Path, $Command, $Arguments) {
  If ([System.IO.Path]::IsPathRooted($Command)) {
    $Command = Resolve-Path -Relative $Command
  }

  $Command = $Command -Replace '\\', '/'

  If($Bash_Path -and (Test-Path "${Bash_Path}")) {
    &"${Bash_Path}" -c "${Command} ${Arguments}"
  } Else {
    Throw [System.IO.FileNotFoundException] 'Could not find bash, perhaps it is not installed'
  }
}

$go_path = $MyInvocation.MyCommand.Path -replace '\.ps1$'

Execute-Bash (Find-Bash) $go_path $args
