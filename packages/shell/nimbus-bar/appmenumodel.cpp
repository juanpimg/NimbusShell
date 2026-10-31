// AppMenuModel (F3-T06). Ver appmenumodel.h para el canal y límites.
#include "appmenumodel.h"
#include <QCoreApplication>
#include <QDBusReply>
#include <QStandardPaths>
#include <QTextStream>
#include <QXmlStreamReader>

namespace {
const char kRegistrar[] = "com.canonical.AppMenu.Registrar";
const char kDbusMenu[] = "com.canonical.dbusmenu";
const char kOurService[] = "org.nimbus.bar";
const char kOurPath[] = "/Bar";

const char kProbeJs[] =
    "function rep(s){callDBus(\"org.nimbus.bar\",\"/Bar\",\"org.nimbus.bar\",\"reportActive\",s);}\n"
    "try{var w=workspace.activeWindow;if(!w)rep(\"none\");\n"
    "else rep(w.caption+\"|\"+w.resourceClass+\"|\"+w.pid);}\n"
    "catch(e){rep(\"err \"+e);}\n";

QString prettyAppName(const QString &resourceClass)
{
    QString b = resourceClass;
    if (b.startsWith(QStringLiteral("org.kde.")))
        b = b.mid(8);
    else if (b.contains(QLatin1Char('.')))
        b = b.split(QLatin1Char('.')).last();
    if (!b.isEmpty())
        b[0] = b[0].toUpper();
    return b;
}
} // namespace

AppMenuModel::AppMenuModel(bool logDbus, QObject *parent)
    : QObject(parent), m_logDbus(logDbus)
{
    qDBusRegisterMetaType<MenuNode>();
    QDBusConnection bus = QDBusConnection::sessionBus();
    m_busOwn = bus.registerService(QString::fromLatin1(kOurService));
    bus.registerObject(QString::fromLatin1(kOurPath), &m_probe,
                       QDBusConnection::ExportAllSlots);
    connect(&m_probe, &ActiveProbe::activeReported,
            this, &AppMenuModel::onActiveReported);
    connect(&m_poll, &QTimer::timeout, this, &AppMenuModel::onPoll);
    m_poll.setInterval(1000);
    m_probePath = QDir::tempPath() + QStringLiteral("/nimbus-bar-activewin.js");
    QFile f(m_probePath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QTextStream out(&f);
        out << kProbeJs;
        f.close();
    }
    m_poll.start();
    QTimer::singleShot(400, this, &AppMenuModel::refresh);
    log(QStringLiteral("init own-service=%1").arg(m_busOwn));
}

QString AppMenuModel::formatShortcut(const QVariant &v)
{
    // Qt exporta shortcut como aas (lista de secuencias); mostramos la 1ª.
    // OJO: solo sobrecargas const (las no-const abortan: datos recibidos
    // de solo lectura, ver nodeFromArg).
    QVariant cur = v;
    if (cur.userType() == qMetaTypeId<QDBusVariant>())
        cur = cur.value<QDBusVariant>().variant();
    if (cur.userType() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument a = cur.value<QDBusArgument>();
        QVariantList outer;
        a.beginArray();
        while (!a.atEnd()) {
            QStringList seq;
            a.beginArray();
            while (!a.atEnd()) {
                QString s;
                a >> s;
                seq.append(s);
            }
            a.endArray();
            outer.append(seq);
        }
        a.endArray();
        cur = outer;
    }
    while (cur.userType() == QVariant::List && !cur.toList().isEmpty())
        cur = cur.toList().first();
    if (cur.userType() == QVariant::StringList)
        return cur.toStringList().join(QLatin1Char('+'));
    if (cur.userType() == QVariant::List) {
        QStringList parts;
        for (const auto &p : cur.toList())
            parts.append(p.toString());
        return parts.join(QLatin1Char('+'));
    }
    return cur.toString();
}

void AppMenuModel::log(const QString &msg) const
{
    if (m_logDbus)
        qInfo().noquote() << QStringLiteral("appmenu: %1").arg(msg);
}

void AppMenuModel::refresh() { ensureScript(); }

void AppMenuModel::onPoll() { pollActive(); }

