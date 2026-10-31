import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// SessionBar — selector de sesión + teclado/idioma + apagar/reiniciar (F2-T02).
// `sessions`/`keyboards` inyectables para preview; en SDDM real vienen de
// sessionModel / keyboard layouts del daemon.
RowLayout {
    id: root
    property var sessions: []
    property var keyboards: []
    property int sessionIndex: 0
    property int keyboardIndex: 0
    property string textColor: "#FFFFFF"
    property string fontFamily: "Inter"
    signal sessionSelected(int index)
    signal powerRequested(string action)
    spacing: 8

    ComboBox {
        id: sessionBox
        Layout.preferredWidth: 180
        model: root.sessions
        textRole: "name"
        currentIndex: root.sessionIndex
        font.family: root.fontFamily
        font.pixelSize: 13
        onActivated: function (i) {
            root.sessionIndex = i;
            root.sessionSelected(i);
        }
    }
    ComboBox {
        id: kbBox
        Layout.preferredWidth: 110
        model: root.keyboards
        currentIndex: root.keyboardIndex
        font.family: root.fontFamily
        font.pixelSize: 13
        onActivated: function (i) {
            root.keyboardIndex = i;
        }
    }
    Button {
        text: "Reiniciar"
        font.family: root.fontFamily
        font.pixelSize: 13
        flat: true
        onClicked: root.powerRequested("reboot")
    }
    Button {
        text: "Apagar"
        font.family: root.fontFamily
        font.pixelSize: 13
        flat: true
        onClicked: root.powerRequested("poweroff")
    }
}
