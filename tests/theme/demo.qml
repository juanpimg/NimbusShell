import "../../packages/themes/nimbus-tokens" as Tokens
import QtQuick

// F3-T01 demo: pinta un rect con tokens del singleton (qmldir en ese dir).
// (paleta hoisted en `c`: el qmllint del sistema, era-Qt5, rompe con
//  varias llamadas encadenadas `Tokens.NimbusTokens.colors(...).x` en un
//  mismo fichero; ver docs/plans/evidence/F3-T01.md)
Rectangle {
    property var c: Tokens.NimbusTokens.colors(Tokens.NimbusTokens.dark)

    width: 320
    height: 200
    color: c.bgElevated
    radius: Tokens.NimbusTokens.radii.windowToolbar
    border.color: c.separator

    Text {
        anchors.centerIn: parent
        text: "NimbusTokens demo"
        font.family: Tokens.NimbusTokens.fontFamily
        font.pixelSize: Tokens.NimbusTokens.type.t13.size
        color: c.label
    }

    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: c.accent

        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 16
        }
    }
}
