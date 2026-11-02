// KWinBackend — implementación (F7 R-MC-CUSTOM).
#include "kwinbackend.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusUnixFileDescriptor>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QHash>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTimer>
#include <poll.h>
#include <unistd.h>

static QString scriptingPath(const QString &file)
{
    return file;
}

KWinBackend::KWinBackend(bool demo, QObject *parent)
    : QObject(parent), m_demo(demo)
{
    if (m_demo)
        loadDemo();
}

void KWinBackend::setExposeActiveAppOnly(bool v)
{
    if (m_exposeOnly == v)
        return;
    m_exposeOnly = v;
    Q_EMIT exposeChanged();
}

void KWinBackend::toggleExpose() { setExposeActiveAppOnly(!m_exposeOnly); }

void KWinBackend::setReduceMotion(bool v)
{
    if (m_reduceMotion == v)
        return;
    m_reduceMotion = v;
    Q_EMIT motionChanged();
}

void KWinBackend::replayIntro()
{
    ++m_introKey;
    Q_EMIT introChanged();
}

void KWinBackend::showDesktop(bool show)
{
    QDBusInterface kwin(QStringLiteral("org.kde.KWin"),
                        QStringLiteral("/KWin"),
                        QStringLiteral("org.kde.KWin"),
                        QDBusConnection::sessionBus());
    kwin.call(QStringLiteral("showDesktop"), show);
}

int KWinBackend::sizeClassFor(int w, int h)
{
    const qint64 area = qint64(w) * qint64(h);
    if (area < 300000)
        return 0; // S
    if (area < 900000)
        return 1; // M
    return 2; // L
}

void KWinBackend::setError(const QString &e)
{
    m_lastError = e;
    Q_EMIT statsChanged();
}

void KWinBackend::loadDemo()
{
    m_desktops = {
        QVariantMap{{"id", "d1"}, {"name", "Escritorio 1"}, {"index", 1}, {"active", true}, {"windowCount", 4}},
        QVariantMap{{"id", "d2"}, {"name", "Escritorio 2"}, {"index", 2}, {"active", false}, {"windowCount", 2}},
        QVariantMap{{"id", "d3"}, {"name", "Escritorio 3"}, {"index", 3}, {"active", false}, {"windowCount", 0}},
        QVariantMap{{"id", "d4"}, {"name", "Escritorio 4"}, {"index", 4}, {"active", false}, {"windowCount", 0}},
    };
    m_currentDesktop = 1;
    m_windows = {
        QVariantMap{{"id", "w-kate"}, {"caption", "Kate — notas.txt"}, {"app", "kate"}, {"desktop", "d1"}, {"active", true}, {"minimized", false}, {"icon", "kate"}, {"thumb", ""}, {"w", 900}, {"h", 600}, {"sizeClass", 1}},
        QVariantMap{{"id", "w-konsole"}, {"caption", "Konsole — zsh"}, {"app", "konsole"}, {"desktop", "d1"}, {"active", false}, {"minimized", false}, {"icon", "konsole"}, {"thumb", ""}, {"w", 700}, {"h", 450}, {"sizeClass", 1}},
        QVariantMap{{"id", "w-dolphin"}, {"caption", "Dolphin — Documentos"}, {"app", "dolphin"}, {"desktop", "d1"}, {"active", false}, {"minimized", false}, {"icon", "dolphin"}, {"thumb", ""}, {"w", 1000}, {"h", 700}, {"sizeClass", 1}},
        QVariantMap{{"id", "w-settings"}, {"caption", "Preferencias del sistema"}, {"app", "systemsettings"}, {"desktop", "d1"}, {"active", false}, {"minimized", true}, {"icon", "systemsettings"}, {"thumb", ""}, {"w", 1100}, {"h", 750}, {"sizeClass", 1}},
        QVariantMap{{"id", "w-firefox"}, {"caption", "Firefox — Tahoe HIG"}, {"app", "firefox"}, {"desktop", "d2"}, {"active", false}, {"minimized", false}, {"icon", "firefox"}, {"thumb", ""}, {"w", 1280}, {"h", 800}, {"sizeClass", 2}},
        QVariantMap{{"id", "w-kate2"}, {"caption", "Kate — plan.md"}, {"app", "kate"}, {"desktop", "d2"}, {"active", false}, {"minimized", false}, {"icon", "kate"}, {"thumb", ""}, {"w", 500}, {"h", 350}, {"sizeClass", 0}},
    };
    m_currentApp = QStringLiteral("kate");
    m_hasThumbnails = false;
    Q_EMIT desktopsChanged();
    Q_EMIT windowsChanged();
}

