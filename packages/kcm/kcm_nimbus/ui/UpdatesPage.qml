// F8-T01 — Actualizaciones (pendiente F8-T07): salta a Discover si existe.
import QtQuick

NimbusPlaceholder {
    heading: i18n("Actualizaciones")
    explanation: i18n("Aquí verás si tu sistema está al día y podrás programar las actualizaciones. De momento, este botón abre la tienda de aplicaciones.")
    jumpButtons: [
        {
            "label": i18n("Abrir Discover"),
            "target": "app:plasma-discover"
        }
    ]
}
