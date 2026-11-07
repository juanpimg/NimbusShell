import QtQuick
import org.kde.layershell as LayerShellQt

Window {
    id: root

    property int hoveredIndex: -1

    visible: true
    width: dockCapsule.width + 48
    height: 84
    color: "transparent"
    title: "nimbus-dock"
    LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
    LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorBottom
    LayerShellQt.Window.exclusionZone: 76
    LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
    LayerShellQt.Window.scope: "nimbus-dock"
    LayerShellQt.Window.activateOnShow: false

    // Sombra suave exterior para separar el dock del fondo
    Rectangle {
        anchors.centerIn: dockCapsule
        width: dockCapsule.width + 12
        height: dockCapsule.height + 8
        radius: 26
        color: Qt.rgba(0, 0, 0, 0.28)
        opacity: 0.7
    }

    Rectangle {
        id: dockCapsule

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        height: 66
        width: contentRow.implicitWidth + 28
        radius: 22
        border.color: Qt.rgba(1, 1, 1, 0.26)
        border.width: 1

        // Top specular rim highlight (borde superior biselado de cristal)
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            height: 1
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.6)
        }

        // Inner bottom rim highlight
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 28
            height: 1
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Row {
            id: contentRow

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 10

            // 1. Finder / Archivos
            DockIcon {
                iconName: "finder"
                label: "Finder"
                running: true
                dockIndex: 0
            }

            // 2. Launchpad
            DockIcon {
                iconName: "launchpad"
                label: "Launchpad"
                dockIndex: 1
            }

            // 3. Safari
            DockIcon {
                iconName: "safari"
                label: "Safari"
                dockIndex: 2
            }

            // 4. Mensajes
            DockIcon {
                iconName: "messages"
                label: "Mensajes"
                dockIndex: 3
            }

            // 5. Música
            DockIcon {
                iconName: "music"
                label: "Música"
                dockIndex: 4
            }

            // 6. Editor / Kate
            DockIcon {
                iconName: "editor"
                label: "Editor de texto"
                running: true
                dockIndex: 5
            }

            // 7. Ajustes
            DockIcon {
                iconName: "settings"
                label: "Ajustes del Sistema"
                running: true
                dockIndex: 6
            }

            // 8. Terminal
            DockIcon {
                iconName: "terminal"
                label: "Terminal"
                dockIndex: 7
            }

            // Separador vítreo
            Rectangle {
                width: 1
                height: 42
                anchors.verticalCenter: parent.verticalCenter

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.28)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                }
            }

            // 9. Descargas
            DockIcon {
                iconName: "downloads"
                label: "Descargas"
                dockIndex: 8
            }

            // 10. Papelera
            DockIcon {
                iconName: "trash"
                label: "Papelera"
                dockIndex: 9
            }
        }

        // Tahoe Liquid Glass: degradado vertical multi-stop con refracción óptica
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            GradientStop {
                position: 0.12
                color: Qt.rgba(0.24, 0.28, 0.36, 0.48)
            }

            GradientStop {
                position: 0.65
                color: Qt.rgba(0.12, 0.14, 0.19, 0.68)
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0.08, 0.09, 0.13, 0.82)
            }
        }
    }

    component DockIcon: Item {
        id: iconRoot

        property string iconName: ""
        property string label: ""
        property bool running: false
        property int dockIndex: 0
        readonly property bool isHovered: root.hoveredIndex === dockIndex
        readonly property bool isAdjacent: Math.abs(root.hoveredIndex - dockIndex) === 1
        readonly property real scaleFactor: isHovered ? 1.28 : (isAdjacent ? 1.12 : 1)

        width: 48
        height: 56

        // Reflejo en el suelo de cristal del Dock (estética Tahoe auténtica)
        Item {
            anchors.top: scaleHolder.bottom
            anchors.topMargin: -8
            anchors.horizontalCenter: scaleHolder.horizontalCenter
            width: scaleHolder.width
            height: 18
            opacity: iconRoot.isHovered ? 0.35 : 0.2
            clip: true

            Rectangle {
                anchors.bottom: parent.top
                anchors.bottomMargin: -scaleHolder.height
                anchors.horizontalCenter: parent.horizontalCenter
                width: scaleHolder.width
                height: scaleHolder.height
                radius: 12
                color: iconBackground.color

                transform: Scale {
                    yScale: -1
                    origin.y: scaleHolder.height / 2
                }
            }

            // Gradiente para difuminar el reflejo hacia abajo
            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0.1, 0.12, 0.16, 0.85)
                    }
                }
            }
        }

        // Magnificación suave estilo macOS Tahoe
        Item {
            id: scaleHolder

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            width: 46
            height: 46
            scale: iconRoot.scaleFactor
            transformOrigin: Item.Bottom

            // Fondo del icono estilo macOS squircle continuo (radio 12)
            Rectangle {
                id: iconBackground

                anchors.fill: parent
                radius: 12
                border.color: Qt.rgba(1, 1, 1, 0.28)
                border.width: 1

                // Brillo especular superior del squircle
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 1
                    width: parent.width - 10
                    height: 1
                    radius: 0.5
                    color: Qt.rgba(1, 1, 1, 0.55)
                }

                // Glifo e ilustración vectorial de alta definición Tahoe
                Canvas {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.save();
                        var w = width;
                        var h = height;
                        var cx = w / 2;
                        var cy = h / 2;
                        if (iconName === "finder") {
                            // Cara bicolor de Finder (azul claro / azul oscuro)
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.arc(10, 12, 2.2, 0, Math.PI * 2);
                            ctx.arc(22, 12, 2.2, 0, Math.PI * 2);
                            ctx.fill();
                            // Sonrisa con línea divisoria
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(10, 20);
                            ctx.quadraticCurveTo(cx, 26, 22, 20);
                            ctx.stroke();
                            // Línea nasal central estilo Finder
                            ctx.beginPath();
                            ctx.moveTo(cx, 10);
                            ctx.lineTo(cx, 18);
                            ctx.stroke();
                        } else if (iconName === "launchpad") {
                            // Cohete / Matriz Tahoe de 9 círculos luminosos
                            for (var r = 0; r < 3; ++r) {
                                for (var c = 0; c < 3; ++c) {
                                    ctx.beginPath();
                                    ctx.arc(8 + c * 8, 8 + r * 8, 2.4, 0, Math.PI * 2);
                                    ctx.fillStyle = (r === 1 && c === 1) ? "#FFD60A" : "#FFFFFF";
                                    ctx.fill();
                                }
                            }
                        } else if (iconName === "safari") {
                            // Bisel de brújula
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.7)";
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 12, 0, Math.PI * 2);
                            ctx.stroke();
                            // Aguja roja y blanca
                            ctx.fillStyle = "#FF3B30";
                            ctx.beginPath();
                            ctx.moveTo(cx, cy);
                            ctx.lineTo(cx + 3, cy - 2);
                            ctx.lineTo(cx + 9, cy - 9);
                            ctx.lineTo(cx + 2, cy - 3);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.moveTo(cx, cy);
                            ctx.lineTo(cx - 3, cy + 2);
                            ctx.lineTo(cx - 9, cy + 9);
                            ctx.lineTo(cx - 2, cy + 3);
                            ctx.closePath();
                            ctx.fill();
                        } else if (iconName === "messages") {
                            // Bocadillo de diálogo con cola redondeada
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.ellipse(cx, cy - 1, 11, 8, 0, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.beginPath();
                            ctx.moveTo(10, 22);
                            ctx.lineTo(7, 26);
                            ctx.lineTo(15, 22);
                            ctx.closePath();
                            ctx.fill();
                        } else if (iconName === "music") {
                            // Notas musicales dobles enlazadas
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.arc(10, 22, 3.2, 0, Math.PI * 2);
                            ctx.arc(22, 19, 3.2, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.lineWidth = 2.4;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(13, 22);
                            ctx.lineTo(13, 10);
                            ctx.lineTo(25, 7);
                            ctx.lineTo(25, 19);
                            ctx.stroke();
                        } else if (iconName === "editor") {
                            // Hoja blanca con esquina doblada y líneas de texto
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.roundedRect(8, 6, 16, 20, 2);
                            ctx.fill();
                            ctx.strokeStyle = "#E65C00";
                            ctx.lineWidth = 1.6;
                            ctx.beginPath();
                            ctx.moveTo(11, 12);
                            ctx.lineTo(21, 12);
                            ctx.moveTo(11, 16);
                            ctx.lineTo(21, 16);
                            ctx.moveTo(11, 20);
                            ctx.lineTo(17, 20);
                            ctx.stroke();
                        } else if (iconName === "settings") {
                            // Engranaje metálico concéntrico
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.arc(cx, cy, 6, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.lineWidth = 3.2;
                            ctx.lineCap = "round";
                            for (var i = 0; i < 6; ++i) {
                                var ang = i * Math.PI / 3;
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(ang) * 7, cy + Math.sin(ang) * 7);
                                ctx.lineTo(cx + Math.cos(ang) * 11, cy + Math.sin(ang) * 11);
                                ctx.stroke();
                            }
                            ctx.fillStyle = "#636366";
                            ctx.beginPath();
                            ctx.arc(cx, cy, 3, 0, Math.PI * 2);
                            ctx.fill();
                        } else if (iconName === "terminal") {
                            // Prompt >_ en verde neón sobre ventana oscura
                            ctx.strokeStyle = "#30D158";
                            ctx.lineWidth = 2.4;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            ctx.moveTo(9, 11);
                            ctx.lineTo(15, 16);
                            ctx.lineTo(9, 21);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(17, 21);
                            ctx.lineTo(23, 21);
                            ctx.stroke();
                        } else if (iconName === "downloads") {
                            // Flecha gruesa hacia bandeja
                            ctx.fillStyle = "#FFFFFF";
                            ctx.beginPath();
                            ctx.moveTo(cx, 20);
                            ctx.lineTo(cx - 6, 14);
                            ctx.lineTo(cx - 2, 14);
                            ctx.lineTo(cx - 2, 8);
                            ctx.lineTo(cx + 2, 8);
                            ctx.lineTo(cx + 2, 14);
                            ctx.lineTo(cx + 6, 14);
                            ctx.closePath();
                            ctx.fill();
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.lineWidth = 2.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(7, 22);
                            ctx.lineTo(7, 25);
                            ctx.lineTo(w - 7, 25);
                            ctx.lineTo(w - 7, 22);
                            ctx.stroke();
                        } else if (iconName === "trash") {
                            // Cubo de basura estriado
                            ctx.strokeStyle = "#FFFFFF";
                            ctx.lineWidth = 1.8;
                            ctx.strokeRect(9, 11, 14, 15);
                            ctx.beginPath();
                            ctx.moveTo(7, 9);
                            ctx.lineTo(25, 9);
                            ctx.moveTo(13, 7);
                            ctx.lineTo(19, 7);
                            ctx.moveTo(13, 14);
                            ctx.lineTo(13, 23);
                            ctx.moveTo(19, 14);
                            ctx.lineTo(19, 23);
                            ctx.stroke();
                        }
                        ctx.restore();
                    }
                }

                // Degradados Tahoe específicos por aplicación
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: {
                            if (iconName === "finder")
                                return "#3AA0FF";

                            if (iconName === "launchpad")
                                return "#7C5CE6";

                            if (iconName === "safari")
                                return "#1E86FF";

                            if (iconName === "messages")
                                return "#4CD964";

                            if (iconName === "music")
                                return "#FF3B56";

                            if (iconName === "editor")
                                return "#FFA028";

                            if (iconName === "settings")
                                return "#A8A8AD";

                            if (iconName === "terminal")
                                return "#2C2C2E";

                            if (iconName === "downloads")
                                return "#0A84FF";

                            if (iconName === "trash")
                                return "#7E7E82";

                            return "#0A84FF";
                        }
                    }

                    GradientStop {
                        position: 1
                        color: {
                            if (iconName === "finder")
                                return "#0B66DA";

                            if (iconName === "launchpad")
                                return "#4A28B0";

                            if (iconName === "safari")
                                return "#0051C6";

                            if (iconName === "messages")
                                return "#28B846";

                            if (iconName === "music")
                                return "#DB1D38";

                            if (iconName === "editor")
                                return "#E65C00";

                            if (iconName === "settings")
                                return "#636366";

                            if (iconName === "terminal")
                                return "#141416";

                            if (iconName === "downloads")
                                return "#0055B8";

                            if (iconName === "trash")
                                return "#48484A";

                            return "#0055B8";
                        }
                    }
                }
            }

            // Indicador de app en ejecución (cápsula blanca resplandeciente debajo)
            Rectangle {
                visible: iconRoot.running
                anchors.top: iconBackground.bottom
                anchors.topMargin: 3
                anchors.horizontalCenter: iconBackground.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: "#FFFFFF"
                opacity: 0.95
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hoveredIndex = iconRoot.dockIndex
            onExited: {
                if (root.hoveredIndex === iconRoot.dockIndex)
                    root.hoveredIndex = -1;
            }
        }
    }
}