void KWinBackend::refresh()
{
    QElapsedTimer t;
    t.start();
    m_refreshT0 = t.nsecsElapsed();
    readDesktops();
    probeScreenshots();
    if (m_demo) {
        // En demo refresca contadores y mide latencia local (<300ms).
        loadDemo();
        m_latencyMs = int(t.elapsed());
        Q_EMIT statsChanged();
        return;
    }
    if (!m_spacesEnsured) {
        m_spacesEnsured = true;
        ensureSpaces(4); // R-SPACES: 4 Spaces al arrancar (crea+refresca)
    }
    requestWindowsViaScript();
    // La latencia real se cierra en pushWindows(); si no llega nada en
    // 1.5s, fallback a demo vacía para no dejar la parrilla vacía.
    QTimer::singleShot(1500, this, [this, t]() mutable {
        if (m_windows.isEmpty()) {
            setError(QStringLiteral("sin respuesta KWin scripting; fallback demo"));
            loadDemo();
            m_latencyMs = int(t.elapsed());
            Q_EMIT statsChanged();
        }
    });
    m_latencyMs = int(t.elapsed());
    Q_EMIT statsChanged();
}

void KWinBackend::readDesktops()
{
    QDBusInterface vdm(QStringLiteral("org.kde.KWin"),
                       QStringLiteral("/VirtualDesktopManager"),
                       QStringLiteral("org.kde.KWin.VirtualDesktopManager"),
                       QDBusConnection::sessionBus());
    if (!vdm.isValid()) {
        setError(QStringLiteral("sin VirtualDesktopManager"));
        return;
    }
    const QVariant count = vdm.property("count");
    const QVariant current = vdm.property("current");
    // NOTA: el struct a(iss) de `desktops` NO se lee por QDBus (libdbus
    // aborta sin tipo registrado); ids/nombres llegan vía pushState.
    const int n = count.isValid() ? count.toInt() : 2;
    const QString curId = current.isValid() ? current.toString() : QString();
    if (m_desktops.isEmpty()) {
        for (int i = 1; i <= n; ++i)
            m_desktops.append(QVariantMap{{"id", QString("d%1").arg(i)},
                {"name", QString("Desktop %1").arg(i)}, {"index", i},
                {"active", i == 1}, {"windowCount", 0}});
        m_currentDesktop = 1;
    } else if (!curId.isEmpty()) {
        for (auto &d : m_desktops) {
            QVariantMap dm = d.toMap();
            dm["active"] = (dm.value("id").toString() == curId);
            if (dm["active"].toBool())
                m_currentDesktop = dm.value("index").toInt();
            d = dm;
        }
    }
    Q_EMIT desktopsChanged();
}

void KWinBackend::requestWindowsViaScript()
{
    // Helper one-shot: vuelca escritorios + windowList() a JSON y lo devuelve
    // vía callDBus a nuestro slot pushState (evita leer a(iss) por QDBus).
    const QString js = QStringLiteral(
        "var wds = workspace.desktops;\n"
        "var ds = [];\n"
        "for (var k = 0; k < wds.length; k++)\n"
        "  ds.push({id: String(wds[k].id), name: String(wds[k].name || ('Desktop ' + (k+1))), index: k+1});\n"
        "var cur = ''; try { cur = String(workspace.currentDesktop.id); } catch (e) {}\n"
        "var wins = workspace.stackingOrder;\n"
        "var out = [];\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "  var w = wins[i];\n"
        "  if (!w.normalWindow) continue;\n"
        "  var cap0 = String(w.caption || '');\n"
        "  var rc0 = String((w.resourceClass || '').toString().split(' ')[0] || '');\n"
        "  if (cap0 === '' || cap0 === 'Mission Control') continue;\n"
        "  if (/missioncontrol/i.test(rc0)) continue;\n"
        "  var desks = w.desktops || [];\n"
        "  var d0 = desks.length > 0 ? String(desks[0].id || desks[0]) : '';\n"
        "  var gw = 0, gh = 0;\n"
        "  try { gw = w.frameGeometry.width || 0; gh = w.frameGeometry.height || 0; } catch (e) {}\n"
        "  out.push({id: String(w.internalId), caption: String(w.caption || ''),\n"
        "    app: String((w.resourceClass || '').toString().split(' ')[0] || ''),\n"
        "    desktop: d0, active: w.active === true, minimized: w.minimized === true,\n"
        "    W: gw, H: gh});\n"
        "}\n"
        "callDBus('org.nimbus.MissionControl', '/MC', 'org.nimbus.MissionControl',\n"
        "  'pushState', JSON.stringify({desktops: ds, current: cur, windows: out}));\n");
    runOneshotScript(js, QStringLiteral("nimbus-mc-dump-%1").arg(++m_dumpSeq));
}

