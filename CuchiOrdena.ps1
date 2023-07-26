<#
.SYNOPSIS
Este script ordena las fotos y videos de una carpeta y subcarpetas, extrayendo la fecha de toma de la foto o video mediante exiftool.
Si no tiene esos datos, se tomará la fecha de modificación. Si el nombre de la foto comienza por "IMG_" o "VID_", se extraerá la fecha del nombre,
ya que se asume que es una foto de WhatsApp. Luego, renombrará el archivo con el siguiente formato: añomesdiahoraminsegundo_nombrecarpeta_nombreoriginal.

.DESCRIPTION
Este script procesará los archivos de imagen y video en la carpeta especificada y sus subcarpetas. Para usarlo, simplemente ejecute el script
especificando la carpeta de origen con el parámetro -folder. También puede utilizar los parámetros -test y -verbose para ejecutar el script en
modo de prueba y habilitar el modo verbose respectivamente.

.PARAMETER folder
La ruta de la carpeta que contiene las fotos y videos a procesar. Si no se especifica, se utilizará el directorio actual del script.

.SWITCH test
Ejecuta el script en modo de prueba. No se realizarán cambios en los archivos, pero se mostrará la información de depuración.

.SWITCH verbose
Habilita el modo verbose para mostrar información detallada durante la ejecución del script.

.NOTES
Autor: [Tu Nombre]
Versión: 1.0
Fecha: [Fecha]

.EXAMPLE
.\CuchiOrdena.ps1 -folder "C:\Ruta\De\La\Carpeta"
Ejecuta el script para ordenar las fotos y videos en la carpeta "C:\Ruta\De\La\Carpeta" y sus subcarpetas.

.EXAMPLE
.\CuchiOrdena.ps1 -test -verbose
Ejecuta el script en modo de prueba con información detallada (modo verbose) sin realizar cambios en los archivos.

#>



param (
    [Parameter(Position = 0)]
    [string]$folder = [System.IO.Directory]::GetCurrentDirectory(),
    [switch]$test,
    [switch]$enableVerbose    # Parámetro para habilitar el modo verbose
)
# Obtener la fecha correcta de captura de la foto o video
function ObtenerFechaCaptura($rutaArchivo) {

    # Comprobar si el nombre del archivo comienza con "IMG" o "VID"
    $nombreArchivo = (Get-Item $rutaArchivo).Name
    

    # Comprobar si el archivo tiene información EXIF
    $exifOutput = & $exiftoolPath "-DateTimeOriginal" "-FileModifyDate" "-S" $rutaArchivo
    $exifLines = $exifOutput -split "`r?`n"

    if ($exifLines.Length -gt 1) {
        $fechaCaptura = $exifLines[0] -replace '^DateTimeOriginal: '
        $fechaCaptura = [datetime]::ParseExact($fechaCaptura, "yyyy:MM:dd HH:mm:ss", $null)

        if ($test) {
            Write-Host "EXIF OK"
        }
    }
    elseif ($nombreArchivo -match "^(IMG|VID)_\d{8}_\d{6}") {
        $fechaHoraCaptura = $nombreArchivo -replace "_", ""
        $fechaHoraCaptura = [System.IO.Path]::GetFileNameWithoutExtension($fechaHoraCaptura)
        $fechaHoraCaptura = $fechaHoraCaptura -replace "^(IMG|VID)", ""

  
        if ($test) {
            Write-Host "$fechaHoraCaptura"
        }
        $fechaCaptura = [datetime]::ParseExact($fechaHoraCaptura, "yyyyMMddHHmmss", $null)
    
        if ($test) {
            Write-Host "WHAS OK: $fechaCaptura"
        }
    }
    
    else {
        # Obtener la fecha de modificación si no hay información EXIF
        $fechaCaptura = (Get-Item $rutaArchivo).LastWriteTime.ToString("yyyy:MM:dd HH:mm:ss")
        $fechaCaptura = [datetime]::ParseExact($fechaCaptura, "yyyy:MM:dd HH:mm:ss", $null)

        if ($test) {
            Write-Host "DATE OK"
        }
    }


    return $fechaCaptura
}



# Verificar si ExifTool está en el PATH
$exiftoolPath = "exiftool.exe"

try {
    $null = & $exiftoolPath "--ver"
} catch {
    Write-Host "Error: ExifTool no se encuentra en el PATH. Asegúrate de que ExifTool está instalado y su ruta está configurada correctamente."
     # Instalar exiftool con Winget
     Write-Host "Instalando exiftool con Winget... acepta la instalacion si te pregunta."
     $packageName = "exiftool"
     $wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue
 
     if (-not $wingetInstalled) {
         Write-Host "Winget no está instalado. Por favor, instale Winget antes de ejecutar el script." -ForegroundColor Red
         Exit
     }
 
     Start-Process -Wait winget install $packageName
      # Recargar el PATH en el contexto actual
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

}


# Ejemplo de cómo usar el parámetro -verbose
if ($enableVerbose) {
    Write-Host "Modo verbose habilitado. Se mostrará información detallada durante la ejecución del script."
}