void AppMenuModel::pollActive()
{
    // KWin Script.run() solo ejecuta una vez por script cargado: ciclo
    // load -> run (bloqueante, el script es trivial) -> unload por poll.
    if (m_pollBusy)
        return;
    m_pollBusy = true;
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusMessage load = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
        QStringLiteral("org.kde.kwin.Scripting"), QStringLiteral("loadScript"));
    load << m_probePath << QStringLiteral("nimbus-bar-active");
    QDBusMessage rep = bus.call(load);
    if (rep.type() != QDBusMessage::ReplyMessage || rep.arguments().isEmpty()) {
        m_pollBusy = false;
        return;
    }
    int id = rep.arguments().first().toInt();
    QDBusMessage run = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/Scripting/Script%1").arg(id),
        QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run"));
    bus.call(run);
    QDBusMessage unload = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
        QStringLiteral("org.kde.kwin.Scripting"), QStringLiteral("unloadScript"));
    unload << QStringLiteral("nimbus-bar-active");
    bus.call(unload);
    m_pollBusy = false;
}

void AppMenuModel::ensureScript()
{
    if (!QDBusConnection::sessionBus().interface()->isServiceRegistered(
            QStringLiteral("org.kde.KWin"))) {
        log(QStringLiteral("sin KWin: sin ventana activa"));
        return;
    }
    pollActive();
}

void AppMenuModel::onActiveReported(const QString &info)
{
    if (info == QStringLiteral("none")) {
        if (m_activePid != -1) {
            m_activePid = -1;
            m_appName = QStringLiteral("Nimbus");
            m_hasMenu = false;
            m_topLevel.clear();
            emit menusChanged();
        }
        return;
    }
    if (info.startsWith(QStringLiteral("err"))) {
        log(info);
        return;
    }
    const QStringList parts = info.split(QLatin1Char('|'));
    if (parts.size() < 3)
        return;
    bool ok = false;
    qlonglong pid = parts[2].toLongLong(&ok);
    if (!ok)
        return;
    // F3-T06-fix: las ventanas propias (barra, popup, scrim son layer-shell
    // pero KWin las reporta como activeWindow) nunca son "la app activa":
    // ignorar el pid propio para no perder el menú al abrir el popup.
    if (pid == QCoreApplication::applicationPid())
        return;
    QString name = prettyAppName(parts[1]);
    if (pid != m_activePid) {
        m_activePid = pid;
        m_appName = name.isEmpty() ? parts[0] : name;
        log(QStringLiteral("activa pid=%1 app=%2 cap=%3")
                .arg(pid)
                .arg(m_appName)
                .arg(parts[0].left(60)));
        discoverMenu();
    } else if (m_appName != name && !name.isEmpty()) {
        m_appName = name;
        emit menusChanged();
    }
}