void KWinBackend::runOneshotScript(const QString &js, const QString &tag)
{
    // RuntimeLocation (/run/user/UID) o tmp; NO /tmp/opencode (no existe en
    // un sistema instalado: el fallo silencioso dejaba MC sin refresh ni
    // activación; reproducido en out12). mkpath garantiza el directorio.
    QString dir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (dir.isEmpty())
        dir = QDir::tempPath();
    dir += QStringLiteral("/nimbus-mc");
    if (!QDir().mkpath(dir))
        return;
    QString path = QStringLiteral("%1/%2.js").arg(dir, tag);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    f.write(js.toUtf8());
    f.close();
    QDBusInterface scripting(QStringLiteral("org.kde.KWin"),
                             QStringLiteral("/Scripting"),
                             QStringLiteral("org.kde.kwin.Scripting"),
                             QDBusConnection::sessionBus());
    if (!scripting.isValid())
        return;
    // loadScript devuelve el id; Script<id>.run evalúa SOLO ese script y la
    // llamada DBus espera al resultado. `start()` re-ejecuta todos los
    // scripts cargados (incluidos one-shots viejos) y causaba activaciones
    // perdidas (F7-T10, VM out12).
    const QDBusReply<int> loaded = scripting.call(
        QStringLiteral("loadScript"), scriptingPath(path), tag);
    if (!loaded.isValid() || loaded.value() < 0)
        return;
    QDBusInterface script(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/Scripting/Script%1").arg(loaded.value()),
        QStringLiteral("org.kde.kwin.Script"),
        QDBusConnection::sessionBus());
    if (script.isValid())
        script.call(QStringLiteral("run"));
    QTimer::singleShot(1200, this, [tag]() {
        QDBusInterface sc(QStringLiteral("org.kde.KWin"),
                          QStringLiteral("/Scripting"),
                          QStringLiteral("org.kde.kwin.Scripting"),
                          QDBusConnection::sessionBus());
        sc.call(QStringLiteral("unloadScript"), tag);
    });
}

