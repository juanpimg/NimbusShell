#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QUrl>
#include <QFileInfo>
#include <QTimer>
#include <QRegion>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include <KWindowEffects>

int main(int argc, char *argv[])
{
    LayerShellQt::Shell::useLayerShell();
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    QString qmlFile;
    QString wpPath;

    for (int i = 1; i < argc; ++i) {
        const QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == QStringLiteral("--wallpaper") && i + 1 < argc) {
            wpPath = QString::fromLocal8Bit(argv[++i]);
        } else if (arg == QStringLiteral("--qml") && i + 1 < argc) {
            qmlFile = QString::fromLocal8Bit(argv[++i]);
        } else if (!arg.startsWith('-') && wpPath.isEmpty()) {
            wpPath = arg;
        }
    }

    if (!qmlFile.isEmpty()) {
        engine.load(QUrl::fromLocalFile(QFileInfo(qmlFile).absoluteFilePath()));
    } else {
        const QString qml = QString(
            "import QtQuick\n"
            "import org.kde.layershell as LayerShellQt\n"
            "Window {\n"
            "  visible: true\n"
            "  width: Screen.width\n"
            "  height: Screen.height\n"
            "  color: 'black'\n"
            "  LayerShellQt.Window.layer: LayerShellQt.Window.LayerBackground\n"
            "  LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorBottom | LayerShellQt.Window.AnchorLeft | LayerShellQt.Window.AnchorRight\n"
            "  LayerShellQt.Window.exclusionZone: -1\n"
            "  LayerShellQt.Window.scope: 'wallpaper'\n"
            "  Image {\n"
            "    anchors.fill: parent\n"
            "    source: '%1'\n"
            "    fillMode: Image.PreserveAspectCrop\n"
            "  }\n"
            "}\n"
        ).arg(wpPath.startsWith('/') ? "file://" + wpPath : wpPath);
        engine.loadData(qml.toUtf8());
    }

    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    // Activar blur-behind de compositor sobre ventanas de capa superior (e.g. Dock)
    for (auto *obj : engine.rootObjects()) {
        if (auto *win = qobject_cast<QQuickWindow *>(obj)) {
            if (!qmlFile.isEmpty()) {
                const QRegion region(0, 0, win->width(), win->height());
                KWindowEffects::enableBlurBehind(win, true, region);
                win->requestUpdate();
                QTimer::singleShot(500, win, [win, region]() {
                    KWindowEffects::enableBlurBehind(win, true, region);
                    win->requestUpdate();
                });
            }
        }
    }

    return app.exec();
}
