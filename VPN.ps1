# Função para exibir texto laranja no console
function Write-Orange($text) {
    Write-Host $text -ForegroundColor DarkYellow
}

# 1. Solicitar CPF do usuário
$cpf = Read-Host "Informe o CPF do usuário para configuração da VPN"

# 2. Testar ping IPv4 para tunel.tjpb.jus.br
try {
    $ipv4Address = [System.Net.Dns]::GetHostAddresses("tunel.tjpb.jus.br") |
        Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
        Select-Object -First 1

    if (-not $ipv4Address) {
        Write-Orange "Não foi possível resolver um endereço IPv4 para tunel.tjpb.jus.br"
        exit 1
    }

    Write-Host "Testando ping para $($ipv4Address.IPAddressToString)..."
    $ping = Test-Connection -ComputerName $ipv4Address.IPAddressToString -Count 2 -Quiet

    if (-not $ping) {
        $ipv6Address = [System.Net.Dns]::GetHostAddresses("tunel.tjpb.jus.br") |
            Where-Object { $_.AddressFamily -eq 'InterNetworkV6' } |
            Select-Object -First 1

        if ($ipv6Address) {
            Write-Orange "O computador está respondendo em IPv6 ($($ipv6Address.IPAddressToString)). Por favor, desabilite o IPv6 para que a VPN funcione corretamente."
        } else {
            Write-Orange "Não foi possível pingar tunel.tjpb.jus.br nem em IPv4 nem em IPv6."
        }
        exit 1
    }

    Write-Host "Ping IPv4 bem-sucedido. Continuando..."
}
catch {
    Write-Orange "Erro ao resolver ou pingar tunel.tjpb.jus.br: $_"
    exit 1
}

# 3. Remover arquivos e DLLs relacionados ao FortiClient VPN
Write-Host "Removendo arquivos relacionados ao FortiClient VPN..."

$pathsToRemove = @(
    "$env:ProgramFiles\Fortinet\FortiClient",
    "$env:ProgramFiles(x86)\Fortinet\FortiClient",
    "$env:ProgramFiles\FortiClient",
    "$env:ProgramFiles(x86)\FortiClient",
    "$env:ProgramData\Fortinet",
    "$env:LocalAppData\FortiClient",
    "$env:ProgramData\FortiClient",
    "$env:SystemRoot\System32\drivers\Forti*",
    "$env:SystemRoot\SysWOW64\Forti*"
)

foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removido: $path"
        } catch {
            Write-Host "Falha ao remover: $path"
        }
    }
}

# Remover serviços FortiClient, se existirem
$serviceNames = @("FortiClient Service", "FortiSSLVPNService")
foreach ($serviceName in $serviceNames) {
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $serviceName | Out-Null
            Write-Host "Serviço $serviceName removido."
        } catch {
            Write-Host "Falha ao remover serviço $serviceName."
        }
    }
}

# 4. Baixar instalador FortiClient VPN (.msi)
$Link = "https://pixeldrain.com/api/file/WzG8EYbP"
$installerPath = "$env:TEMP\instalador.msi"

Write-Host "⬇️ Iniciando download do arquivo Pixeldrain..."
Invoke-WebRequest -Uri $Link -OutFile $installerPath -UseBasicParsing

if (Test-Path $installerPath) {
    Write-Host "✅ Download concluído com sucesso: $installerPath"
} else {
    Write-Orange "❌ Falha no download. Verifique o link."
    exit 1
}

# 5. Instalar FortiClient VPN via msiexec
Write-Host "Iniciando instalação do FortiClient VPN via msiexec..."
$installArgs = "/i `"$installerPath`" /quiet /norestart"
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru

if ($process.ExitCode -ne 0) {
    Write-Orange "❌ A instalação do FortiClient falhou com código $($process.ExitCode)."
    exit 1
}

Write-Host "✅ Instalação concluída."

# 6. Configurar a conexão VPN
Write-Host "Configurando a conexão VPN..."

# Remover conexão VPN existente, se houver
if (Get-VpnConnection -Name "VPN-TJPB" -ErrorAction SilentlyContinue) {
    Remove-VpnConnection -Name "VPN-TJPB" -Force -ErrorAction SilentlyContinue
}

try {
    Add-VpnConnection -Name "VPN-TJPB" `
                      -ServerAddress "tunel.tjpb.jus.br" `
                      -TunnelType "Sstp" `
                      -AuthenticationMethod Pap, MSChapv2 `
                      -SplitTunneling $false `
                      -EncryptionLevel Required `
                      -RememberCredential `
                      -Force

    # Salvar o CPF informado em arquivo
    $cpfFile = "$env:ProgramData\VPN-TJPB-CPF.txt"
    Set-Content -Path $cpfFile -Value $cpf

    Write-Host "VPN configurada com sucesso. CPF salvo em $cpfFile"
}
catch {
    Write-Orange "Falha ao configurar a VPN: $_"
    exit 1
}

Write-Host "Script finalizado com sucesso."
