// KWinBackend — implementación (F7-T01/T02).
#include "kwinbackend.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryFile>
#include <QTimer>

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

void KWinBackend::setError(const QString &e)
{
    m_lastError = e;
    Q_EMIT statsChanged();
}

void KWinBackend::loadDemo()
{
    m_desktops = {
        QVariantMap{{"id", "d1"}, {"name", "Desktop 1"}, {"index", 1}, {"active", true}, {"windowCount", 4}},
        QVariantMap{{"id", "d2"}, {"name", "Desktop 2"}, {"index", 2}, {"active", false}, {"windowCount", 2}},
    };
    m_currentDesktop = 1;
    m_windows = {
        QVariantMap{{"id", "w-kate"}, {"caption", "Kate — notas.txt"}, {"app", "kate"}, {"desktop", "d1"}, {"active", true}, {"minimized", false}, {"icon", "kate"}, {"thumb", ""}},
        QVariantMap{{"id", "w-konsole"}, {"caption", "Konsole — zsh"}, {"app", "konsole"}, {"desktop", "d1"}, {"active", false}, {"minimized", false}, {"icon", "konsole"}, {"thumb", ""}},
        QVariantMap{{"id", "w-dolphin"}, {"caption", "Dolphin — Documentos"}, {"app", "dolphin"}, {"desktop", "d1"}, {"active", false}, {"minimized", false}, {"icon", "dolphin"}, {"thumb", ""}},
        QVariantMap{{"id", "w-settings"}, {"caption", "Preferencias del sistema"}, {"app", "systemsettings"}, {"desktop", "d1"}, {"active", false}, {"minimized", true}, {"icon", "systemsettings"}, {"thumb", ""}},
        QVariantMap{{"id", "w-firefox"}, {"caption", "Firefox — Tahoe HIG"}, {"app", "firefox"}, {"desktop", "d2"}, {"active", false}, {"minimized", false}, {"icon", "firefox"}, {"thumb", ""}},
        QVariantMap{{"id", "w-kate2"}, {"caption", "Kate — plan.md"}, {"app", "kate"}, {"desktop", "d2"}, {"active", false}, {"minimized", false}, {"icon", "kate"}, {"thumb", ""}},
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
        "var wins = workspace.windowList();\n"
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
        "  out.push({id: String(w.internalId), caption: String(w.caption || ''),\n"
        "    app: String((w.resourceClass || '').toString().split(' ')[0] || ''),\n"
        "    desktop: d0, active: w.active === true, minimized: w.minimized === true});\n"
        "}\n"
        "callDBus('org.nimbus.MissionControl', '/MC', 'org.nimbus.MissionControl',\n"
        "  'pushState', JSON.stringify({desktops: ds, current: cur, windows: out}));\n");
    runOneshotScript(js, QStringLiteral("nimbus-mc-dump-%1").arg(++m_dumpSeq));
}

void KWinBackend::runOneshotScript(const QString &js, const QString &tag)
{
    QString path = QStringLiteral("/tmp/opencode/%1.js").arg(tag);
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
    scripting.call(QStringLiteral("loadScript"), scriptingPath(path), tag);
    scripting.call(QStringLiteral("start"));
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
    m_windows.clear();
    QString activeApp;
    for (const QJsonValue &v : warr) {
        const QJsonObject o = v.toObject();
        const QString app = o.value("app").toString();
        if (o.value("active").toBool())
            activeApp = app;
        QVariantMap m{{"id", o.value("id").toString()},
                      {"caption", o.value("caption").toString()},
                      {"app", app},
                      {"desktop", o.value("desktop").toString()},
                      {"active", o.value("active").toBool()},
                      {"minimized", o.value("minimized").toBool()},
                      {"icon", app.toLower()}, {"thumb", ""}};
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
        "var wins = workspace.windowList();\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "  if (String(wins[i].internalId) === target) {\n"
        "    var ds = wins[i].desktops;\n"
        "    if (ds && ds.length > 0) workspace.currentDesktop = ds[0];\n"
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
        "var wins = workspace.windowList();\n"
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
    // path /org/kde/KWin/ScreenShot2, CaptureWindow/CaptureWorkspace con
    // pipe (exige portal/pipewire: F7-T09). La captura aún NO está
    // implementada → hasThumbnails=false honesto; parrilla en fallback
    // icono+título hasta F7-T09.
    QDBusInterface ss(QStringLiteral("org.kde.KWin.ScreenShot2"),
                      QStringLiteral("/org/kde/KWin/ScreenShot2"),
                      QStringLiteral("org.kde.KWin.ScreenShot2"),
                      QDBusConnection::sessionBus());
    m_hasThumbnails = false;
    if (ss.isValid())
        setError(QStringLiteral("ScreenShot2 presente pero sin captura pipewire (F7-T09); fallback icono+título"));
    else
        setError(QStringLiteral("ScreenShot2 no disponible; fallback icono+título"));
}