void AppMenuModel::discoverMenu()
{
    m_hasMenu = false;
    m_topLevel.clear();
    // Cambio de app: cerrar submenú abierto (como macOS); el QML también
    // cierra su popup al ver menusChanged.
    m_submenu.clear();
    m_submenuTitle.clear();
    emit submenuChanged();
    m_service.clear();
    m_menuPath.clear();
    if (m_activePid <= 0) {
        emit menusChanged();
        return;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QStringList names = bus.interface()->registeredServiceNames().value();
    for (const QString &svc : names) {
        if (svc.startsWith(QStringLiteral(":"))
            || svc.startsWith(QStringLiteral("org.freedesktop"))
            || svc.startsWith(QStringLiteral("org.kde.KWin"))
            || svc == QString::fromLatin1(kOurService)
            || svc == QStringLiteral("org.nimbus.Probe"))
            continue;
        QDBusReply<uint> pidRep = bus.interface()->servicePid(svc);
        if (!pidRep.isValid() || (qlonglong)pidRep.value() != m_activePid)
            continue;
        // Introspección de /MenuBar: buscar hijo con com.canonical.dbusmenu.
        QDBusInterface bar(svc, QStringLiteral("/MenuBar"),
                           QStringLiteral("org.freedesktop.DBus.Introspectable"),
                           bus);
        QDBusReply<QString> xml = bar.call(QStringLiteral("Introspect"));
        if (!xml.isValid()) {
            log(QStringLiteral("candidato %1 /MenuBar introspect ERR %2")
                    .arg(svc, xml.error().message().left(80)));
            continue;
        }
        const QString &x = xml.value();
        // Hijos de /MenuBar vía QXmlStreamReader (robusto ante formato).
        QStringList kids;
        {
            QXmlStreamReader r(x);
            while (!r.atEnd()) {
                r.readNext();
                if (r.isStartElement() && r.name() == QLatin1String("node")) {
                    QString n = r.attributes().value(QStringLiteral("name")).toString();
                    if (!n.isEmpty())
                        kids.append(n);
                }
            }
            if (r.hasError())
                log(QStringLiteral("candidato %1 xml ERR %2").arg(svc, r.errorString().left(80)));
        }
        log(QStringLiteral("candidato %1 hijos=%2").arg(svc, kids.join(QLatin1Char(','))));
        for (const QString &child : kids) {
            QString cpath = QStringLiteral("/MenuBar/") + child;
            QDBusInterface ci(svc, cpath,
                              QStringLiteral("org.freedesktop.DBus.Introspectable"),
                              bus);
            QDBusReply<QString> cxml = ci.call(QStringLiteral("Introspect"));
            if (cxml.isValid()
                && cxml.value().contains(QString::fromLatin1(kDbusMenu))) {
                m_service = svc;
                m_menuPath = cpath;
                break;
            }
        }
        if (!m_service.isEmpty())
            break;
    }
    if (!m_service.isEmpty()) {
        log(QStringLiteral("menu %1 %2").arg(m_service, m_menuPath));
        if (!fetchTopLevel())
            m_service.clear();
    } else {
        log(QStringLiteral("pid %1 sin dbusmenu (GTK/in-window?)").arg(m_activePid));
    }
    m_hasMenu = !m_service.isEmpty();
    emit menusChanged();
}

QDBusInterface AppMenuModel::menuIface() const
{
    return QDBusInterface(m_service, m_menuPath, QString::fromLatin1(kDbusMenu),
                          QDBusConnection::sessionBus());
}

bool AppMenuModel::fetchTopLevel()
{
    QDBusInterface mi = menuIface();
    mi.setTimeout(2000);
    QDBusMessage rep = mi.call(QStringLiteral("GetLayout"), 0, -1, QStringList());
    if (rep.type() != QDBusMessage::ReplyMessage || rep.arguments().size() < 2) {
        log(QStringLiteral("GetLayout fallo: %1").arg(rep.errorMessage()));
        return false;
    }
    {
        const QVariant &a1 = rep.arguments().at(1);
        QString sig = QStringLiteral("?");
        if (a1.userType() == qMetaTypeId<QDBusArgument>())
            sig = a1.value<QDBusArgument>().currentSignature();
        log(QStringLiteral("GetLayout reply type=%1 sig=%2")
                .arg(QLatin1String(a1.typeName()), sig));
    }
    m_root = MenuNode();
    {
        // Lectura in situ del argumento original del reply (sin copias
        // intermedias que compartan el lector). Puntero CONST: las
        // sobrecargas no-const de QDBusArgument son de escritura y abortan
        // ("write from a read-only object", visto en nested 2026-10-31).
        QList<QVariant> args = rep.arguments();
        const QVariant &v = args.at(1);
        const QDBusArgument *pa = static_cast<const QDBusArgument *>(v.constData());
        nodeFromArg(*pa, m_root);
    }
    m_topLevel.clear();
    for (const auto &kid : m_root.children) {
        if (kid.props.value(QStringLiteral("visible"), true).toBool())
            m_topLevel.append(nodeToMap(kid, false));
    }
    log(QStringLiteral("GetLayout %1 tops=%2").arg(m_menuPath).arg(m_topLevel.size()));
    // LayoutUpdated -> refrescar (best-effort).
    QDBusConnection::sessionBus().connect(
        m_service, m_menuPath, QString::fromLatin1(kDbusMenu),
        QStringLiteral("LayoutUpdated"), this, SLOT(refresh()));
    return true;
}

void AppMenuModel::nodeFromList(const QVariantList &l, MenuNode &node)
{    // asVariant() de (ia{sv}av): [int id, QVariantMap props, QVariantList kids].
    if (l.size() < 3)
        return;
    node.id = l.at(0).toInt();
    node.props = l.at(1).toMap();
    const QVariantList kids = l.at(2).toList();
    for (const QVariant &k : kids) {
        MenuNode c;
        nodeFromList(k.toList(), c);
        node.children.append(c);
    }
}

void AppMenuModel::nodeFromArg(const QDBusArgument &a, MenuNode &node)
{
    // Parseo directo del struct (ia{sv}av) sobre el argumento original
    // del reply (sin copias intermedias). `a` es CONST a propósito.
    a.beginStructure();
    a >> node.id;
    a >> node.props;
    a.beginArray();
    while (!a.atEnd()) {
        QDBusVariant vw;
        a >> vw;
        QVariant inner = vw.variant();
        if (inner.userType() == qMetaTypeId<MenuNode>()) {
            node.children.append(inner.value<MenuNode>());
        } else if (inner.userType() == qMetaTypeId<QDBusArgument>()) {
            const QDBusArgument ca = inner.value<QDBusArgument>();
            MenuNode c;
            nodeFromArg(ca, c);
            node.children.append(c);
        }
    }
    a.endArray();
    a.endStructure();
}

QVariantMap AppMenuModel::nodeToMap(const MenuNode &n, bool withKids) const
{
    QVariantMap m;
    const QVariantMap &p = n.props;
    m[QStringLiteral("id")] = n.id;
    QString label = p.value(QStringLiteral("label")).toString();
    label.remove(QLatin1Char('_')); // mnemónicos Qt (&/ _)
    label.remove(QLatin1Char('&'));
    m[QStringLiteral("label")] = label;
    m[QStringLiteral("enabled")] = p.value(QStringLiteral("enabled"), true).toBool();
    m[QStringLiteral("separator")] =
        p.value(QStringLiteral("type")).toString() == QStringLiteral("separator");
    m[QStringLiteral("shortcut")] = formatShortcut(p.value(QStringLiteral("shortcut")));
    bool check = p.value(QStringLiteral("toggle-type")).toString()
            == QStringLiteral("checkmark")
        || p.value(QStringLiteral("toggle-type")).toString()
            == QStringLiteral("radio");
    m[QStringLiteral("checked")] =
        check && p.value(QStringLiteral("toggle-state"), 0).toInt() != 0;
    if (withKids) {
        QVariantList kids;
        for (const auto &c : n.children) {
            if (c.props.value(QStringLiteral("visible"), true).toBool())
                kids.append(nodeToMap(c, false));
        }
        m[QStringLiteral("kids")] = kids;
    } else {
        m[QStringLiteral("hasKids")] = !n.children.isEmpty();
    }
    return m;
}

void AppMenuModel::openSubmenu(int id)
{
    if (m_service.isEmpty())
        return;
    QDBusInterface mi = menuIface();
    mi.setTimeout(2000);
    mi.call(QStringLiteral("AboutToShow"), id); // best-effort
    QDBusMessage rep =
        mi.call(QStringLiteral("GetLayout"), id, 1, QStringList());
    QVariantList kids;
    QString title;
    if (rep.type() == QDBusMessage::ReplyMessage && rep.arguments().size() >= 2) {
        MenuNode sub;
        QDBusArgument arg = rep.arguments().at(1).value<QDBusArgument>();
        nodeFromList(arg.asVariant().toList(), sub);
        QString l = sub.props.value(QStringLiteral("label")).toString();
        l.remove(QLatin1Char('_'));
        l.remove(QLatin1Char('&'));
        title = l;
        for (const auto &c : sub.children) {
            if (c.props.value(QStringLiteral("visible"), true).toBool())
                kids.append(nodeToMap(c, true));
        }
    } else {
        // Fallback: subárbol cacheado del GetLayout raíz.
        std::function<void(const MenuNode &)> find = [&](const MenuNode &n) {
            for (const auto &c : n.children) {
                if (c.id == id) {
                    QString l = c.props.value(QStringLiteral("label")).toString();
                    l.remove(QLatin1Char('_'));
                    l.remove(QLatin1Char('&'));
                    title = l;
                    for (const auto &k : c.children) {
                        if (k.props.value(QStringLiteral("visible"), true)
                                .toBool())
                            kids.append(nodeToMap(k, true));
                    }
                    return;
                }
                find(c);
            }
        };
        find(m_root);
        log(QStringLiteral("openSubmenu(%1) fallback-cache kids=%2").arg(id).arg(kids.size()));
    }
    m_submenu = kids;
    m_submenuTitle = title;
    emit submenuChanged();
}

void AppMenuModel::backToTop() { openSubmenu(0); }

void AppMenuModel::trigger(int id)
{
    if (m_service.isEmpty())
        return;
    QDBusInterface mi = menuIface();
    mi.setTimeout(2000);
    uint ts = (uint)QDateTime::currentSecsSinceEpoch();
    QDBusMessage rep = mi.call(QStringLiteral("Event"), id,
                               QStringLiteral("clicked"),
                               QVariant::fromValue(QDBusVariant(QString())),
                               ts);
    if (rep.type() != QDBusMessage::ReplyMessage)
        log(QStringLiteral("Event(%1) fallo: %2").arg(id).arg(rep.errorMessage()));
    else
        log(QStringLiteral("Event(%1) clicked ok").arg(id));
    closeMenu();
}

void AppMenuModel::closeMenu()
{
    m_submenu.clear();
    m_submenuTitle.clear();
    emit submenuChanged();
}