# Crear la carpeta de salida
$carpetaSalida = Join-Path -Path $folder -ChildPath "out"
New-Item -ItemType Directory -Path $carpetaSalida -ErrorAction SilentlyContinue | Out-Null

# Borrar el contenido de la carpeta de salida
Remove-Item -Path $carpetaSalida\* -Force -Recurse -ErrorAction SilentlyContinue

# Procesar la carpeta y subcarpetas
$exclude_folder = Join-Path -Path $folder -ChildPath "out"
$archivos = Get-ChildItem -Path $folder -Recurse -File | Where-Object {
    -not $_.PSIsContainer -and $_.FullName -notlike "$exclude_folder\*" -and $_.Extension -ne ".ps1"
}
$totalArchivos = $archivos.Count
$contador = 0


# Inicializar tabla hash para el resumen
$summary = @{}
$totalMbProcesados = 0


# Procesar la carpeta y subcarpetas
foreach ($archivo in $archivos) {  
    $contador++
    $rutaArchivo = $archivo.FullName
    $nombreArchivo = $archivo.Name
    $carpetaPadre = $archivo.Directory.Name

    # Obtiene la fehca y captura

    $fechaCaptura = ObtenerFechaCaptura $rutaArchivo
    
    
    if ($enableVerbose) {

        Write-Host "Procesando $rutaArchivo"
    }
    
     # Escribir el mensaje en la consola
     $mensaje = "$contador de $totalArchivos : $rutaArchivo : $fechaCaptura"
     Write-Host -NoNewline $mensaje
 
     # Reportar el progreso con Write-Progress
     $progresoActual = [int]($contador * 100 / $totalArchivos)
     if ($progresoActual -gt $progreso) {
         $progreso = $progresoActual
         Write-Progress -Activity "Procesando archivos" -Status "$contador de $totalArchivos archivos procesados $_.FullName" -PercentComplete $progreso
     }

    
    # Renombrar el archivo
    $nombreNuevo = $fechaCaptura.ToString("yyyyMMddHHmmss") + "_" + $carpetaPadre + "_" + $nombreArchivo
    

    # Crear la carpeta del año y del mes si no existen
    $carpetaAnio = Join-Path -Path $carpetaSalida -ChildPath $fechaCaptura.Year.ToString()
    $carpetaMes = Join-Path -Path $carpetaAnio -ChildPath ("{0:D2}" -f $fechaCaptura.Month)

    $nuevoNombreArchivo = Join-Path -Path $carpetaMes -ChildPath $nombreNuevo
    
    if ($test) {
        Write-Host "TEST: Renombrando archivo: $rutaArchivo --> ¨$nuevoNombreArchivo"
    }
    else {
        
         
 
         if (-not (Test-Path -Path $carpetaAnio)) {
             New-Item -ItemType Directory -Path $carpetaAnio | Out-Null
         }
 
         if (-not (Test-Path -Path $carpetaMes)) {
             New-Item -ItemType Directory -Path $carpetaMes | Out-Null
         }
 
        # Copiar archivo a la carpeta del mes y obtener el nuevo nombre
        Copy-Item -Path $rutaArchivo -Destination $nuevoNombreArchivo -Force

         # Formatear la fecha y hora en el formato adecuado (yyyyMMddHHmmss)
         $fechaFormateada = $fechaCaptura.ToString("yyyy:MM:dd HH:mm:ss")


         


         
         # Escribir la fecha correcta de captura en el archivo y obtener la salida de ExifTool
        $exiftoolOutput = & $exiftoolPath  "-DateTimeOriginal=$fechaFormateada" "-FileModifyDate=$fechaFormateada"  $nuevoNombreArchivo -overwrite_original

        # Concatenar la salida de ExifTool con el mensaje y mostrarlo en la consola
        Write-Host  " | $exiftoolOutput"
     
        }

         # Actualizar resumen por extensión y tamaño
    $extension = $archivo.Extension
    $tamanioMb = $archivo.Length / 1MB

    $summary[$extension] += 1
    $summary["$extension-MB"] += $tamanioMb
    $summary["Total-MB"] += $tamanioMb
    $totalMbProcesados += $tamanioMb
}



# Finalizar el progreso al completar el bucle
Write-Progress -Activity "Procesando archivos" -Status "Proceso completo" -Completed

# Imprimir el resumen
Write-Host "Resumen:"
foreach ($key in $summary.Keys) {
    if ($key -like "*-MB" -and $key -ne "Total-MB") {
        $extension = $key -replace "-MB$"
        $totalMb = $summary[$key]
        $totalMbRounded = $totalMb.ToString("N1")

        $totalArchivosPorExtension = $summary[$extension]

        Write-Host "$extension : $totalArchivosPorExtension archivos : $totalMbRounded MB"
    }
}
# Total de archivos procesados
Write-Host "Total de archivos procesados: $totalArchivos"
# Redondear $totalMbProcesados a un decimal
$totalMbProcesados = $totalMbProcesados.ToString("N1")

Write-Host "Total de megabytes procesados: $totalMbProcesados MB"


