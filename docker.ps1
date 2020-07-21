 $dockerPath = "C:\Program Files\docker"
$dockerDURI = "https://master.dockerproject.org/windows/x86_64/dockerd.exe"
$dockerClientURI = "https://master.dockerproject.org/windows/x86_64/docker.exe"

[DscLocalConfigurationManager()]
configuration LCM {
    Settings {
        RebootNodeIfNeeded = $false #$true
        ActionAfterReboot = 'ContinueConfiguration'
    }
}

configuration win10ContainerHost {
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    node localhost {
        WindowsFeature HyperV {
            Ensure = 'Present'
            Name = 'Hyper-V'
        }

        WindowsFeature Containers {
            Ensure = 'Present'
            Name = 'Containers'
        }

        Script DownloadDockerD
        {
            GetScript = 
            {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = ('True' -in (Test-Path "$dockerPath\dockerd.exe"))
                }
            }

            SetScript = 
            {
                

                if (!(Test-Path "$using:dockerPath" -PathType Container)) {
                    New-Item -ItemType Directory -Force -Path "$using:dockerPath"
                }

                Invoke-WebRequest -Uri $using:dockerDURI -OutFile "$using:dockerPath\dockerd.exe"
            }

            TestScript = 
            {
                $Status = ('True' -in (Test-Path "$dockerPath\dockerd.exe"))
                $Status -eq $True
            }
        }

        Script DownloadDockerClient
        {
            GetScript = 
            {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = ('True' -in (Test-Path "$dockerPath\docker.exe"))
                }
            }

            SetScript = 
            {
                

                if (!(Test-Path "$using:dockerPath" -PathType Container)) {
                    New-Item -ItemType Directory -Force -Path "$using:dockerPath"
                }

                Invoke-WebRequest -Uri $using:dockerClientURI -OutFile "$using:dockerPath\docker.exe"
            }

            TestScript = 
            {
                $Status = ('True' -in (Test-Path "$dockerPath\dockerd.exe"))
                $Status -eq $True
            }
        }

        Environment DockerEnv {
            Path = $true
            Name = 'Path'
            Value = "$dockerPath\"
        }

        script EnableDockerService {
            getScript = {
                $result = if (Get-Service -Name Docker -ErrorAction SilentlyContinue) {'Service Present'} else {'Service Absent'}
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = $Result
                }
            }

            SetScript = {
                & "$using:dockerPath\dockerd.exe" --register-service
            }
            TestScript = {
                if (Get-Service -Name Docker -ErrorAction SilentlyContinue) {
                    return $true
                } else {
                    return $false
                }
            }
            DependsOn = '[script]DownloadDockerD'
        }

        service DockerD {
            Name = 'Docker'
            State = 'Running'
            DependsOn = '[Script]EnableDockerService'
        }


    }
}

LCM
Set-DscLocalConfigurationManager -Path .\LCM -Verbose
Win10ContainerHost
Start-DscConfiguration .\Win10ContainerHost -Wait -Verbose -Force 
