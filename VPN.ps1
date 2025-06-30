Write-Host "`n=== INSTALAÇÃO E CONFIGURAÇÃO DA VPN - TJPB ===" -ForegroundColor Cyan

$vpnNome = "FortiClient VPN"
$instaladorUrl = "https://links.fortinet.com/forticlient/win/vpnagent"
$instaladorPath = "$env:TEMP\FortiClientVPN.exe"

# Solicita CPF
$cpf = Read-Host "Digite o CPF do usuário (sem pontos ou traços)"

# VPN.conf com CPF
$vpnConf = @"
[sslvpn]
VPNConnectionName=VPN - TJPB
Server=tunel.tjpb.jus.br
Port=20443
Description=VPN - TJPB
PromptUsername=1
PromptPassword=1
AutoConnect=0
UserName=$cpf
"@

# Verifica se o host responde e detecta IPv6
function Verificar-Conexao-VPN {
    Write-Host "`n→ Verificando conectividade com tunel.tjpb.jus.br..." -ForegroundColor Yellow

    try {
        $ips = [System.Net.Dns]::GetHostAddresses("tunel.tjpb.jus.br")
        $ipv6 = $ips | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' }

        if ($ipv6) {
            Write-Host "⚠ O domínio resolve para IPv6: $($ipv6.IPAddressToString)" -ForegroundColor Red
            Write-Host "→ Desabilitando IPv6 para evitar falhas na VPN..." -ForegroundColor Yellow
            Desativar-IPv6
        } else {
            $ipv4 = $ips | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
            Write-Host "✓ Responde via IPv4: $($ipv4.IPAddressToString)" -ForegroundColor Green
        }
    } catch {
        Write-Host "✖ Falha ao resolver o endereço: $_" -ForegroundColor Red
    }
}

function Desativar-IPv6 {
    try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" `
            -Name "DisabledComponents" -PropertyType DWord -Value 0xff -Force | Out-Null

        Write-Host "✓ IPv6 desabilitado com sucesso (efetivo após reinício)." -ForegroundColor Green
        $Global:RequerReinicio = $true
    } catch {
        Write-Host "✖ Erro ao desativar IPv6: $_" -ForegroundColor Red
    }
}

function Remover-FortiClient {
    Write-Host "`n→ Removendo FortiClient existente (se houver)..." -ForegroundColor Yellow

    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($key in $keys) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*FortiClient*"
        } | ForEach-Object {
            Write-Host "→ Desinstalando: $($_.DisplayName)" -ForegroundColor Red
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
}

function Limpar-DLLs {
    Write-Host "`n→ Limpando DLLs do FortiClient..." -ForegroundColor Yellow
    $caminhos = @(
        "$env:ProgramFiles\Fortinet",
        "$env:ProgramFiles(x86)\Fortinet",
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64"
    )

    foreach ($pasta in $caminhos) {
        if (Test-Path $pasta) {
            Get-ChildItem -Path $pasta -Recurse -Include "*forticlient*.dll","*fortinet*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
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

function Instalar-FortiClient {
    Write-Host "`n→ Baixando instalador do FortiClient VPN..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $instaladorUrl -OutFile $instaladorPath -UseBasicParsing
        Write-Host "✓ Download concluído." -ForegroundColor Green

        Write-Host "→ Instalando FortiClient VPN..." -ForegroundColor Cyan
        Start-Process -FilePath $instaladorPath -ArgumentList "/quiet /norestart" -Wait
        Write-Host "✓ Instalação concluída." -ForegroundColor Green
    } catch {
        Write-Host "✖ Falha na instalação: $_" -ForegroundColor Red
    }
}

function Configurar-VPN {
    $destino = "C:\Program Files\Fortinet\FortiClient\vpn.conf"

    if (!(Test-Path -Path (Split-Path $destino))) {
        Write-Host "✖ FortiClient ainda não instalado: $destino" -ForegroundColor Red
        return
    }

    $vpnConf | Set-Content -Path $destino -Encoding UTF8
    Write-Host "`n✓ Perfil VPN configurado com sucesso para CPF: $cpf" -ForegroundColor Green
}

# EXECUÇÃO
Verificar-Conexao-VPN
Remover-FortiClient
Limpar-DLLs
Instalar-FortiClient
Start-Sleep -Seconds 5
Configurar-VPN

Write-Host "`n✅ VPN FortiClient configurada com sucesso." -ForegroundColor Cyan
if ($Global:RequerReinicio) {
    Write-Host "⚠️ Reinicie o computador para aplicar a desativação do IPv6." -ForegroundColor Yellow
}
