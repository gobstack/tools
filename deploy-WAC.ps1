<#
.SYNOPSIS
    Este script realiza la instalación o desinstalación de WAC.
     # LICENCIA #
     El Kit de herramientas de implementación de aplicaciones de PowerShell: proporciona un conjunto de funciones para realizar tareas comunes de implementación de aplicaciones en Windows.
     Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
     Este programa es software libre: puede redistribuirlo y / o modificarlo según los términos de la Licencia Pública General Reducida GNU publicada por la Free Software Foundation, ya sea la versión 3 de la Licencia o cualquier versión posterior. Este programa se distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA; incluso sin la garantía implícita de COMERCIABILIDAD o APTITUD PARA UN PROPÓSITO PARTICULAR. Consulte la Licencia pública general GNU para obtener más detalles.
     Debería haber recibido una copia de la Licencia Pública General Reducida GNU junto con este programa. De lo contrario, consulte <http://www.gnu.org/licenses/>.
.DESCRIPTION
    El script se proporciona como una plantilla para realizar una instalación o desinstalación de una(s) aplicación(es).
    El script realiza un tipo de implementación (DeploymentType) "Install" o un tipo de implementación "Uninstall".
    El tipo de implementación de instalación se divide en 3 secciones/fases principales: preinstalación, instalación y posinstalación.
    El script dot-sources (punto de origen) AppDeployToolkitMain.ps1 contiene la lógica y las funciones necesarias para instalar o desinstalar una aplicación.
.PARAMETER DeploymentType
    El tipo de deployment a realizar. por default es: Install. la otra opcion es uninstall
.PARAMETER DeployMode
    Especifica si la instalación debe ejecutarse en modo Interactive (interactivo), o NonInteractive (silencioso o no interactivo). El valor predeterminado es: Interactive. 
    Opciones: Interactive = Muestra diálogos, Silent = Sin diálogos, NonInteractive = Muy silencioso, es decir, sin aplicaciones de bloqueo. El modo No interactivo se establece automáticamente si se detecta que el proceso no es interactivo para el usuario.
.PARAMETER AllowRebootPassThru
    Permite que el código de retorno 3010 (requiere reinicio) se devuelva al proceso principal (por ejemplo, SCCM) si se detecta en una instalación. Si 3010 se devuelve a SCCM, se activará un mensaje de reinicio.
.PARAMETER TerminalServerMode
    Cambios al "modo de instalación del usuario" y de nuevo al "modo de ejecución del usuario" para instalar/desinstalar aplicaciones para servidores de sesión de escritorio remoto/servidores Citrix.
.PARAMETER DisableLogging
    Desactiva el registro (logging) al script. El valor predeterminado es: $false.
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Install" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Install" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Install" -DeployMode "Interactive"
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Uninstall" -DeployMode "NonInteractive"
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Uninstall" -DeployMode "Silent"
.EXAMPLE
    PowerShell.exe .\Deploy-WAC.ps1 -DeploymentType "Uninstall" -DeployMode "Interactive"
.NOTES
    Rangos de códigos de salida del kit de herramientas:
    60000 - 68999: Reservado para códigos de salida integrados (built-in) en Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended para códigos de salida personalizados por el usuario en Deploy-Application.ps1
    70000 - 79999: Recommended para códigos de salida personalizados por el usuario en AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install','Uninstall','Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory=$false)]
    [ValidateSet('Interactive','Silent','NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory=$false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory=$false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory=$false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Establecer la política de ejecución de scripts para este proceso
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = ''
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = 'XX/XX/20XX'
    [string]$appScriptAuthor = 'Gobstack'
    ##*===============================================
    ## Variables: instalar títulos (solo se establece aquí para anular los valores predeterminados establecidos por el kit de herramientas)
    [string]$installName = ''
    [string]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '26/01/2021'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* No modifique la sección anterior
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        ## Muestre el mensaje de bienvenida, cierre el WACcon una cuenta regresiva de 60 segundos antes de cerrar automáticamente
        Show-InstallationWelcome -CloseApps 'SmeDesktop' -CloseAppsCountdown 60

        ## Mostrar mensaje de progreso (con el mensaje predeterminado)
        Show-InstallationProgress

        ## Eliminar cualquier versión existente del Centro de administración de Windows
        Remove-MSIApplications -Name "Windows Admin Center"
   
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        ## Instala WAC
        $MsiPath = Get-ChildItem -Path "$dirFiles" -Include WindowsAdminCenter*.msi -File -Recurse -ErrorAction SilentlyContinue
        If($MsiPath.Exists)
        {
        Write-Log -Message "Found $($MsiPath.FullName), now attempting to install $installTitle."
        Show-InstallationProgress "Installing Windows Admin Center. This may take some time. Please wait..."
        Execute-MSI -Action Install -Path "$MsiPath" -AddParameters "SME_PORT=443 SSL_CERTIFICATE_OPTION=generate"
        }
       
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

    }
    ElseIf ($deploymentType -ieq 'Uninstall')
    {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Muestre el mensaje de bienvenida, cierre el WAC con una cuenta regresiva de 60 segundos antes de cerrar automáticamente
        Show-InstallationWelcome -CloseApps 'SmeDesktop' -CloseAppsCountdown 60

        ## Mostrar mensaje de progreso (con un mensaje para indicar que la aplicación se está desinstalando)
        Show-InstallationProgress -StatusMessage "Gobstack esta desinstalando $installTitle. Espere por favor..."


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Desinstale cualquier versión existente del WAC
        Remove-MSIApplications -Name "Windows Admin Center"

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'


    }
    ElseIf ($deploymentType -ieq 'Repair')
    {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ## Mostrar mensaje de progreso (con el mensaje predeterminado)
        Show-InstallationProgress


        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Llame a la función Exit-Script para realizar las operaciones de limpieza finales
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
