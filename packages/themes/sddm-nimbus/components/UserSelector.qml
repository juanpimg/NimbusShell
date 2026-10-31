import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// UserSelector — lista de usuarios (F2-T02). En SDDM real se alimenta de
// userModel (role name/realName/icon); `users` es inyectable para preview.
ColumnLayout {
    id: root
    property var users: []
    property int currentIndex: 0
    property string textColor: "#FFFFFF"
    property string fontFamily: "Inter"
    signal userSelected(int index)
    spacing: 8

    Repeater {
        model: root.users
        delegate: Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: 44
            checkable: true
            checked: index === root.currentIndex
            flat: true
            onClicked: {
                root.currentIndex = index;
                root.userSelected(index);
            }
            contentItem: RowLayout {
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: "#2C2C2E"
                    opacity: 0.85
                    Text {
                        anchors.centerIn: parent
                        text: (modelData.realName || modelData.name || "?").charAt(0).toUpperCase()
                        color: "#FFFFFF"
                        font.family: root.fontFamily
                        font.pixelSize: 15
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.realName || modelData.name || ""
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }
            }
            background: Rectangle {
                radius: 10
                color: parent.checked ? "#0A84FF" : "transparent"
                opacity: parent.checked ? 0.9 : 1
                border.color: "#EBEBF5"
                border.width: parent.checked ? 0 : 1
            }
        }
    }
}
