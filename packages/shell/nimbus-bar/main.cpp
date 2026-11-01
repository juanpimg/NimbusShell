// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// F3-T04: CommandRunner (QProcess, run(QString)) como `runner` + flag
// --demo-menu (abre el menú al arrancar, acciones destructivas inhibidas).
#include <QGuiApplication>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QStringList>
#include <QQuickImageProvider>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QTimer>
#include <QWindow>
#include <QDebug>
#include <QDBusConnection>
#include <cstdio>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include "commandrunner.h"
#include "appmenumodel.h"
#include "statusnotifiermodel.h"
#include "batteryinfo.h"
#include "notificationserver.h"
#include "osdbridge.h"

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

// F3-T13: lee ~/.config/nimbus-bar/preset.json (XDG_CONFIG_HOME primero).
// Devuelve el JSON compacto, o "{}" si ausente/inválido (QML aplica
// fallbacks; sin valores mágicos nuevos en C++ salvo el "sin preset").
static QString loadBarPresetJson()
{
    const QString cfg = qEnvironmentVariable(
        "XDG_CONFIG_HOME", QDir::homePath() + QStringLiteral("/.config"));
    QFile f(cfg + QStringLiteral("/nimbus-bar/preset.json"));
    if (!f.open(QIODevice::ReadOnly))
        return QStringLiteral("{}");
    QJsonDocument d = QJsonDocument::fromJson(f.readAll());
    if (!d.isObject())
        return QStringLiteral("{}");
    return QString::fromUtf8(d.toJson(QJsonDocument::Compact));
}

