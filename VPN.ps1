Clear-Host
Write-Host "`n=== INSTALAÇÃO DO FORTICLIENT VPN ===" -ForegroundColor Cyan

$vpnNome = "FortiClient VPN"
$instaladorUrl = "https://links.fortinet.com/forticlient/win/vpnagent"
$instaladorPath = "$env:TEMP\FortiClientVPN.exe"

# Função para desinstalar FortiClient VPN
function Remover-FortiClient {
    Write-Host "`n→ Procurando instalações existentes..." -ForegroundColor Yellow

    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $encontrado = $false
    foreach ($key in $keys) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*FortiClient*"
        } | ForEach-Object {
            $encontrado = $true
            Write-Host "→ Removendo: $($_.DisplayName)" -ForegroundColor Red

            if ($_.UninstallString) {
                $uninstall = $_.UninstallString
                if ($uninstall -match "msiexec") {
                    Start-Process "msiexec.exe" -ArgumentList "/x $($_.PSChildName) /quiet /norestart" -Wait
                } else {
                    Start-Process "cmd.exe" -ArgumentList "/c `"$uninstall /quiet /norestart`"" -Wait
                }
            }
        }
    }

    if (-not $encontrado) {
        Write-Host "✓ Nenhuma instalação do FortiClient foi encontrada." -ForegroundColor Green
    } else {
        Write-Host "✓ Desinstalação concluída." -ForegroundColor Green
    }
}

# Função para apagar DLLs relacionadas ao FortiClient
function Limpar-DLLs {
    Write-Host "`n→ Limpando arquivos .dll do FortiClient..." -ForegroundColor Yellow
    $caminhos = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64",
        "$env:ProgramFiles\Fortinet",
        "$env:ProgramFiles(x86)\Fortinet"
    )

    foreach ($caminho in $caminhos) {
        if (Test-Path $caminho) {
            Get-ChildItem -Path $caminho -Recurse -Include "*forticlient*.dll","*fortinet*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -ErrorAction Stop
                    Write-Host "✓ Removido: $($_.FullName)" -ForegroundColor Green
                } catch {
                    Write-Host "✖ Erro ao remover $($_.FullName): $_" -ForegroundColor Red
                }
            }
        }
    }
}

# Função para baixar e instalar
function Instalar-FortiClient {
    Write-Host "`n→ Baixando instalador do FortiClient VPN..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $instaladorUrl -OutFile $instaladorPath -UseBasicParsing
        Write-Host "✓ Download concluído." -ForegroundColor Green

        Write-Host "→ Instalando FortiClient VPN..." -ForegroundColor Cyan
        Start-Process -FilePath $instaladorPath -ArgumentList "/quiet /norestart" -Wait
        Write-Host "✓ Instalação concluída." -ForegroundColor Green
    } catch {
        Write-Host "✖ Falha no download ou instalação: $_" -ForegroundColor Red
    }
}

# Execução das etapas
Remover-FortiClient
Limpar-DLLs
Instalar-FortiClient

Write-Host "`n✅ Procedimento finalizado." -ForegroundColor Green
