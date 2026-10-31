// F8-T01 — Atajos (pendiente F8-T04): salta al editor existente.
import QtQuick

NimbusPlaceholder {
    heading: i18n("Atajos")
    explanation: i18n("Aquí podrás ver tus atajos de teclado con la tecla ⌘ y recuperar los valores de Nimbus con un botón. De momento, este botón abre el editor original.")
    jumpButtons: [
        {
            "label": i18n("Editar atajos"),
            "target": "kcm_keys"
        }
    ]
}
