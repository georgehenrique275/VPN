# Script PowerShell para baixar e instalar FortiClient via GitHub RAW
# Salve como: FortiClient_Download.ps1

# Configuração da URL de download (espaços codificados como %20)
$DownloadURL = "https://raw.githubusercontent.com/georgehenrique275/VPN/main/FortiClient%207.2.4.0972.exe"
$OutputFile = "FortiClient_7.2.4.0972.exe"

Write-Host "=== Download e Instalação do FortiClient ===" -ForegroundColor Green
Write-Host "URL de download: $DownloadURL"
Write-Host "Arquivo de saída: $OutputFile"
Write-Host ""

# Função para baixar arquivo do GitHub
function Download-FromGitHub {
    param(
        [string]$URL,
        [string]$OutputPath
    )
    
    try {
        Write-Host "Iniciando download..." -ForegroundColor Yellow

        # Usar WebClient para download
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("User-Agent", "Mozilla/5.0")

        $WebClient.DownloadFile($URL, $OutputPath)
        $WebClient.Dispose()

        Write-Host "✓ Download concluído!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Erro no download: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Função para instalar FortiClient
function Install-FortiClient {
    param([string]$ExePath)
    
    if (-not (Test-Path $ExePath)) {
        Write-Host "✗ Arquivo não encontrado: $ExePath" -ForegroundColor Red
        return $false
    }
    
    $FileInfo = Get-Item $ExePath
    $FileSizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
    Write-Host "Arquivo: $($FileInfo.Name)"
    Write-Host "Tamanho: $FileSizeMB MB"
    Write-Host ""
    
    try {
        Write-Host "Iniciando instalação do FortiClient..." -ForegroundColor Yellow
        Write-Host "⚠️  A instalação pode solicitar permissões de administrador" -ForegroundColor Cyan
        
        Write-Host "Tentando instalação silenciosa..."
        $Process = Start-Process -FilePath $ExePath -ArgumentList "/VERYSILENT" -Wait -PassThru

        if ($Process.ExitCode -eq 0) {
            Write-Host "✓ FortiClient instalado com sucesso!" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Instalação silenciosa falhou, iniciando instalação normal..." -ForegroundColor Yellow
            Start-Process -FilePath $ExePath
            Write-Host "✓ Instalador do FortiClient iniciado" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "✗ Erro na instalação: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Função para limpeza
function Remove-TempFile {
    param([string]$FilePath)
    
    $Confirm = Read-Host "Deseja remover o arquivo de instalação? (s/n)"
    if ($Confirm -match "^[sS]") {
        try {
            Remove-Item $FilePath -Force
            Write-Host "✓ Arquivo temporário removido" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Não foi possível remover o arquivo: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# EXECUÇÃO PRINCIPAL
Write-Host "1. Baixando FortiClient..."
$DownloadSuccess = Download-FromGitHub -URL $DownloadURL -OutputPath $OutputFile

if ($DownloadSuccess -and (Test-Path $OutputFile)) {
    Write-Host ""
    Write-Host "2. Instalando FortiClient..."
    $InstallSuccess = Install-FortiClient -ExePath $OutputFile

    if ($InstallSuccess) {
        Write-Host ""
        Write-Host "3. Limpeza..."
        Remove-TempFile -FilePath $OutputFile
    }
}
else {
    Write-Host "✗ Falha no download. Verifique a URL ou sua conexão." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Processo concluído ===" -ForegroundColor Green
Read-Host "Pressione Enter para sair"
