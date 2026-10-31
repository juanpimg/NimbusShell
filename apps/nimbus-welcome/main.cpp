// nimbus-welcome — wizard de primer arranque F9-T02.
// Flags: --demo (abrir aunque esté completado), --page <n|nombre>,
//   --shot <png> (autocaptura para test nested), --reset (borra el .ini).
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QTimer>
#include <cstdio>

#include "welcomebackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-welcome"));
    app.setOrganizationName(QStringLiteral("nimbus"));

    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &,
                              const QString &m) {
        fprintf(stderr, "nimbus-welcome[%d]: %s\n", static_cast<int>(t),
                m.toUtf8().constData());
    });

    bool demo = false, reset = false;
    QString pageArg, shotPath;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo")) demo = true;
        else if (a == QStringLiteral("--reset")) reset = true;
        else if (a == QStringLiteral("--page") && i + 1 < argc)
            pageArg = QString::fromLocal8Bit(argv[++i]);
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
    }

    WelcomeBackend backend;
    if (reset) backend.reset();
    if (!pageArg.isEmpty()) {
        const int idx = backend.stepIndexFor(pageArg);
        if (idx < 0) {
            fprintf(stderr, "nimbus-welcome: página desconocida '%s'\n",
                    pageArg.toUtf8().constData());
            return 1;
        }
        backend.setStep(idx);
    }
    if (backend.completed() && !demo && pageArg.isEmpty() && shotPath.isEmpty()) {
        fprintf(stderr, "nimbus-welcome: ya completado, salgo (--demo para reabrir)\n");
        return 0;
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &w) {
                         for (const auto &e : w)
                             fprintf(stderr, "nimbus-welcome: QML-WARN %s\n",
                                     e.toString().toUtf8().constData());
                     });
    engine.load(QStringLiteral("qrc:/qml/Welcome.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-welcome: FALLO al cargar qrc:/qml/Welcome.qml\n");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        fprintf(stderr, "nimbus-welcome: root no es Window\n");
        return 1;
    }
    QObject::connect(&backend, &WelcomeBackend::requestQuit, win, &QQuickWindow::close);
    fprintf(stderr, "nimbus-welcome: STEP=%d completed=%d demo=%d\n",
            backend.step(), backend.completed() ? 1 : 0, demo ? 1 : 0);

    if (!shotPath.isEmpty()) {
        QTimer::singleShot(3500, win, [win, shotPath]() {
            const QImage img = win->grabWindow();
            if (!img.isNull() && img.save(shotPath))
                fprintf(stderr, "nimbus-welcome: SHOT_OK %s\n", shotPath.toUtf8().constData());
            else
                fprintf(stderr, "nimbus-welcome: SHOT_FAIL (grab vacío)\n");
        });
    }
    return app.exec();
}
