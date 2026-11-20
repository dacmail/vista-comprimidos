#!/bin/bash
# Crea comprimidos de prueba en Tests/fixtures con las herramientas de macOS.
# (RAR no se puede crear sin la herramienta comercial `rar`: prueba con un .rar real.)
set -uo pipefail
cd "$(dirname "$0")"

rm -rf fixtures work
mkdir -p fixtures work/src/"Carpeta con acentos ñ"/sub work/src/vacía
cd work
echo "hola" > src/leeme.txt
echo "# Título" > src/"Carpeta con acentos ñ"/notas.md
head -c 200000 /dev/urandom > src/"Carpeta con acentos ñ"/sub/datos.bin
printf 'x%.0s' {1..50000} > src/"Carpeta con acentos ñ"/sub/repetido.txt
ln -s leeme.txt src/enlace.txt
for i in $(seq 1 40); do echo "$i" > src/vacía/../"Carpeta con acentos ñ"/sub/archivo-$i.log; done

F=../fixtures
try() { "$@" >/dev/null 2>&1 || echo "  (omitido: $*)"; }

try zip -qry  $F/prueba.zip src
try zip -qry  -P secreto $F/cifrado.zip src
cp $F/prueba.zip $F/comic.cbz
try tar -cf   $F/prueba.tar src
try tar -czf  $F/prueba.tar.gz src
cp $F/prueba.tar.gz $F/prueba.tgz
try tar -cjf  $F/prueba.tar.bz2 src
try tar -cJf  $F/prueba.tar.xz src
try tar --zstd -cf $F/prueba.tar.zst src
try tar --lz4  -cf $F/prueba.tar.lz4 src
try tar --format 7zip    -cf $F/prueba.7z src
try tar --format cpio    -cf $F/prueba.cpio src
try tar --format xar     -cf $F/prueba.xar src
try tar --format iso9660 -cf $F/prueba.iso src
gzip  -c src/"Carpeta con acentos ñ"/sub/repetido.txt > $F/suelto.txt.gz
bzip2 -c src/"Carpeta con acentos ñ"/sub/repetido.txt > $F/suelto.txt.bz2
: > $F/vacio.zip                             # 0 bytes
head -c 4096 /dev/urandom > $F/roto.zip      # basura con extensión .zip
cd .. && rm -rf work
ls fixtures | wc -l | xargs echo "Comprimidos de prueba:"
