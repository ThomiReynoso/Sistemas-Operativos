
<#
.SYNOPSIS
Nombre del Script: Ejercicio4.ps1
Trabajo Practico Nro: 1 - Entrega
Integrantes:
    Bermudez, Pablo           | 35337444
    Cyc, Juan Federico        | 36538280
    Reynoso, Thomas Ignacio   | 39332450
    Silvero, Ezequiel         | 36404597
    Torres, Quimey Belen      | 38891324

Script de Powershell que monitorea un directorio donde se crean archivos.txt y actualiza los datos almacenados en otro archivo.csv (donde se encuentra el stock)

.DESCRIPTION
Se monitorea un directorio pasado por parametro y levanta los datos de los archivos Sucursal_XXX.txt en un hash table,
para actualizar los existentes en RegistroStock.csv (que fueron levantados en otro hash table). Ademas se añadiràn los productos
cuyo CodigoProducto se hallen en Sucursal_XXX.txt y NO se encuentre en RegistroStock.csv  a este ultimo archivo mencionado

.EXAMPLE

    pathDirectorioRegistroStock: C:\Users\thomi\Desktop\stock
    pathDirectorioSucursales: C:\Users\thomi\Desktop\suc



Get-Help '.\Ejercicio4.ps1' 
 
.NOTES

    .Se debe tener el archivo RegistroStock.csv creado y cargado con datos previo a ejecutar el script en el directorio pasado por parametro
    .En el directorio de sucursales: 
        .. Si no tiene el archivo Sucursal.txt creado, crearlo (sin renombrarlo), cargarle los datos (con cabecera y registros separados por ';'), y una vez que contenga los productos, renombrar el archivo a "Sucursal_XXX.txt" donde XXX es el nº de sucursal
    
        .. Si copia el archivo Sucursal.txt desde otro directorio (con productos cargados como se menciona anteriormente), solo debe renombrarlo a "Sucursal_XXX.txt"


.INPUTS

.OUTPUTS
#>

Param(
       [Parameter(Mandatory=$true)]                 #C:\Users\thomi\Desktop\stock
        [string] $pathDirectorioRegistroStock,      
                                                    
                                             
                                               
       [Parameter(Mandatory=$true)]
       [string] $pathDirectorioSucursales
                                            #C:\Users\thomi\Desktop\suc
                                           
                                           
      )   

Function global:actualizarStock {

   
    $fechaActual = Get-Date -Format d
    $global:hashSuc.GetEnumerator() | Foreach-Object{
       $aux=[String]$_.Key #Aux contiene la key del hashSuc 
       $linea=$global:hashRegStock.$aux #linea contiene el registro del HashRegStock, que coincide con el codProd del hashSuc 
             
        if($linea -eq $null){ #NO se encontro el prod cargado en Sucursales, en el RegStock
                    
            
            if( $_.Value[1] -ge 0){ #Se carga el nuevo prod al RegistroStock
                Write-Host "Se agrega el producto ( $($_.value[0]) ) con la cantidad ( $(  $_.value[1]) ) al RegistroStock"
                $global:hashRegStock.add($_.Key, @($_.Value[0], $fechaActual, $_.Value[1]))
            }else{
                Write-Host "No se puede agregar el producto ( $($_.value[0]) ) con la cantidad ( $(  $_.value[1]) ) al RegistroStock. La cantidad debe ser positiva "
            }
            
             
        }
             else{ #Se encontro el prod cargado en Sucursales, en el RegStock
                    
                    Write-Host "Actualizar linea ( $($linea) ) con el stock de $($_.value) y codigoProd $($aux)"
            
            #Actualizo stock con la cantidad del arch de Suc y la fecha actual
            $global:hashRegStock[$aux][2] += [int] $_.value[1]
            $global:hashRegStock[$aux][1] = Get-Date -Format d

            if ($global:hashRegStock[$aux][2] -lt 0){
                Write-Host "No puede haber stock negativo en $linea"
                $global:hashRegStock[$aux][2] = [int]0
            }

                   
             }
        
    } #Fin forEach
    Write-Host ( "El hashRegStock actualizado es:" | Out-String )
    Write-Host ( $global:hashRegStock.GetEnumerator() | sort -Property Name | Out-String )
  
} #Fin Function

Function global:insertarEnArchivoRegStock { #Funcion que se encargar de dar el formato correspondiente al hash table e insertar en RegistroStock.csv para actualizar los datos

    $header = @("CodigoProducto,NombreProducto,FechaDeActualizacion,StockTotal")
    $global:hashRegStock.keys |%{
    $header += (@($_) + $global:hashRegStock.$_) -join "," }
    $header  | out-file  "$pathDirectorioRegistroStock\RegistroStock.csv"  #Luego este path sobreescribirá el archivo RegistroStock.csv 
    $imp = import-csv  "$pathDirectorioRegistroStock\RegistroStock.csv"
    

} 

Function global:importarRegStock{
    
    param([string] $dirCSV)

        $csv=Import-Csv -Path "$dirCSV\RegistroStock.csv"  -Delimiter ','
        $global:hashRegStock=@{};
        foreach($line in $csv){
           
         $global:hashRegStock.add( $line.CodigoProducto, @( $line.NombreProducto, $line.FechaDeActualizacion, [int]$line.StockTotal ) ) 
    }

   Write-Host ( $global:hashRegStock.GetEnumerator() | sort -Property Name | Out-String )

}

Function global:importarSucursal{
    
    param([string] $dirTXT)
    
    $txtSuc = Import-Csv $dirTXT -Delimiter ';'
    $global:hashSuc=@{}
    foreach($line in $txtSuc){
        $global:hashSuc.add( [String]$line.CodigoProducto, @($line.NombreProducto, [int]$line.Cantidad) )
    }
    Write-Host ( $global:hashSuc.GetEnumerator() | sort -Property Name | Out-String ) 

}


Function monitorearDirectorio{

    param([string] $dirAMonitorear)

     $fsw = New-Object IO.FileSystemWatcher $dirAMonitorear -Property @{        
     EnableRaisingEvents = $true
     NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
    }
    $onRename = Register-ObjectEvent $fsw Renamed -SourceIdentifier FileRenamed -Action {
         
         $path = $Event.SourceEventArgs.FullPath
         $name = $Event.SourceEventArgs.Name
         $oldName = $Event.SourceEventArgs.OldName
         $changeType = $Event.SourceEventArgs.ChangeType
         $timeStamp = $Event.TimeGenerated
         Write-Host "El archivo '$oldName' fue $changeType a $name a las  $timeStamp en la ubicacion $path"
          
         # Unregister-Event -SourceIdentifier FileRenamed  -> correr cmd para desuscribir el evento fsw     
        
            
           if($changeType -match "Renamed"){ 
     
            importarSucursal "$path" 
            actualizarStock 
            insertarEnArchivoRegStock
           }          
               
    }


}


importarRegStock "$pathDirectorioRegistroStock" #cargo el hash con los productos del regStock

monitorearDirectorio "$pathDirectorioSucursales" #monitoreo el path pasado por param (donde van a estar los sucursal_xxx.txt)
