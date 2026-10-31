// F8-T01 — Red (pendiente F8-T03): salta a los KCMs existentes.
import QtQuick

NimbusPlaceholder {
    heading: i18n("Red")
    explanation: i18n("Aquí verás tu conexión wifi, Bluetooth e impresoras en lenguaje claro. De momento, estos botones abren los ajustes originales.")
    jumpButtons: [
        { "label": i18n("Wifi y red"), "target": "kcm_networkmanagement" },
        { "label": i18n("Bluetooth"), "target": "kcm_bluetooth" }
    ]
}
