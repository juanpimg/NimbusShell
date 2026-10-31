// F8-T01 — Accesibilidad (pendiente F8-T05): salta al KCM existente.
import QtQuick

NimbusPlaceholder {
    heading: i18n("Accesibilidad")
    explanation: i18n("Aquí podrás activar el zoom de pantalla, el contraste alto y reducir animaciones y transparencias. De momento, este botón abre los ajustes originales.")
    jumpButtons: [
        {
            "label": i18n("Abrir accesibilidad"),
            "target": "kcm_access"
        }
    ]
}
