// --- Análisis para múltiples secciones (5 regiones del corazón) ---
//run("Movie (FFMPEG)...", "choose=[C:/Users/jandr/OneDrive - Universidad del rosario/Investigación_fisologia_cardiorrespiratoria_C_aspersum/Datos/Videos freq. cardiaca/Videos_masa_freq_premier_pro/Adobe Premiere Pro Auto-Save/Videos_editados_color/Reposo_30_Color_MP4.mp4] first_frame=0 last_frame=-1");
dir = "C:/Users/jandr/OneDrive - Universidad del rosario/Heart_rate_speed_HRV/Datos/Videos freq. cardiaca/Videos_masa_freq_premier_pro/Adobe Premiere Pro Auto-Save/Videos_editados_color";

videoNums = newArray(19, 20, 21, 22, 23, 25, 26, 27,28, 29, 30, 31, 32);

for (i = 0; i < videoNums.length; i++) {
    n = videoNums[i];
    videoPath = dir + "Movimiento_" +  n + "_Color_MP4.mp4";
    print("Procesando video: Movimiento_" + n);
    run("Movie (FFMPEG)...", "open=[" + videoPath + "] first_frame=0 last_frame=-1");
		run("8-bit");
		run("Fire");
		//falta media, remove outliers u otro filtro 
	    nPixels = 0;
        mean = 0;
        min = 0;
        max = 0;
        std = 0;
		// Obtener valores de intensidad del stack
		getRawStatistics(nPixels, mean, min, max, std);

// Definir umbral de intensidad máxima
umbralMean = 30;

// Si la intensidad máxima es menor o igual al umbral, aplica ajustes
if (mean <= 30) {
  run("Window/Level...");
    run("Enhance Contrast", "saturated=0.35");
    setMinAndMax(-3, 140);
    run("Apply LUT", "stack");   }
else {
   print("No se aplica ajuste porque la intensidad máxima es " + mean);
}

// Parámetros de las 5 secciones
nSecciones = 4;
altoRect = 100; // altura de cada región
separacion = 1; // separación entre regiones
inicioY = 16;
inicioX = 96;
anchoRect = 150;
nFrames = nSlices;

// Arreglo para guardar cambios acumulados por sección
cambiosPorSeccion = newArray(nSecciones);
puntosReferencia = newArray(nSecciones);

for (s = 0; s < nSecciones; s++) {
    y = inicioY + s * (altoRect + separacion);
    perfiles = newArray(nFrames * anchoRect);

    // Extraer perfiles para la sección actual
    for (i = 0; i < nFrames; i++) {
        setSlice(i + 1);
        makeRectangle(inicioX, y, anchoRect, altoRect);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename", "rectangulo");
        roiManager("Update");
        
        prof = getProfile(); // promedio vertical
        
        for (j = 0; j < anchoRect; j++) {
            perfiles[i * anchoRect + j] = prof[j];
        }
    }

    // Calcular cambios acumulados por posición X en esta sección
    cambiosAcumulados = newArray(anchoRect);
    for (j = 0; j < anchoRect; j++) {
        cambiosAcumulados[j] = 0;
        for (i = 1; i < nFrames; i++) {
            idx1 = i * anchoRect + j;
            idx0 = (i - 1) * anchoRect + j;
            cambio = abs(perfiles[idx1] - perfiles[idx0]);
            cambiosAcumulados[j] += cambio;
        }
    }

    // Encontrar el máximo cambio acumulado
    maxCambio = -1;
    for (j = 0; j < anchoRect; j++) {
        if (cambiosAcumulados[j] > maxCambio) {
            maxCambio = cambiosAcumulados[j];
        }
    }

    // Buscar primer punto desde la izquierda con cambio ≥ 50% del máximo  uso de umbra 60% para caracol reposo 9 y movimiento 29
    umbralCambio = 0.85 * maxCambio;
    puntoReferencia = 0;
    for (j = 0; j < anchoRect; j++) {
        if (cambiosAcumulados[j] >= umbralCambio) {
            puntoReferencia = j - 1;
            break;
        }
    }

    // Guardar valores de esta sección
    cambiosPorSeccion[s] = maxCambio;
    puntosReferencia[s] = inicioX + puntoReferencia;
}

// --- Buscar la sección con mayor cambio ---
mayorCambioGlobal = -1;
seccionMax = -1;
for (s = 0; s < nSecciones; s++) {
    if (cambiosPorSeccion[s] > mayorCambioGlobal) {
        mayorCambioGlobal = cambiosPorSeccion[s];
        puntoReal = puntosReferencia[s];
        seccionMax = s;
    }
}

print("Sección con mayor cambio: " + seccionMax);
print("Punto real con mayor cambio: " + puntoReal);

// Calcular intensidad promedio desde X=0 hasta puntoReferencia
suma = 0;
cuenta = 0;
for (j = 0; j <= puntoReferencia; j++) {
    for (i = 0; i < nFrames; i++) {
        idx = i * anchoRect + j;
        suma += perfiles[idx];
        cuenta++;
    }
}
intensidadMedia = suma / cuenta;

// Guardar resultados en CSV
savePath = "C:/Users/jandr/OneDrive - Universidad del rosario/Heart_rate_speed_HRV/Datos/Videos freq. cardiaca/Results_optocardiography/curva_contraccion.csv";
File.saveString("PuntoX,IntensidadPromedio\n", savePath);
File.append(puntoReal + "," + intensidadMedia + "\n", savePath);

// Dibujar línea de referencia en el primer frame
setSlice(1);
makeLine(inicioX, 67, puntoReal, 67);
roiManager("Add");
roiManager("Select", roiManager("Count") - 1);
roiManager("Rename", "linea_real");
roiManager("Update");

roiManager("Reset");
// Dibujar línea y óvalo para cada sección


for (s = 0; s < nSecciones; s++) {
    yCentro = inicioY + s * (altoRect + separacion) + altoRect / 2;  // Centro vertical del rectángulo
    puntoX = puntosReferencia[s];

    setSlice(1); // Dibujamos siempre en el primer frame

    if (puntoX - inicioX > 50) {
        // Línea fija de 50 px
        makeLine(inicioX, yCentro, inicioX + 50, yCentro);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename", "linea_horizontal_" + (s+1));
        roiManager("Update");
      
        // Línea vertical de 50 px
        makeLine(inicioX + 25, yCentro + 25, inicioX + 25, yCentro -25);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename",  "linea_vertical_" + (s+1));
        roiManager("Update");

        // Óvalo de tamaño fijo
        makeOval(inicioX, yCentro - 25, 50, 50);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename", "ovalo_" + (s+1));
        roiManager("Update");
        

    } else {
        // Línea hacia puntoX
        makeLine(inicioX, yCentro, puntoX, yCentro);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename", "linea_horizontal_" + (s+1));
        roiManager("Update");
        
         // Línea vertical puntox
        makeLine((puntoX + inicioX) / 2, yCentro + 25, (puntoX + inicioX) / 2, yCentro - 25);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename",  "linea_vertical_" + (s+1));
        roiManager("Update");

        // Óvalo con ancho igual a puntoX - inicioX
        makeOval(inicioX, yCentro - 25, puntoX - inicioX, 50);
        roiManager("Add");
        roiManager("Select", roiManager("Count") - 1);
        roiManager("Rename", "ovalo_" + (s+1));
        roiManager("Update");
    }
}
   roiManager("Select All");
   roiManager("Multi Measure");

// Guardar CSV por cada video
        //savePath = dir + "Movimiento_" + n + "_curva_contraccion" +  ".csv";
        //saveAs("Results", savePath);
        //close(); // Cierra el stack actual antes de seguir al siguiente video
        //roiManager("Reset");
}
        setBatchMode(false);
//Revisar reposo 9 y movimiento 9, movimiento 10, movimiento 22. movimiento 29, movimiento 31