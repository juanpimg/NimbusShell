// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// F3-T04: CommandRunner (QProcess, run(QString)) como `runner` + flag
// --demo-menu (abre el menú al arrancar, acciones destructivas inhibidas).
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QWindow>
#include <QDebug>
#include <cstdio>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include "commandrunner.h"
#include "appmenumodel.h"

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

    bool demoMenu = false, demoCC = false, openCC = false, logQuery = false, logActions = false, demoCalendar = false, demoAppmenu = false, logAppmenu = false;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo-menu"))
            demoMenu = true;
        else if (a == QStringLiteral("--demo-cc"))
            demoCC = true;
        else if (a == QStringLiteral("--open-cc"))
            openCC = true;
        else if (a == QStringLiteral("--log-query"))
            logQuery = true;
        else if (a == QStringLiteral("--log-actions"))
            logActions = true;
        else if (a == QStringLiteral("--demo-calendar"))
            demoCalendar = true;
        else if (a == QStringLiteral("--demo-appmenu"))
            demoAppmenu = true;
        else if (a == QStringLiteral("--log-appmenu"))
            logAppmenu = true;
    }

    CommandRunner runner;
    runner.setLogQuery(logQuery || demoCC);
    // F3-T05-fix: el qDebug por defecto no sale en este Qt (verificado con
    // binario mínimo); con --log-query se instala handler propio a stderr.
    // F3-T06: idem para --log-appmenu/--demo-appmenu (AppMenuModel usa qInfo).
    // El handler va ANTES de construir AppMenuModel: su log de init usa qInfo.
    if (logQuery || demoCC || logAppmenu || demoAppmenu)
        qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &, const QString &m) {
            fprintf(stderr, "nimbus-bar[%d]: %s\n", static_cast<int>(t), m.toUtf8().constData());
        });
    AppMenuModel appMenu(logAppmenu || demoAppmenu);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("runner"), &runner);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMenu"), demoMenu);
    engine.rootContext()->setContextProperty(QStringLiteral("demoCC"), demoCC);
    engine.rootContext()->setContextProperty(QStringLiteral("openCC"), openCC);
    engine.rootContext()->setContextProperty(QStringLiteral("logActions"), logActions);
    engine.rootContext()->setContextProperty(QStringLiteral("demoCalendar"), demoCalendar);
    engine.rootContext()->setContextProperty(QStringLiteral("appMenu"), &appMenu);
    engine.rootContext()->setContextProperty(QStringLiteral("demoAppmenu"), demoAppmenu);
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
