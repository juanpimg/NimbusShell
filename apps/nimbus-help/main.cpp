// main.cpp — nimbus-help F11-T06. Flags: --demo, --shot <png>,
// --tab about|guide|shortcuts (inicial). Dos binarios separados
// (nimbus-about + nimbus-help); --tab solo elige pestaña inicial.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QTimer>
#include <cstdio>

#include "helpbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-help"));
    app.setOrganizationName(QStringLiteral("nimbus"));
    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &, const QString &m) {
        fprintf(stderr, "nimbus-help[%d]: %s\n", static_cast<int>(t), m.toUtf8().constData());
    });
    QString shotPath, tab = QStringLiteral("guide");
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo")) {
        } else if (a == QStringLiteral("--shot") && i + 1 < argc) {
            shotPath = QString::fromLocal8Bit(argv[++i]);
        } else if (a == QStringLiteral("--tab") && i + 1 < argc) {
            tab = QString::fromLocal8Bit(argv[++i]);
        }
    }
    if (tab == QStringLiteral("about"))
        tab = QStringLiteral("guide"); // alias: about vive en nimbus-about
    if (tab != QStringLiteral("guide") && tab != QStringLiteral("shortcuts"))
        tab = QStringLiteral("guide");
    HelpBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("initialTab"), tab);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &w) {
        for (const auto &e : w)
            fprintf(stderr, "nimbus-help: QML-WARN %s\n", e.toString().toUtf8().constData());
    });
    engine.load(QStringLiteral("qrc:/qml/Help.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-help: FALLO al cargar qrc:/qml/Help.qml\n");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        fprintf(stderr, "nimbus-help: root no es Window\n");
        return 1;
    }
    fprintf(stderr, "nimbus-help: OPEN tab=%s dir=%s\n", tab.toUtf8().constData(),
            backend.guidePath().toUtf8().constData());
    if (!shotPath.isEmpty()) {
        QTimer::singleShot(2500, win, [win, shotPath]() {
            const QImage img = win->grabWindow();
            if (!img.isNull() && img.save(shotPath))
                fprintf(stderr, "nimbus-help: SHOT_OK %s\n", shotPath.toUtf8().constData());
            else
                fprintf(stderr, "nimbus-help: SHOT_FAIL (grab vacío)\n");
        });
    }
    return app.exec();
}
