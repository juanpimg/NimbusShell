// MediaWidget.qml — F10-T01 Now Playing en Control Center.
// Tile glass con carátula 40px, título/artista y 3 botones (prev/play/next).
// Se oculta sin reproductor (mpris.hasPlayer). Arte propio, sin SF Symbols.
import QtQuick

Rectangle {
    id: root

    visible: mpris.hasPlayer
    width: parent ? parent.width : 284
    height: visible ? 64 : 0
    radius: 10
    color: NimbusTokens.hoverFill(NimbusTokens.dark)
    border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
    border.width: 1
    objectName: "ccMedia"

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            width: 40
            height: 40
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: NimbusTokens.colors(NimbusTokens.dark).bg2
            objectName: "ccArt"

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: mpris.artFile !== "" ? "file://" + mpris.artFile : ""
                visible: mpris.artFile !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 16
                color: NimbusTokens.colors(NimbusTokens.dark).label
                visible: mpris.artFile === ""
            }
        }

        Column {
            width: parent.width - 40 - 3 * 34 - 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: mpris.title
                font.pixelSize: 12
                font.weight: 600
                color: NimbusTokens.colors(NimbusTokens.dark).label
                elide: Text.ElideRight
                width: parent.width
                objectName: "ccMediaTitle"
            }

            Text {
                text: mpris.artist
                font.pixelSize: 11
                color: NimbusTokens.subText(NimbusTokens.dark)
                elide: Text.ElideRight
                width: parent.width
                objectName: "ccMediaArtist"
            }
        }

        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: [
                    {
                        "label": "⏮",
                        "fn": "prev",
                        "name": "ccPrev"
                    },
                    {
                        "label": "⏯",
                        "fn": "play",
                        "name": "ccPlay"
                    },
                    {
                        "label": "⏭",
                        "fn": "next",
                        "name": "ccNext"
                    }
                ]

                delegate: Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: btnArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : btnArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                    border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                    border.width: btnArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                    objectName: modelData.name

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 13
                        color: NimbusTokens.colors(NimbusTokens.dark).label
                    }

                    MouseArea {
                        id: btnArea

                        anchors.fill: parent
                        hoverEnabled: true
                        activeFocusOnTab: true
                        onClicked: {
                            if (modelData.fn === "play")
                                mpris.playPause();
                            else if (modelData.fn === "next")
                                mpris.next();
                            else
                                mpris.previous();
                        }
                        Keys.onReturnPressed: {
                            if (modelData.fn === "play")
                                mpris.playPause();
                            else if (modelData.fn === "next")
                                mpris.next();
                            else
                                mpris.previous();
                        }
                    }
                }
            }
        }
    }
}
