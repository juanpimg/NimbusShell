# Compatibilidad Boost 1.91 para Calamares (R-CALAMARES-BOOST)

`cachyos-calamares` 3.4.2-4 y `-next` 3.4.2-13 enlazan
`libboost_python314.so.1.91.0`, pero los repos actuales sirven
`boost-libs` 1.92. Sin la lib, Calamares no arranca en el live.

`boost191.tar.gz` contiene las 48 bibliotecas `libboost_*1.91.0`
extraídas del ISO CachyOS `cachyos-desktop-linux-260809.iso`
(Boost Software License 1.0; ver `LICENSE`). Se extraen en
`/usr/lib` del airootfs durante `build-iso.sh`; conviven con
las 1.92 por soname versionado y solo las usa Calamares.

**Retirar** cuando CachyOS reconstruya `cachyos-calamares` contra
el `boost-libs` vigente (comprobar `ldd /usr/bin/calamares`).
