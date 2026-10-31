// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// F3-T04: CommandRunner (QProcess, run(QString)) como `runner` + flag
// --demo-menu (abre el menú al arrancar, acciones destructivas inhibidas).
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QWindow>
#include <QDebug>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include "commandrunner.h"

int main(int argc, char *argv[])
{
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    LayerShellQt::Shell::useLayerShell();
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-bar"));
    app.setOrganizationName(QStringLiteral("nimbus"));

    bool demoMenu = false;
    bool logActions = false;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo-menu"))
            demoMenu = true;
        else if (a == QStringLiteral("--log-actions"))
            logActions = true;
    }

    CommandRunner runner;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("runner"), &runner);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMenu"), demoMenu);
    engine.rootContext()->setContextProperty(QStringLiteral("logActions"), logActions);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &w) {
                         for (const auto &e : w)
                             qWarning().noquote() << e.toString();
                     });
    engine.load(QStringLiteral("qrc:/Bar.qml"));
    if (engine.rootObjects().isEmpty()) {
        qWarning("nimbus-bar: fallo al cargar qrc:/Bar.qml");
        return 1;
    }
    qInfo().noquote() << QStringLiteral("nimbus-bar: demoMenu=%1 logActions=%2")
                             .arg(demoMenu)
                             .arg(logActions);
    // --log-actions: invoca Menu.logAllActions desde C++ (recorre el
    // modelo QML real; runner.run inhibido en demo → solo log).
    if (demoMenu && logActions) {
        QObject *menu = engine.rootObjects().first()->findChild<QObject *>(
            QStringLiteral("appleMenuObj"));
        if (!menu) {
            qWarning("nimbus-bar: --log-actions sin Menu (appleMenuObj no encontrado)");
        } else if (!QMetaObject::invokeMethod(menu, "logAllActions")) {
            qWarning("nimbus-bar: --log-actions invokeMethod fallo");
        }
    }

    // Refuerzo en C++ de los mismos valores declarados en Bar.qml
    // (anclas/arriba, exclusiveZone 24, capa Top, sin teclado, scope).
    if (auto *win = qobject_cast<QWindow *>(engine.rootObjects().first())) {
        if (auto *ls = LayerShellQt::Window::get(win)) {
            ls->setAnchors({LayerShellQt::Window::AnchorTop,
                            LayerShellQt::Window::AnchorLeft,
                            LayerShellQt::Window::AnchorRight});
            ls->setExclusiveZone(24);
            ls->setLayer(LayerShellQt::Window::LayerTop);
            ls->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            ls->setScope(QStringLiteral("nimbus-bar"));
            ls->setActivateOnShow(false);
        }
    }

    return app.exec();
}