void KWinBackend::pushState(const QString &json)
{
    QElapsedTimer t;
    t.start();
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject())
        return;
    const QJsonObject root = doc.object();
    const QJsonArray darr = root.value("desktops").toArray();
    const QString curId = root.value("current").toString();
    if (!darr.isEmpty()) {
        m_desktops.clear();
        int idx = 1;
        for (const QJsonValue &v : darr) {
            const QJsonObject o = v.toObject();
            const QString id = o.value("id").toString();
            const int di = o.value("index").toInt(idx);
            QString dname = o.value("name").toString();
            if (dname.isEmpty())
                dname = QStringLiteral("Desktop %1").arg(di);
            m_desktops.append(QVariantMap{
                {"id", id}, {"name", dname}, {"index", di},
                {"active", !curId.isEmpty() ? (id == curId) : (idx == 1)},
                {"windowCount", 0}});
            if (!curId.isEmpty() && id == curId)
                m_currentDesktop = di;
            ++idx;
        }
    }
    QJsonArray warr = root.value("windows").toArray();
    QHash<QString, QString> oldThumbs; // conserva thumbs por ventana (mismo internalId)
    for (const auto &w : m_windows)
        oldThumbs.insert(w.toMap().value("id").toString(),
                         w.toMap().value("thumb").toString());
    m_windows.clear();
    QString activeApp;
    for (const QJsonValue &v : warr) {
        const QJsonObject o = v.toObject();
        const QString app = o.value("app").toString();
        if (o.value("active").toBool())
            activeApp = app;
        const int ww = o.value("W").toInt(), hh = o.value("H").toInt();
        const QString wid = o.value("id").toString();
        QVariantMap m{{"id", wid},
                      {"caption", o.value("caption").toString()},
                      {"app", app},
                      {"desktop", o.value("desktop").toString()},
                      {"active", o.value("active").toBool()},
                      {"minimized", o.value("minimized").toBool()},
                      {"icon", app.toLower()},
                      {"thumb", oldThumbs.value(wid)},
                      {"w", ww}, {"h", hh},
                      {"sizeClass", sizeClassFor(ww, hh)}};
        m_windows.append(m);
    }
    if (!activeApp.isEmpty())
        m_currentApp = activeApp;
    // Contadores por escritorio.
    for (auto &d : m_desktops) {
        QVariantMap dm = d.toMap();
        const QString id = dm.value("id").toString();
        int c = 0;
        for (const auto &w : m_windows)
            if (w.toMap().value("desktop").toString() == id)
                ++c;
        dm["windowCount"] = c;
        d = dm;
    }
    m_latencyMs = int(t.elapsed());
    setError(QString());
    Q_EMIT windowsChanged();
    Q_EMIT desktopsChanged();
}

// Compat: helper antiguos que mandan solo el array de ventanas.
void KWinBackend::pushWindows(const QString &json)
{
    pushState(QStringLiteral("{\"desktops\":[],\"current\":\"\",\"windows\":%1}").arg(json));
}

