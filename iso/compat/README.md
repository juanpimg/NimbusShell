# Compatibilidad Boost 1.91 para Calamares (R-CALAMARES-BOOST)

`cachyos-calamares` 3.4.2-4/-next enlazan
`libboost_python314.so.1.91.0`, pero los repos actuales sirven
`boost-libs` 1.92. Sin la lib, Calamares no arranca en el live.

`boost191.tar.gz` contiene las 48 bibliotecas `libboost_*1.91.0`
extraídas del ISO CachyOS `cachyos-desktop-linux-260809.iso`
(Boost Software License 1.0; ver `LICENSE`). Se extraen en
`/usr/share/nimbus/compat/usr/lib` (NO en `/usr/lib`, para no
chocar con pacstrap) y el wrapper `/usr/local/bin/calamares` fija
`LD_LIBRARY_PATH` solo para el instalador.

**Retirar** cuando CachyOS reconstruya `cachyos-calamares` contra
el `boost-libs` vigente (comprobar `ldd /usr/bin/calamares`).