// F3-T13: altura de la barra desde el preset (clamp 16..32; 24 sin preset).
static int barPresetHeight(const QString &presetJson)
{
    QJsonDocument d = QJsonDocument::fromJson(presetJson.toUtf8());
    const int h = d.object().value(QStringLiteral("bar")).toObject()
                      .value(QStringLiteral("height")).toInt(24);
    return qBound(16, h, 32);
}

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

    bool demoMenu = false, demoCC = false, openCC = false, logQuery = false, logActions = false,
         demoCalendar = false, demoAppmenu = false, logAppmenu = false, demoTray = false,
         demoOsd = false, wantNotif = true, demoNotif = false;
    QString demoOsdKind = QStringLiteral("volume");
    double demoOsdValue = 0.7;
    int trayOpenMenu = -1;
    QString customAccent; // F11-T03: --accent <hex> → NimbusTokens.accentCustom
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo-menu"))
            demoMenu = true;
        else if (a == QStringLiteral("--demo-osd")) {
            // --demo-osd volume|brightness (arg separado o =kind).
            demoOsd = true;
            if (i + 1 < argc && argv[i + 1][0] != '-') {
                demoOsdKind = QString::fromLocal8Bit(argv[++i]);
            }
        } else if (a.startsWith(QStringLiteral("--demo-osd="))) {
            demoOsd = true;
            demoOsdKind = a.mid(QStringLiteral("--demo-osd=").size());
        }
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
        else if (a == QStringLiteral("--demo-tray"))
            demoTray = true;
        else if (a == QStringLiteral("--notifications"))
            wantNotif = true;
        else if (a == QStringLiteral("--no-notifications"))
            wantNotif = false;
        else if (a == QStringLiteral("--demo-notification"))
            demoNotif = true;
        else if (a == QStringLiteral("--tray-open-menu"))
            trayOpenMenu = 0;
        else if (a == QStringLiteral("--accent") && i + 1 < argc)
            customAccent = QString::fromLocal8Bit(argv[++i]);
        else if (a.startsWith(QStringLiteral("--accent=")))
            customAccent = a.mid(QStringLiteral("--accent=").size());
    }
    if (demoOsd && demoOsdKind != QStringLiteral("volume")
        && demoOsdKind != QStringLiteral("brightness")) {
        qWarning("nimbus-bar: --demo-osd kind '%s' invalido, uso volume",
                 qUtf8Printable(demoOsdKind));
        demoOsdKind = QStringLiteral("volume");
    }
    if (demoOsd && demoOsdKind == QStringLiteral("brightness"))
        demoOsdValue = 0.6;

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
    // F3-T10: puente OSD (DBus org.nimbus.OSD /OSD show(kind,value)).
    OsdBridge osdBridge;
    new OsdAdaptor(&osdBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("osdBridge"), &osdBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("demoOsd"), demoOsd);
    engine.rootContext()->setContextProperty(QStringLiteral("demoOsdKind"), demoOsdKind);
    engine.rootContext()->setContextProperty(QStringLiteral("demoOsdValue"), demoOsdValue);
    // F3-T12: servidor FDO de notificaciones (R-NOTIF-SERVER). No fatal:
    // si el nombre lo posee plasmashell stock, la barra sigue viva.
    NotificationServer notifServer;
    engine.rootContext()->setContextProperty(QStringLiteral("notifServer"),
                                             &notifServer);
    // F3-T07: modelo SNI + provider image://sni.
    StatusNotifierModel trayModel;
    engine.rootContext()->setContextProperty(QStringLiteral("trayModel"), &trayModel);
    // F3-T05: batería real (se oculta si el equipo no tiene batería).
    BatteryInfo battery;
    engine.rootContext()->setContextProperty(QStringLiteral("battery"), &battery);
    engine.rootContext()->setContextProperty(QStringLiteral("trayOpenMenu"), trayOpenMenu);
    // F11-T03: acento configurable (siempre definido; "" = tabla §2.1).
    engine.rootContext()->setContextProperty(QStringLiteral("customAccent"), customAccent);
    // F3-T13: preset de la barra (~/.config/nimbus-bar/preset.json).
    const QString barPresetJson = loadBarPresetJson();
    engine.rootContext()->setContextProperty(QStringLiteral("barPresetJson"), barPresetJson);
    const int barHeight = barPresetHeight(barPresetJson);
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
    qInfo().noquote() << QStringLiteral("nimbus-bar: demoMenu=%1 logActions=%2 barHeight=%3")
                             .arg(demoMenu)
                             .arg(logActions)
                             .arg(barHeight);
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
    // (anclas/arriba, exclusiveZone = altura del preset, capa Top,
    // sin teclado, scope). F3-T13: barHeight sale del preset (24 sin preset).
    if (auto *win = qobject_cast<QWindow *>(engine.rootObjects().first())) {
        if (auto *ls = LayerShellQt::Window::get(win)) {
            ls->setAnchors({LayerShellQt::Window::AnchorTop,
                            LayerShellQt::Window::AnchorLeft,
                            LayerShellQt::Window::AnchorRight});
            ls->setExclusiveZone(barHeight);
            ls->setLayer(LayerShellQt::Window::LayerTop);
            ls->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            ls->setScope(QStringLiteral("nimbus-bar"));
            ls->setActivateOnShow(false);
        }
    }

    bool dumpPreset = false;
    for (int i = 1; i < argc; ++i) {
        if (QString::fromLocal8Bit(argv[i]) == QStringLiteral("--dump-preset"))
            dumpPreset = true;
    }

    // F3-T13: --dump-preset vuelca los valores EFECTIVOS del binding QML
    // (altura, formato de reloj, orden/visibilidad de iconos, OSD) por
    // stderr con fprintf (visible aunque el Qt suprima qInfo, ver
    // F3-T05-fix) y sale. Solo verificación (nested/offscreen/CI).
    if (dumpPreset) {
        QTimer::singleShot(1500, &app, [&engine]() {
            QObject *rootObj = engine.rootObjects().first();
            if (!rootObj) {
                fprintf(stderr, "preset-dump: sin root\n");
                QCoreApplication::exit(1);
                return;
            }
            const QString pname =
                rootObj->property("preset").toMap().value(QStringLiteral("name")).toString();
            fprintf(stderr, "preset-dump: name=%s height=%d clockFormat=%s\n",
                    qUtf8Printable(pname),
                    rootObj->property("height").toInt(),
                    qUtf8Printable(rootObj->property("clockFormat").toString()));
            if (QObject *rb = rootObj->findChild<QObject *>(QStringLiteral("rightBox"))) {
                QStringList parts;
                // childItems(): orden visual que usa Row (QObject::children
                // no lo refleja tras reparentar).
                QList<QQuickItem *> items;
                if (auto *ritem = qobject_cast<QQuickItem *>(rb))
                    items = ritem->childItems();
                for (QQuickItem *c : items) {
                    if (c->objectName().isEmpty())
                        continue;
                    parts << QStringLiteral("%1:%2").arg(
                        c->objectName(), c->property("visible").toBool() ? QStringLiteral("1") : QStringLiteral("0"));
                }
                fprintf(stderr, "preset-dump: rightBox=%s\n",
                        qUtf8Printable(parts.join(QStringLiteral(","))));
            } else {
                fprintf(stderr, "preset-dump: rightBox NO ENCONTRADO\n");
            }
            if (QObject *osd = rootObj->findChild<QObject *>(QStringLiteral("osdRoot"))) {
                fprintf(stderr, "preset-dump: osd=%dx%d timeout=%d\n",
                        osd->property("popupWidth").toInt(),
                        osd->property("popupHeight").toInt(),
                        osd->property("timeoutMs").toInt());
            } else {
                fprintf(stderr, "preset-dump: osdRoot NO ENCONTRADO\n");
            }
            if (QObject *clk = rootObj->findChild<QObject *>(QStringLiteral("clock"))) {
                fprintf(stderr, "preset-dump: clock='%s'\n",
                        qUtf8Printable(clk->property("text").toString()));
            }
            fprintf(stderr, "preset-dump: orderApplied=%s orderError=%s\n",
                    qUtf8Printable(rootObj->property("presetOrderApplied").toString()),
                    qUtf8Printable(rootObj->property("presetOrderError").toString()));
            QCoreApplication::quit();
        });
    }
    // F3-T07: --demo-tray siembra 2 items si el watcher sigue vacío
    // (fallback determinista; con items reales no hace nada).
    if (demoTray) {
        QTimer::singleShot(2500, &trayModel, [&trayModel]() {
            if (trayModel.rowCount() == 0)
                trayModel.seedDemoItems();
        });
    }

    // F3-T10: servicio org.nimbus.OSD (/OSD show(kind,value)). No fatal:
    // la barra funciona sin bus (nested sin sesión, OSD vía --demo-osd).
    if (!QDBusConnection::sessionBus().registerService(QStringLiteral("org.nimbus.OSD")))
        qWarning("nimbus-bar: no se pudo registrar org.nimbus.OSD (sigue sin DBus)");
    if (!QDBusConnection::sessionBus().registerObject(QStringLiteral("/OSD"), &osdBridge))
        qWarning("nimbus-bar: no se pudo registrar /OSD (sigue sin DBus)");

    // F3-T12: servidor org.freedesktop.Notifications (R-NOTIF-SERVER).
    // --no-notifications lo omite; --notifications (defecto) lo intenta;
    // nombre tomado (plasmashell stock) = aviso, NO aborta.
    if (wantNotif)
        notifServer.registerOnBus();
    else
        qInfo("nimbus-bar: notificaciones desactivadas (--no-notifications)");
    // --demo-notification: siembra una notificación local (funciona con o
    // sin bus: ejercita modelo + banner en nested/offscreen).
    if (demoNotif) {
        QTimer::singleShot(2500, &notifServer, [&notifServer]() {
            notifServer.Notify(
                QStringLiteral("Nimbus"), 0, QString(),
                QStringLiteral("Reunión"),
                QStringLiteral("En 5 minutos"), QStringList(),
                QVariantMap(), 5000);
        });
    }

    return app.exec();
}