void KWinBackend::activateWindow(const QString &winId)
{
    // Activa ventana (y su escritorio) vía one-shot.
    const QString js = QStringLiteral(
        "var target = '%1';\n"
        "var wins = workspace.stackingOrder;\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "  if (String(wins[i].internalId) === target) {\n"
        "    wins[i].minimized = false;\n"
        "    workspace.activeWindow = wins[i];\n"
        "    break;\n"
        "  }\n"
        "}\n").arg(winId);
    runOneshotScript(js, QStringLiteral("nimbus-mc-act-%1").arg(++m_dumpSeq));
}

QString KWinBackend::activateFirst()
{
    // Test E2E de la ruta de activación (one-shot KWin real).
    for (const auto &w : m_windows) {
        const QVariantMap m = w.toMap();
        if (!m.value("caption").toString().isEmpty()) {
            activateWindow(m.value("id").toString());
            return m.value("caption").toString();
        }
    }
    return QString();
}

void KWinBackend::moveWindowToDesktop(const QString &winId, const QString &deskId)
{
    const QString js = QStringLiteral(
        "var target = '%1', desk = '%2';\n"
        "var wins = workspace.stackingOrder;\n"
        "var ds = workspace.desktops;\n"
        "var dd = null;\n"
        "for (var i = 0; i < ds.length; i++) {\n"
        "  if (String(ds[i].id) === desk) { dd = ds[i]; break; }\n"
        "}\n"
        "if (dd) for (var j = 0; j < wins.length; j++) {\n"
        "  if (String(wins[j].internalId) === target) {\n"
        "    wins[j].desktops = [dd];\n"
        "    break;\n"
        "  }\n"
        "}\n").arg(winId, deskId);
    runOneshotScript(js, QStringLiteral("nimbus-mc-mv-%1").arg(++m_dumpSeq));
}

void KWinBackend::moveWindowToDesktopAtCursor(const QString &winId)
{
    // F7-T10: sin Drag/Drop QML. Usa workspace.cursorPos y Window.desktops
    // (propiedad read-write de KWin 6). Mapea la fila de Spaces: margen 24,
    // tile 180 + spacing 12; el clamp evita índices fuera de rango.
    const QString js = QStringLiteral(
        "var target = '%1';\n"
        "var wins = workspace.stackingOrder;\n"
        "var ds = workspace.desktops;\n"
        "var pos = workspace.cursorPos;\n"
        "var idx = Math.floor((pos.x - 24) / 192);\n"
        "if (idx < 0) idx = 0;\n"
        "if (idx >= ds.length) idx = ds.length - 1;\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "  if (String(wins[i].internalId) === target) {\n"
        "    wins[i].desktops = [ds[idx]];\n"
        "    print('NIMBUS_MOVE_CURSOR ' + target + ' -> ' + ds[idx].name);\n"
        "    break;\n"
        "  }\n"
        "}\n").arg(winId);
    runOneshotScript(js, QStringLiteral("nimbus-mc-mvcursor-%1").arg(++m_dumpSeq));
}

void KWinBackend::createSpace()
{
    // R-SPACES: crea "Escritorio N" real vía VirtualDesktopManager.
    QDBusInterface vdm(QStringLiteral("org.kde.KWin"),
                       QStringLiteral("/VirtualDesktopManager"),
                       QStringLiteral("org.kde.KWin.VirtualDesktopManager"),
                       QDBusConnection::sessionBus());
    if (!vdm.isValid()) {
        setError(QStringLiteral("sin VirtualDesktopManager"));
        return;
    }
    const int n = vdm.property("count").toInt();
    vdm.call(QStringLiteral("createDesktop"), uint(n),
             QStringLiteral("Escritorio %1").arg(n + 1));
    readDesktops();
    if (!m_demo)
        requestWindowsViaScript();
}

void KWinBackend::ensureSpaces(int n)
{
    QDBusInterface vdm(QStringLiteral("org.kde.KWin"),
                       QStringLiteral("/VirtualDesktopManager"),
                       QStringLiteral("org.kde.KWin.VirtualDesktopManager"),
                       QDBusConnection::sessionBus());
    if (!vdm.isValid())
        return;
    for (int guard = 0; guard < 8; ++guard) {
        const int count = vdm.property("count").toInt();
        if (count >= n || count <= 0)
            break;
        vdm.call(QStringLiteral("createDesktop"), uint(count),
                 QStringLiteral("Escritorio %1").arg(count + 1));
    }
    readDesktops();
}

QString KWinBackend::moveFirstTo(int deskIndex)
{
    // F7-T05 test E2E: mueve la 1ª ventana al Space nº deskIndex (1-based).
    if (m_windows.isEmpty())
        return QString();
    QString deskId, deskName;
    for (const auto &d : m_desktops) {
        const QVariantMap dm = d.toMap();
        if (dm.value("index").toInt() == deskIndex) {
            deskId = dm.value("id").toString();
            deskName = dm.value("name").toString();
        }
    }
    if (deskId.isEmpty())
        return QString();
    const QVariantMap w = m_windows.first().toMap();
    moveWindowToDesktop(w.value("id").toString(), deskId);
    return w.value("caption").toString() + QStringLiteral(" -> ") + deskName;
}
void KWinBackend::setCurrentDesktopById(const QString &deskId)
{
    for (const auto &d : m_desktops) {
        if (d.toMap().value("id").toString() == deskId) {
            setCurrentDesktopByIndex(d.toMap().value("index").toInt());
            return;
        }
    }
}

void KWinBackend::setCurrentDesktopByIndex(int idx)
{
    QDBusInterface kwin(QStringLiteral("org.kde.KWin"),
                        QStringLiteral("/KWin"),
                        QStringLiteral("org.kde.KWin"),
                        QDBusConnection::sessionBus());
    kwin.call(QStringLiteral("setCurrentDesktop"), idx);
    m_currentDesktop = idx;
    Q_EMIT desktopsChanged();
}

void KWinBackend::probeScreenshots()
{
    // Ruta real verificada en Plasma 6: servicio org.kde.KWin.ScreenShot2,
    // path /org/kde/KWin/ScreenShot2, CaptureWindow(handle,opciones,pipe) /
    // CaptureWorkspace(opciones,pipe). F7-T04 intenta la captura real con
    // pipe (ver requestThumbs); hasThumbnails solo si hay thumbs en disco.
    QDBusInterface ss(QStringLiteral("org.kde.KWin.ScreenShot2"),
                      QStringLiteral("/org/kde/KWin/ScreenShot2"),
                      QStringLiteral("org.kde.KWin.ScreenShot2"),
                      QDBusConnection::sessionBus());
    if (!ss.isValid()) {
        m_hasThumbnails = false;
        setError(QStringLiteral("ScreenShot2 no disponible; fallback icono+título"));
    }
}

QString KWinBackend::thumbLog()
{
    return m_thumbLog.join(QStringLiteral("\n"));
}

void KWinBackend::setWindowThumb(const QString &winId, const QString &url)
{
    for (auto &w : m_windows) {
        QVariantMap m = w.toMap();
        if (m.value("id").toString() == winId) {
            m["thumb"] = url;
            w = m;
        }
    }
    Q_EMIT windowsChanged();
}

// Captura síncrona (llamada DBus con timeout 2.5s + lectura del pipe con
// poll). KWin escribe píxeles RAW (BGRA32) + dimensiones en el reply
// (así lo consume xdg-desktop-portal-kde); aquí se convierte a PNG.
// Devuelve "" si guarda PNG en outPath, o el error exacto (para evidencia).
QString KWinBackend::captureTo(const QString &method, const QVariantList &leadArgs,
                              const QString &outPath, const QString &label)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin.ScreenShot2"),
        QStringLiteral("/org/kde/KWin/ScreenShot2"),
        QStringLiteral("org.kde.KWin.ScreenShot2"), method);
    int fds[2] = {-1, -1};
    if (::pipe(fds) != 0)
        return QStringLiteral("pipe() falló");
    QVariantList args = leadArgs;
    args << QVariant::fromValue(QVariantMap{})
         << QVariant::fromValue(QDBusUnixFileDescriptor(fds[1]));
    msg.setArguments(args);
    QDBusPendingCall pcall =
        QDBusConnection::sessionBus().asyncCall(msg, 2500);
    QDBusPendingCallWatcher watcher(pcall);
    QEventLoop loop;
    QTimer t;
    t.setSingleShot(true);
    QObject::connect(&t, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(&watcher, &QDBusPendingCallWatcher::finished,
                     &loop, &QEventLoop::quit);
    t.start(3000);
    loop.exec();
    // El envío ya ocurrió (hay reply o timeout): cierro mi extremo de
    // escritura ANTES de leer, o read() nunca ve EOF.
    ::close(fds[1]);
    fds[1] = -1;
    if (!t.isActive()) {
        ::close(fds[0]);
        return QStringLiteral("timeout esperando a KWin");
    }
    t.stop();
    QDBusPendingReply<QVariantMap> reply = pcall;
    if (reply.isError()) {
        ::close(fds[0]);
        return reply.error().message();
    }
    const QVariantMap meta = reply.value();
    // KWin escribe píxeles RAW (BGRA32) + dimensiones en el reply
    // (así lo consume xdg-desktop-portal-kde); aquí se convierte a PNG.
    QByteArray raw;
    const qint64 deadline = QDateTime::currentMSecsSinceEpoch() + 4000;
    for (;;) {
        struct pollfd pfd;
        pfd.fd = fds[0];
        pfd.events = POLLIN;
        pfd.revents = 0;
        const int pr = ::poll(&pfd, 1, 500);
        if (pr > 0) {
            char buf[65536];
            const ssize_t r = ::read(fds[0], buf, sizeof(buf));
            if (r <= 0)
                break; // EOF o error: fin real
            raw.append(buf, r);
            continue;
        }
        if (!raw.isEmpty())
            break; // silencio con datos: KWin retiene el fd; aceptamos
        if (QDateTime::currentMSecsSinceEpoch() >= deadline)
            break;
    }
    ::close(fds[0]);
    if (raw.size() < 100)
        return QStringLiteral("pipe vacío (%1 bytes)").arg(raw.size());
    // Conversión raw→PNG con las dimensiones del reply.
    const int mw = meta.value(QStringLiteral("width")).toInt();
    const int mh = meta.value(QStringLiteral("height")).toInt();
    int stride = meta.value(QStringLiteral("stride")).toInt();
    if (mw <= 0 || mh <= 0) {
        // Sin dimensiones no hay conversión honesta: se guarda raw y se
        // documenta (el visor mostrará fallback). Claves vistas:
        QFile f(outPath);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
            f.write(raw);
        m_thumbLog << label + QStringLiteral(" RAW sin dims (claves: %1)")
                                  .arg(QStringList(meta.keys()).join(','));
        return QStringLiteral("reply sin width/height");
    }
    if (stride <= 0)
        stride = mw * 4;
    if (raw.size() < stride * (mh - 1) + mw * 4) {
        QFile f(outPath);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
            f.write(raw);
        m_thumbLog << label + QStringLiteral(" RAW incompleto (%1 < %2)")
                                  .arg(raw.size()).arg(stride * mh);
        return QStringLiteral("bytes insuficientes");
    }
    QImage img(reinterpret_cast<const uchar *>(raw.constData()), mw, mh, stride,
               QImage::Format_RGB32);
    if (img.isNull())
        return QStringLiteral("QImage nula");
    if (!img.copy().save(outPath, "PNG"))
        return QStringLiteral("no se pudo escribir ") + outPath;
    m_thumbLog << label + QStringLiteral(" PNG %1x%2 stride=%3").arg(mw).arg(mh).arg(stride);
    return QString();
}

void KWinBackend::requestThumbs()
{
    // F7-T04: cadena workspace + hasta 10 ventanas, paso a paso con
    // singleShot para no bloquear la UI. Cada error queda en thumbLog.
    if (m_thumbIdx >= 0)
        return; // ya en curso
    m_thumbLog.clear();
    m_thumbDir = QDir::tempPath() + QStringLiteral("/mc-thumbs-%1").arg(::getpid());
    QDir().mkpath(m_thumbDir);
    m_thumbLog << QStringLiteral("dir=") + m_thumbDir;
    m_thumbIdx = 0;
    m_thumbCount = 0;
    m_hasThumbnails = false;
    m_workspaceThumb.clear();
    QTimer::singleShot(0, this, &KWinBackend::nextThumb);
}

void KWinBackend::nextThumb()
{
    if (m_thumbIdx < 0)
        return;
    if (m_thumbIdx == 0) {
        const QString err = captureTo(
            QStringLiteral("CaptureWorkspace"), {},
            m_thumbDir + QStringLiteral("/workspace.png"),
            QStringLiteral("workspace"));
        if (err.isEmpty()) {
            m_workspaceThumb =
                QStringLiteral("file://") + m_thumbDir + QStringLiteral("/workspace.png");
            m_thumbLog << QStringLiteral("workspace OK (thumb activo)");
        } else {
            m_thumbLog << QStringLiteral("workspace FALLO: ") + err;
        }
        Q_EMIT windowsChanged();
        ++m_thumbIdx;
        QTimer::singleShot(0, this, &KWinBackend::nextThumb);
        return;
    }
    const int wi = m_thumbIdx - 1;
    if (wi >= m_windows.size() || wi >= 10) {
        m_thumbLog << QStringLiteral("fin: %1 ventanas con thumb").arg(m_thumbCount);
        m_thumbIdx = -1;
        if (!m_hasThumbnails)
            setError(QStringLiteral("ScreenShot2 sin imagen; fallback icono+título"));
        else
            setError(QString());
        Q_EMIT windowsChanged();
        return;
    }
    const QVariantMap w = m_windows.at(wi).toMap();
    const QString id = w.value("id").toString();
    // Handle = internalId tal cual lo devuelve el scripting (UUID en Plasma 6).
    const QString err = captureTo(
        QStringLiteral("CaptureWindow"), {id},
        m_thumbDir + QStringLiteral("/win-%1.png").arg(wi),
        QStringLiteral("win %1 (%2)").arg(wi).arg(id));
    if (err.isEmpty()) {
        ++m_thumbCount;
        m_hasThumbnails = true;
        setWindowThumb(id, QStringLiteral("file://") + m_thumbDir
                                 + QStringLiteral("/win-%1.png").arg(wi));
        m_thumbLog << QStringLiteral("win %1 (%2) OK").arg(wi).arg(id);
    } else {
        m_thumbLog << QStringLiteral("win %1 (%2) FALLO: ").arg(wi).arg(id) + err;
    }
    ++m_thumbIdx;
    QTimer::singleShot(0, this, &KWinBackend::nextThumb);
}
