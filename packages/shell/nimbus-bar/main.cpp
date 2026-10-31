// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// F3-T04: CommandRunner (QProcess, run(QString)) como `runner` + flag
// --demo-menu (abre el menú al arrancar, acciones destructivas inhibidas).
#include <QGuiApplication>
#include <QImage>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QTimer>
#include <QWindow>
#include <QDebug>
#include <cstdio>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include "commandrunner.h"
#include "statusnotifiermodel.h"

// F3-T07: provider image://sni/<uid> (pixmap SNI, icono de tema o badge).
class SniProvider : public QQuickImageProvider {
public:
    explicit SniProvider(StatusNotifierModel *m)
        : QQuickImageProvider(QQuickImageProvider::Image), m_model(m) {}
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override
    {
        const QSize s = requestedSize.isValid() ? requestedSize : QSize(16, 16);
        QImage img = m_model ? m_model->imageFor(id, s) : QImage();
        if (size)
            *size = img.size();
        return img;
    }
private:
    StatusNotifierModel *m_model;
};

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

    bool demoMenu = false, demoCC = false, openCC = false, logQuery = false, logActions = false, demoCalendar = false, demoTray = false;
    int trayOpenMenu = -1;
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
        else if (a == QStringLiteral("--demo-tray"))
            demoTray = true;
        else if (a == QStringLiteral("--tray-open-menu"))
            trayOpenMenu = 0;
    }

    CommandRunner runner;
    runner.setLogQuery(logQuery || demoCC);
    // F3-T05-fix: el qDebug por defecto no sale en este Qt (verificado con
    // binario mínimo); con --log-query se instala handler propio a stderr.
    if (logQuery || demoCC)
        qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &, const QString &m) {
            fprintf(stderr, "nimbus-bar[%d]: %s\n", static_cast<int>(t), m.toUtf8().constData());
        });
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("runner"), &runner);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMenu"), demoMenu);
    engine.rootContext()->setContextProperty(QStringLiteral("demoCC"), demoCC);
    engine.rootContext()->setContextProperty(QStringLiteral("openCC"), openCC);
    engine.rootContext()->setContextProperty(QStringLiteral("logActions"), logActions);
    engine.rootContext()->setContextProperty(QStringLiteral("demoCalendar"), demoCalendar);
    // F3-T07: modelo SNI + provider image://sni.
    StatusNotifierModel trayModel;
    engine.rootContext()->setContextProperty(QStringLiteral("trayModel"), &trayModel);
    engine.rootContext()->setContextProperty(QStringLiteral("trayOpenMenu"), trayOpenMenu);
    engine.addImageProvider(QStringLiteral("sni"), new SniProvider(&trayModel));
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

    // F3-T07: --demo-tray siembra 2 items si el watcher sigue vacío
    // (fallback determinista; con items reales no hace nada).
    if (demoTray) {
        QTimer::singleShot(2500, &trayModel, [&trayModel]() {
            if (trayModel.rowCount() == 0)
                trayModel.seedDemoItems();
        });
    }

    return app.exec();
}
