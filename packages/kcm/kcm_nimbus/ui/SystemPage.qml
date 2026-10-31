// F8-T01 — Sistema (pendiente F8-T06): salta a los KCMs existentes.
import QtQuick

NimbusPlaceholder {
    heading: i18n("Sistema")
    explanation: i18n("Aquí verás tus usuarios, la fecha y hora y el idioma, explicados sin tecnicismos. De momento, estos botones abren los ajustes originales.")
    jumpButtons: [
        { "label": i18n("Usuarios"), "target": "kcm_users" },
        { "label": i18n("Fecha y hora"), "target": "kcm_clock" },
        { "label": i18n("Idioma y región"), "target": "kcm_regionandlang" }
    ]
}
