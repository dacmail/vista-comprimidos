# Vista de Comprimidos

Extensión de Vista Rápida (barra espaciadora en el Finder) que muestra el contenido
de archivos comprimidos: árbol de carpetas, tamaños, fechas y archivos cifrados.

Se compila **sin Xcode**, solo con las Command Line Tools, y usa la `libarchive`
que ya incluye macOS.

## Instalación

Necesitas macOS 13 o posterior. Funciona en Macs con chip Apple y en Macs Intel.

1. Descarga `Vista-de-Comprimidos.zip` desde la [página de descarga](https://dacmail.github.io/vista-comprimidos/) o desde
   [Releases](../../releases/latest) y descomprímelo.
2. Mueve **Vista de Comprimidos.app** a la carpeta **Aplicaciones**. Hazlo antes de
   abrirla.
3. Ábrela con doble clic. macOS avisará de que no puede verificar el desarrollador:
   la app no está firmada con un certificado de Apple. Pulsa **Aceptar** (o
   **Hecho**).
4. Ve a **Ajustes del Sistema → Privacidad y seguridad**. Baja hasta el mensaje sobre
   «Vista de Comprimidos», pulsa **Abrir igualmente** y confirma.
5. Se abrirá una ventana que confirma que la extensión está instalada. Ya puedes
   cerrarla.

Ahora selecciona un comprimido en el Finder y pulsa la **barra espaciadora**.

Si no funciona:

- Comprueba que esté activada en Ajustes del Sistema → General → Ítems de inicio y
  extensiones → Vista Rápida.
- Si sigues sin verla, en lugar de los pasos 3 y 4 puedes ejecutar esto en la
  Terminal y volver a abrir la app:

  ```bash
  xattr -dr com.apple.quarantine "/Applications/Vista de Comprimidos.app"
  ```

## Formatos

ZIP, 7z, RAR (v4 y v5), tar y sus variantes comprimidas (gz, bz2, xz, zst, lz4),
archivos comprimidos sueltos (.gz, .bz2, .xz, .lzma, .zst, .Z), CAB, LHA/LZH, cpio,
xar, ISO, deb, RPM, JAR/WAR, APK, wheel y cómics (CBZ, CBR, CB7).

La lista completa está en [`formats.json`](formats.json).

## Compilar desde el código

Solo hacen falta las Command Line Tools (`xcode-select --install`) y `python3`.

```bash
./build.sh install   # compila, instala en ~/Applications y la registra
./build.sh test      # crea comprimidos de prueba y los lista en la terminal
./build.sh release   # compilación universal + .zip en build/release/
./build.sh           # solo compila en build/
```

La primera vez, abre **Vista de Comprimidos** en `~/Applications`. Comprueba
también que la extensión esté activa en Ajustes del Sistema → General → Ítems
de inicio y extensiones → Vista Rápida.

Para ver el HTML que genera la vista previa sin pasar por Vista Rápida:

```bash
build/archive-list --html /tmp/vista.html archivo.rar && open /tmp/vista.html
```

## Estructura

```
formats.json                 Formatos: extensiones, UTIs y qué motor los lee
Sources/
  CArchive/                  Declaraciones C de libarchive (el SDK no trae las cabeceras)
  Core/
    ArchiveReader.swift      Protocolo ArchiveReader + ReaderRegistry (lista de motores)
    LibarchiveReader.swift   Motor libarchive
    FormatCatalog.swift      Carga formats.json y decide el formato de un archivo
    ListingTree.swift        Lista plana → árbol de carpetas
    HTMLRenderer.swift       Página HTML de la vista previa
    PreviewBuilder.swift     Une todo lo anterior (lo usan la extensión y la CLI)
  Extension/                 La extensión de Vista Rápida
  App/                       App contenedora mínima
  CLI/                       Herramienta de terminal para pruebas
Scripts/gen-plists.py        Genera los Info.plist desde formats.json
Tests/make-fixtures.sh       Crea comprimidos de prueba
```

## Añadir un formato

**Si lo lee libarchive** (la mayoría): añade una entrada a `formats.json` y ejecuta
`./build.sh install`. No hace falta tocar código.

```json
{ "id": "ejemplo", "name": "Ejemplo", "reader": "libarchive",
  "extensions": ["ejm"], "types": ["com.ejemplo.archive"] }
```

- `types`: UTIs que macOS ya conoce para esa extensión. Para averiguarlo:
  `mdls -name kMDItemContentType archivo.ejm`.
- Si el UTI que sale empieza por `dyn.`, macOS no conoce el tipo. En ese caso deja
  `types` vacío y añade `declare` para que la app lo declare:

  ```json
  "declare": { "identifier": "local.archivepreview.ejemplo",
               "description": "Archivo Ejemplo",
               "conformsTo": ["public.archive", "public.data"] }
  ```

**Si hace falta otro motor** (un formato que libarchive no lee):

1. Crea `Sources/Core/MiFormatoReader.swift` con un tipo que cumpla `ArchiveReader`.
   Debe devolver un `ArchiveListing` con las entradas.
2. Añádelo a `ReaderRegistry.all` en `ArchiveReader.swift`.
3. En `formats.json`, pon `"reader": "<su id>"` en los formatos que deba leer.

El árbol, el HTML y la extensión funcionan igual para cualquier motor.

## Limitaciones

- Para responder rápido, lista como máximo 20.000 entradas o 6 segundos. Si llega
  al límite, indica que el listado es parcial.
- Los RAR/7z con **nombres** cifrados no se pueden listar sin contraseña. Si solo
  está cifrado el contenido, sí se listan, marcados con 🔒.
- La firma es local (ad hoc). Funciona en este Mac, pero para pasarla a otro Mac
  habría que recompilarla allí o firmarla con un certificado de desarrollador.
- En ZIP no hay tamaño comprimido por archivo: se muestra el total del comprimido
  frente al total descomprimido.

## Licencia

MIT. Ver [LICENSE](LICENSE).
