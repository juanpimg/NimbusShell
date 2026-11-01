// main.cpp — nimbus-about F10-T01. Flags: --demo, --shot <png>.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QTimer>
#include <cstdio>

#include "aboutbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-about"));
    app.setOrganizationName(QStringLiteral("nimbus"));
    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &, const QString &m) {
        fprintf(stderr, "nimbus-about[%d]: %s\n", static_cast<int>(t), m.toUtf8().constData());
    });
    bool demo = false;
    QString shotPath;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo"))
            demo = true;
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
    }
    Q_UNUSED(demo);
    AboutBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &w) {
        for (const auto &e : w)
            fprintf(stderr, "nimbus-about: QML-WARN %s\n", e.toString().toUtf8().constData());
    });
    engine.load(QStringLiteral("qrc:/qml/About.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-about: FALLO al cargar qrc:/qml/About.qml\n");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        fprintf(stderr, "nimbus-about: root no es Window\n");
        return 1;
    }
    fprintf(stderr, "nimbus-about: OPEN version=%s\n", backend.version().toUtf8().constData());
    if (!shotPath.isEmpty()) {
        QTimer::singleShot(2500, win, [win, shotPath]() {
            const QImage img = win->grabWindow();
            if (!img.isNull() && img.save(shotPath))
                fprintf(stderr, "nimbus-about: SHOT_OK %s\n", shotPath.toUtf8().constData());
            else
                fprintf(stderr, "nimbus-about: SHOT_FAIL (grab vacío)\n");
        });
    }
    return app.exec();
}
