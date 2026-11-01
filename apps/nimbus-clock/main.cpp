// main.cpp — nimbus-clock F10-T01. Flags: --demo, --shot <png>, --tab <mundo|alarmas|crono|temporizador>.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QTimer>
#include <cstdio>

#include "clockbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-clock"));
    app.setOrganizationName(QStringLiteral("nimbus"));
    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &, const QString &m) {
        fprintf(stderr, "nimbus-clock[%d]: %s\n", static_cast<int>(t), m.toUtf8().constData());
    });
    bool demo = !qEnvironmentVariableIsEmpty("NIMBUS_CLOCK_SIM");
    QString shotPath, startTab = QStringLiteral("mundo");
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo"))
            demo = true;
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
        else if (a == QStringLiteral("--tab") && i + 1 < argc)
            startTab = QString::fromLocal8Bit(argv[++i]);
    }
    if (demo)
        qputenv("NIMBUS_CLOCK_SIM", "1");
    ClockBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("startTab"), startTab);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &w) {
        for (const auto &e : w)
            fprintf(stderr, "nimbus-clock: QML-WARN %s\n", e.toString().toUtf8().constData());
    });
    engine.load(QStringLiteral("qrc:/qml/Clock.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-clock: FALLO al cargar qrc:/qml/Clock.qml\n");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        fprintf(stderr, "nimbus-clock: root no es Window\n");
        return 1;
    }
    fprintf(stderr, "nimbus-clock: OPEN tab=%s\n", startTab.toUtf8().constData());
    if (!shotPath.isEmpty()) {
        QTimer::singleShot(2500, win, [win, shotPath]() {
            const QImage img = win->grabWindow();
            if (!img.isNull() && img.save(shotPath))
                fprintf(stderr, "nimbus-clock: SHOT_OK %s\n", shotPath.toUtf8().constData());
            else
                fprintf(stderr, "nimbus-clock: SHOT_FAIL (grab vacío)\n");
        });
    }
    return app.exec();
}
