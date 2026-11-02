// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// F3-T04: CommandRunner (QProcess, run(QString)) como `runner` + flag
// --demo-menu (abre el menú al arrancar, acciones destructivas inhibidas).
#include <QGuiApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
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
#include <KWindowEffects>
#include "commandrunner.h"
#include "appmenumodel.h"
#include "statusnotifiermodel.h"
#include "batteryinfo.h"
#include "notificationserver.h"
#include "osdbridge.h"
#include "mprismodel.h"
#include "weathermodel.h"

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

    // F3-T03: single-instance por nombre de bus. systemd (nimbus-bar.service),
    // el env script y el autostart .desktop pueden coincidir en el login; solo
    // la primera instancia posee org.nimbus.Bar y las demás salen 0. Sin bus
    // de sesión (nested/offscreen/CI) se permite el arranque (single-instance
    // desactivado, se avisa). No toca org.freedesktop.Notifications: ese
    // registro sigue siendo no fatal y puede perderlo contra plasmashell.
    {
        QDBusConnection sessionBus = QDBusConnection::sessionBus();
        if (sessionBus.isConnected()) {
            if (!sessionBus.registerService(QStringLiteral("org.nimbus.Bar"))) {
                fprintf(stderr, "nimbus-bar: org.nimbus.Bar ya registrado "
                        "(instancia viva) — salgo 0\n");
                return 0;
            }
        } else {
            fprintf(stderr, "nimbus-bar: sin bus de sesión; single-instance "
                    "desactivado en este arranque\n");
        }
    }

    bool demoMenu = false, demoCC = false, openCC = false, logQuery = false, logActions = false,
         demoCalendar = false, demoAppmenu = false, logAppmenu = false, demoTray = false,
         demoOsd = false, wantNotif = true, demoNotif = false, demoMedia = false,
         demoWeather = false, dumpMedia = false, dumpWeather = false;
    QString demoOsdKind = QStringLiteral("volume");
    double demoOsdValue = 0.7;
    int trayOpenMenu = -1;
    QString customAccent; // F11-T03: --accent <hex> → NimbusTokens.accentCustom
    QString qmlRoot; // --qml-root DIR: Bar.qml desde disco (iterar sin rebuild)
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
        else if (a == QStringLiteral("--demo-media"))
            demoMedia = true;
        else if (a == QStringLiteral("--demo-weather"))
            demoWeather = true;
        else if (a == QStringLiteral("--dump-media"))
            dumpMedia = true;
        else if (a == QStringLiteral("--dump-weather"))
            dumpWeather = true;
        else if (a == QStringLiteral("--tray-open-menu"))
            trayOpenMenu = 0;
        else if (a == QStringLiteral("--accent") && i + 1 < argc)
            customAccent = QString::fromLocal8Bit(argv[++i]);
        else if (a.startsWith(QStringLiteral("--accent=")))
            customAccent = a.mid(QStringLiteral("--accent=").size());
        else if (a == QStringLiteral("--qml-root")) {
            if (i + 1 >= argc) {
                fprintf(stderr, "nimbus-bar: --qml-root requiere un directorio "
                        "(ejemplo: --qml-root packages/shell/nimbus-bar/qml)\n");
                return 1;
            }
            qmlRoot = QString::fromLocal8Bit(argv[++i]);
        } else if (a.startsWith(QStringLiteral("--qml-root=")))
            qmlRoot = a.mid(QStringLiteral("--qml-root=").size());
    }

    // --qml-root DIR: carga DIR/Bar.qml en vez de qrc:/Bar.qml para iterar
    // QML editando y reiniciando la barra (sin cmake). El `import "."` del
    // QML resuelve NimbusTokens.qml/qmldir del mismo DIR; el resto del QML
    // es idéntico al empaquetado. Sin flag se mantiene qrc:/Bar.qml.
    QUrl rootUrl(QStringLiteral("qrc:/Bar.qml"));
    if (!qmlRoot.isEmpty()) {
        const QFileInfo barQml(qmlRoot + QStringLiteral("/Bar.qml"));
        if (!barQml.isFile() || !barQml.isReadable()) {
            fprintf(stderr, "nimbus-bar: --qml-root: falta %s o no es legible "
                    "(se espera DIR/Bar.qml; ejemplo: --qml-root "
                    "packages/shell/nimbus-bar/qml)\n",
                    qUtf8Printable(barQml.absoluteFilePath()));
            return 1;
        }
        qmlRoot = barQml.absolutePath();
        rootUrl = QUrl::fromLocalFile(barQml.absoluteFilePath());
        fprintf(stderr, "nimbus-bar: qml-root=%s\n", qUtf8Printable(qmlRoot));
        if (!QFileInfo::exists(qmlRoot + QStringLiteral("/qmldir")))
            fprintf(stderr, "nimbus-bar: aviso: sin qmldir en %s; import \".\" "
                    "no resolverá NimbusTokens\n", qUtf8Printable(qmlRoot));
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
    // F10-T01: Now Playing MPRIS + Tiempo Open-Meteo (context props).
    MprisModel mpris;
    if (demoMedia)
        mpris.setDemo(true);
    engine.rootContext()->setContextProperty(QStringLiteral("mpris"), &mpris);
    engine.rootContext()->setContextProperty(QStringLiteral("demoMedia"), demoMedia);
    WeatherModel weather;
    if (demoWeather)
        weather.setDemo(true);
    engine.rootContext()->setContextProperty(QStringLiteral("weather"), &weather);
    engine.rootContext()->setContextProperty(QStringLiteral("demoWeather"), demoWeather);
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
    engine.load(rootUrl);
    if (engine.rootObjects().isEmpty()) {
        qWarning("nimbus-bar: fallo al cargar %s",
                 qUtf8Printable(rootUrl.toString()));
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

    // F11: blur real del compositor (ext-background-effect) detrás de las
    // superficies layer-shell transparentes de Nimbus. El QML solo pinta
    // tinte/rim/sombra. El binding del global Wayland y la capability blur
    // son ASÍNCRONOS: isEffectAvailable() es false en el primer frame aunque
    // el protocolo exista. Registramos la región siempre y reaplicamos a los
    // 500 ms; el protocolo es double-buffered, así que hace falta un
    // requestUpdate() para que el commit aplique la región.
    auto enableCompositorBlur = [](QWindow *win) {
        if (!win)
            return;
        // Región explícita (no vacía): con layer-shell, una región vacía
        // significa "toda la ventana" y algunos popups degenerados podían
        // hacer que KWin blureara el output completo.
        const QRegion region(0, 0, qMax(1, win->width()), qMax(1, win->height()));
        // El scrim del CC es pantalla completa: blurearlo emborronaría todo
        // el escritorio. No es una superficie de vidrio. Se detecta por
        // scope/título y, como red de seguridad, por geometría (el scope
        // adjunto puede no estar resuelto cuando se itera al arrancar).
        if (win->title().contains(QStringLiteral("scrim"), Qt::CaseInsensitive))
            return;
        if (QScreen *scr = win->screen()) {
            const QSize sz = scr->geometry().size();
            if (sz.isValid() && win->width() >= sz.width() * 9 / 10
                && win->height() >= sz.height() * 9 / 10)
                return;
        }
        if (auto *ls = LayerShellQt::Window::get(win)) {
            const QString scope = ls->scope();
            if (scope.contains(QStringLiteral("scrim")))
                return;
            fprintf(stderr, "nimbus-bar: glass scope=%s\n", qUtf8Printable(scope));
        }
        KWindowEffects::enableBlurBehind(win, true, region);
        win->requestUpdate();
        QTimer::singleShot(500, win, [win, region]() {
            fprintf(stderr, "nimbus-bar: blur compositor activo=%d\n",
                    KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind));
            KWindowEffects::enableBlurBehind(win, false);
            KWindowEffects::enableBlurBehind(win, true, region);
            win->requestUpdate();
        });
    };

    // F3-T12 multi-monitor: una ventana layer-shell por QScreen en el mismo
    // proceso (una sola instancia, un solo NotificationServer). Visible=false
    // en Bar.qml hasta fijar screen; asi el surface nace en su salida.
    auto configureBar = [&](QWindow *win, QScreen *screen) {
        if (!win || !screen)
            return;
        win->setScreen(screen);
        if (auto *ls = LayerShellQt::Window::get(win)) {
            ls->setScreen(screen);
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
        win->setVisible(true);
        enableCompositorBlur(win);
    };
    auto *primaryWin = qobject_cast<QWindow *>(engine.rootObjects().first());
    configureBar(primaryWin, QGuiApplication::primaryScreen());
    QList<QObject *> extraBars;
    QQmlComponent barComponent(&engine, rootUrl);
    for (QScreen *screen : QGuiApplication::screens()) {
        if (screen == QGuiApplication::primaryScreen())
            continue;
        QObject *obj = barComponent.create();
        if (!obj) {
            qWarning("nimbus-bar: no se pudo crear barra para %s",
                     qUtf8Printable(screen->name()));
            continue;
        }
        auto *w = qobject_cast<QWindow *>(obj);
        configureBar(w, screen);
        extraBars.append(obj);
        qInfo("nimbus-bar: barra secundaria en %s", qUtf8Printable(screen->name()));
    }

    // Ventanas layer-shell de popups creadas por Bar.qml (CC, menú, calendario,
    // OSD, notificaciones): mismo vidrio que la barra. Se reaplica al mostrar
    // porque el surface puede nacer recién entonces.
    const bool glassBarOnly = qEnvironmentVariableIsSet("NIMBUS_GLASS_BAR_ONLY");
    const QStringList glassScopes = qEnvironmentVariable("NIMBUS_GLASS_SCOPES")
                                        .split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (QWindow *w : QGuiApplication::allWindows()) {
        if (!w || w == primaryWin || glassBarOnly)
            continue;
        auto *ls = LayerShellQt::Window::get(w);
        fprintf(stderr, "nimbus-bar: window title=%s geom=%dx%d scope=%s\n",
                qUtf8Printable(w->title()), w->width(), w->height(),
                ls ? qUtf8Printable(ls->scope()) : "(none)");
        if (!ls || ls->scope() == QStringLiteral("nimbus-bar"))
            continue;
        // F3-T04: sin anchors, KWin asigna al popup del menú toda el área
        // disponible (1280x730) y su fondo oscuro tapa el escritorio. El
        // menú se ancla arriba-izquierda con su tamaño QML (248x372).
        if (ls->scope() == QStringLiteral("nimbus-menu")) {
            ls->setAnchors({LayerShellQt::Window::AnchorTop,
                            LayerShellQt::Window::AnchorLeft});
            ls->setMargins(QMargins(8, 26, 0, 0));
        }
        if (!glassScopes.isEmpty() && !glassScopes.contains(ls->scope()))
            continue;
        // Allowlist: de momento solo el CC está validado. Registrar blur en
        // otros popups ocultos (menú/calendario/tray/OSD) hacía que KWin 6.8
        // blureara el output completo; se validarán uno a uno con captura.
        // Allowlist de superficies de vidrio propias. Los scrims full-screen
        // se descartan dentro de enableCompositorBlur (título/geometría).
        static const QStringList kNimbusGlassScopes = {
            QStringLiteral("nimbus-cc"),
            QStringLiteral("nimbus-menu"),
            QStringLiteral("nimbus-cal"),
            QStringLiteral("nimbus-notifications"),
            QStringLiteral("nimbus-osd"),
            QStringLiteral("nimbus-tray-menu"),
            QStringLiteral("nimbus-globalmenu"),
        };
        if (!kNimbusGlassScopes.contains(ls->scope()))
            continue;
        enableCompositorBlur(w);
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
    // F10-T01: --dump-media/--dump-weather (unit test determinista, offscreen).
    if (dumpMedia || dumpWeather) {
        QTimer::singleShot(3000, &app, [&mpris, &weather, dumpMedia, dumpWeather]() {
            if (dumpMedia)
                fprintf(stderr, "media-dump: has=%d title='%s' artist='%s' playing=%d\n",
                        mpris.hasPlayer(), qUtf8Printable(mpris.title()),
                        qUtf8Printable(mpris.artist()), mpris.playing());
            if (dumpWeather)
                fprintf(stderr, "weather-dump: city='%s' temp='%s' cond='%s' code=%d minmax='%s' days=%d stale=%d\n",
                        qUtf8Printable(weather.city()), qUtf8Printable(weather.temp()),
                        qUtf8Printable(weather.cond()), weather.condCode(),
                        qUtf8Printable(weather.minMax()), weather.days().size(),
                        weather.stale());
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
