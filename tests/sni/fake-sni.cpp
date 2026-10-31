// fake-sni (F3-T07): item SNI falso para el test nested. Uso:
//   fake-sni --service org.nimbus.FakeSniA --title "Nimbus A" --letter A
// Registra org.kde.StatusNotifierItem en /StatusNotifierItem con
// IconPixmap propio (letra sobre fondo, 32px), Title/Status/ToolTip, y
// menú com.canonical.dbusmenu en /Menu (info/acerca/Quit).
// Marshalling con structs registrados (qDBusRegisterMetaType), el único
// patrón soportado por Qt para a(iiay) / (sa(iiay)ss) / layouts.
#include <QCommandLineParser>
#include <QDBusAbstractAdaptor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDBusVirtualObject>
#include <QDebug>
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <cstdio>

static void logLine(const char *msg)
{
    fprintf(stderr, "fake-sni: %s\n", msg);
    fflush(stderr);
}

static QImage s_icon;
static QString s_title;
static QString s_letter;

// --- Tipos D-Bus registrados -------------------------------------------
struct SniPixmap {
    qint32 w = 0;
    qint32 h = 0;
    QByteArray bytes; // ARGB big-endian por píxel (spec SNI)
};
Q_DECLARE_METATYPE(SniPixmap)

QDBusArgument &operator<<(QDBusArgument &arg, const SniPixmap &p)
{
    arg.beginStructure();
    arg << p.w << p.h << p.bytes;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, SniPixmap &p)
{
    arg.beginStructure();
    arg >> p.w >> p.h >> p.bytes;
    arg.endStructure();
    return arg;
}

struct SniToolTip {
    QString icon;
    QList<SniPixmap> pixmaps;
    QString title;
    QString text;
};
Q_DECLARE_METATYPE(SniToolTip)

QDBusArgument &operator<<(QDBusArgument &arg, const SniToolTip &t)
{
    arg.beginStructure();
    arg << t.icon << t.pixmaps << t.title << t.text;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, SniToolTip &t)
{
    arg.beginStructure();
    arg >> t.icon >> t.pixmaps >> t.title >> t.text;
    arg.endStructure();
    return arg;
}

// Hoja del menú (entradas A-info/acerca/Quit). children es QStringList
// SIEMPRE vacío en el fake: el array vacío no lee elementos, así que su
// tipo de elemento es irrelevante para el parser y evita anidar structs
// custom (QtDBus lo soporta mal). Límite documentado en evidence/F3-T07.
struct MenuLeaf {
    qint32 id = 0;
    QVariantMap props;
    QStringList children;
};
Q_DECLARE_METATYPE(MenuLeaf)

QDBusArgument &operator<<(QDBusArgument &arg, const MenuLeaf &n)
{
    arg.beginStructure();
    arg << n.id << n.props << n.children;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, MenuLeaf &n)
{
    arg.beginStructure();
    arg >> n.id >> n.props >> n.children;
    arg.endStructure();
    return arg;
}

// Raíz del menú (hijos = entradas). Firmas finitas en todos los niveles.
struct MenuRoot {
    qint32 id = 0;
    QVariantMap props;
    QList<MenuLeaf> children;
};
Q_DECLARE_METATYPE(MenuRoot)

QDBusArgument &operator<<(QDBusArgument &arg, const MenuRoot &n)
{
    arg.beginStructure();
    arg << n.id << n.props << n.children;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, MenuRoot &n)
{
    arg.beginStructure();
    arg >> n.id >> n.props >> n.children;
    arg.endStructure();
    return arg;
}

struct MenuLayout {
    quint32 rev = 0;
    MenuRoot root;
};
Q_DECLARE_METATYPE(MenuLayout)

QDBusArgument &operator<<(QDBusArgument &arg, const MenuLayout &l)
{
    arg.beginStructure();
    arg << l.rev << l.root;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, MenuLayout &l)
{
    arg.beginStructure();
    arg >> l.rev >> l.root;
    arg.endStructure();
    return arg;
}

// --- Adaptadores --------------------------------------------------------
class ItemAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierItem")
public:
    explicit ItemAdaptor(QObject *o) : QDBusAbstractAdaptor(o) {}
public slots:
    Q_NOREPLY void Activate(int x, int y)
    {
        // fprintf (no qInfo: este Qt no vuelca qInfo sin handler).
        fprintf(stderr, "fake-sni: Activate %s %d %d\n",
                s_title.toUtf8().constData(), x, y);
        fflush(stderr);
    }
    Q_NOREPLY void ContextMenu(int, int)
    {
        fprintf(stderr, "fake-sni: ContextMenu %s\n",
                s_title.toUtf8().constData());
        fflush(stderr);
    }
    Q_NOREPLY void SecondaryActivate(int, int) {}
    Q_NOREPLY void Scroll(int, const QString &) {}
signals:
    void NewIcon();
    void NewTitle();
    void NewStatus(const QString &status);
    void NewToolTip();
};

static SniPixmap currentPixmap()
{
    SniPixmap p;
    p.w = s_icon.width();
    p.h = s_icon.height();
    p.bytes.resize(p.w * p.h * 4);
    auto *d = reinterpret_cast<unsigned char *>(p.bytes.data());
    for (int y = 0; y < p.h; ++y) {
        const auto *row =
            reinterpret_cast<const QRgb *>(s_icon.constScanLine(y));
        for (int x = 0; x < p.w; ++x) {
            const int o = (y * p.w + x) * 4;
            d[o] = static_cast<unsigned char>(qAlpha(row[x]));
            d[o + 1] = static_cast<unsigned char>(qRed(row[x]));
            d[o + 2] = static_cast<unsigned char>(qGreen(row[x]));
            d[o + 3] = static_cast<unsigned char>(qBlue(row[x]));
        }
    }
    return p;
}

// PropsAdaptor: org.freedesktop.DBus.Properties explícito (Q_PROPERTY no
// puede exponer a(iiay) ni (sa(iiay)ss)).
class PropsAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.DBus.Properties")
public:
    explicit PropsAdaptor(QObject *o) : QDBusAbstractAdaptor(o) {}
    static QVariantMap allProps()
    {
        QVariantMap m;
        m[QStringLiteral("Id")] = s_title;
        m[QStringLiteral("Category")] = QStringLiteral("ApplicationStatus");
        m[QStringLiteral("Title")] = s_title;
        m[QStringLiteral("Status")] = QStringLiteral("Active");
        m[QStringLiteral("IconName")] = QString();
        m[QStringLiteral("IconThemePath")] = QString();
        m[QStringLiteral("ItemIsMenu")] = false;
        m[QStringLiteral("WindowId")] = 0;
        m[QStringLiteral("Menu")] =
            QVariant::fromValue(QDBusObjectPath(QStringLiteral("/Menu")));
        m[QStringLiteral("IconPixmap")] =
            QVariant::fromValue(QList<SniPixmap>{currentPixmap()});
        SniToolTip tt;
        tt.title = s_title;
        tt.text = s_title + QStringLiteral(" tooltip");
        m[QStringLiteral("ToolTip")] = QVariant::fromValue(tt);
        return m;
    }
public slots:
    QDBusVariant Get(const QString &, const QString &prop)
    {
        return QDBusVariant(allProps().value(prop));
    }
    QVariantMap GetAll(const QString &) { return allProps(); }
    Q_NOREPLY void Set(const QString &, const QString &, const QDBusVariant &)
    {
    }
};

// MenuVirtual: sirve com.canonical.dbusmenu con la forma REAL del
// protocolo (GetLayout: dos out-args u revision + struct layout) vía
// QDBusVirtualObject. Los adaptadores Qt no pueden firmar retornos
// struct custom anidados (emiten type="" y la respuesta sale vacía);
// la respuesta manual con operator<< registrado sí funciona.
// Límite del fake: los hijos de las hojas son `as` vacío en vez de
// a(iai{sv}av) recursivo (Qt no firma tipos recursivos); los arrays
// vacíos no leen elementos, así que el parser genérico no lo nota.
class MenuVirtual : public QDBusVirtualObject {
public:
    QString introspect(const QString &) const override
    {
        return QStringLiteral(
            "<interface name=\"com.canonical.dbusmenu\">"
            "<method name=\"GetLayout\">"
            "<arg direction=\"in\" type=\"i\"/>"
            "<arg direction=\"in\" type=\"i\"/>"
            "<arg direction=\"in\" type=\"as\"/>"
            "<arg direction=\"out\" type=\"u\"/>"
            "<arg direction=\"out\" type=\"(ia{sv}a(ia{sv}as))\"/>"
            "</method>"
            "<method name=\"AboutToShow\">"
            "<arg direction=\"in\" type=\"i\"/>"
            "<arg direction=\"out\" type=\"b\"/>"
            "</method>"
            "<method name=\"Event\">"
            "<arg direction=\"in\" type=\"i\"/>"
            "<arg direction=\"in\" type=\"s\"/>"
            "<arg direction=\"in\" type=\"v\"/>"
            "<arg direction=\"in\" type=\"u\"/>"
            "</method>"
            "<property name=\"Version\" type=\"u\" access=\"read\"/>"
            "<property name=\"Status\" type=\"s\" access=\"read\"/>"
            "</interface>");
    }
    static MenuLayout layout()
    {
        MenuLayout l;
        l.rev = 1;
        auto entry = [](int id, const QString &label) {
            MenuLeaf n;
            n.id = id;
            n.props[QStringLiteral("label")] = label;
            n.props[QStringLiteral("enabled")] = true;
            n.props[QStringLiteral("visible")] = true;
            return n;
        };
        l.root.children = {entry(1, s_title + QStringLiteral(" info")),
                           entry(2, s_title + QStringLiteral(" acerca")),
                           entry(99, QStringLiteral("Quit"))};
        return l;
    }
    bool handleMessage(const QDBusMessage &message,
                       const QDBusConnection &connection) override
    {
        if (message.interface() != QLatin1String("com.canonical.dbusmenu")
            && message.interface()
                != QLatin1String("org.freedesktop.DBus.Properties"))
            return false;
        const QString member = message.member();
        if (member == QLatin1String("GetLayout")) {
            const MenuLayout l = layout();
            QDBusMessage reply = message.createReply();
            reply << l.rev << QVariant::fromValue(l.root);
            connection.send(reply);
            return true;
        }
        if (member == QLatin1String("AboutToShow")) {
            QDBusMessage reply = message.createReply(false);
            connection.send(reply);
            return true;
        }
        if (member == QLatin1String("Event")) {
            const QVariantList args = message.arguments();
            const int id = args.value(0).toInt();
            fprintf(stderr, "fake-sni: Event id=%d %s %s\n", id,
                    args.value(1).toString().toUtf8().constData(),
                    s_title.toUtf8().constData());
            fflush(stderr);
            connection.send(message.createReply());
            if (id == 99)
                QGuiApplication::quit();
            return true;
        }
        if (member == QLatin1String("Get")
            && args0(message) == QLatin1String("Version")) {
            QDBusMessage reply = message.createReply(
                QVariant::fromValue(QDBusVariant(quint32(3))));
            connection.send(reply);
            return true;
        }
        if (member == QLatin1String("Get")
            && args0(message) == QLatin1String("Status")) {
            QDBusMessage reply = message.createReply(
                QVariant::fromValue(QDBusVariant(QStringLiteral("normal"))));
            connection.send(reply);
            return true;
        }
        return false;
    }
private:
    static QString args0(const QDBusMessage &m)
    {
        // Get(iface, prop): nos interesa el 2º arg, pero filtramos por
        // interfaz dbusmenu (el 1º siempre es com.canonical.dbusmenu).
        return m.arguments().value(1).toString();
    }
};

static QImage makeIcon(const QString &letter, const QColor &bg)
{
    QImage img(32, 32, QImage::Format_ARGB32);
    img.fill(Qt::transparent);
    QPainter pt(&img);
    pt.setRenderHint(QPainter::Antialiasing);
    pt.setBrush(bg);
    pt.setPen(Qt::NoPen);
    pt.drawEllipse(0, 0, 32, 32);
    pt.setPen(Qt::white);
    QFont f(QStringLiteral("Sans"));
    f.setPixelSize(18);
    f.setBold(true);
    pt.setFont(f);
    pt.drawText(img.rect(), Qt::AlignCenter, letter);
    return img;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    logLine("arranque");
    qDBusRegisterMetaType<SniPixmap>();
    qDBusRegisterMetaType<QList<SniPixmap>>();
    qDBusRegisterMetaType<SniToolTip>();
    qDBusRegisterMetaType<MenuLeaf>();
    qDBusRegisterMetaType<QList<MenuLeaf>>();
    qDBusRegisterMetaType<MenuRoot>();
    qDBusRegisterMetaType<MenuLayout>();
    QCommandLineParser p;
    p.addOption({QStringLiteral("service"), QString(), QStringLiteral("s")});
    p.addOption({QStringLiteral("title"), QString(), QStringLiteral("t")});
    p.addOption({QStringLiteral("letter"), QString(), QStringLiteral("l")});
    p.addOption(QCommandLineOption(QStringLiteral("stay")));
    p.process(app);
    const QString svc = p.value(QStringLiteral("service"));
    s_title = p.value(QStringLiteral("title"));
    s_letter = p.value(QStringLiteral("letter"));
    if (svc.isEmpty() || s_title.isEmpty() || s_letter.isEmpty()) {
        logLine("faltan args");
        return 2;
    }
    const bool isA = s_letter == QStringLiteral("A");
    s_icon = makeIcon(s_letter,
                      isA ? QColor(0x0A, 0x84, 0xFF) : QColor(0x30, 0xD1, 0x58));
    logLine("icono OK");

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(svc)) {
        logLine("no registra servicio");
        return 1;
    }
    logLine("servicio OK");
    QObject itemObj;
    auto *menuVirtual = new MenuVirtual;
    new ItemAdaptor(&itemObj);
    new PropsAdaptor(&itemObj);
    if (!bus.registerObject(QStringLiteral("/StatusNotifierItem"), &itemObj,
                            QDBusConnection::ExportAdaptors)) {
        logLine("no registra objeto item");
        return 1;
    }
    if (!bus.registerVirtualObject(QStringLiteral("/Menu"), menuVirtual)) {
        logLine("no registra objeto menu");
        return 1;
    }
    logLine("objetos OK");
    QDBusMessage call = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("/StatusNotifierWatcher"),
        QStringLiteral("org.kde.StatusNotifierWatcher"),
        QStringLiteral("RegisterStatusNotifierItem"));
    call.setArguments({svc});
    QDBusMessage rep = bus.call(call);
    if (rep.type() == QDBusMessage::ErrorMessage) {
        qWarning().noquote() << "fake-sni: watcher ausente:"
                             << rep.errorMessage();
        if (!p.isSet(QStringLiteral("stay")))
            return 1;
    }
    qInfo().noquote() << "fake-sni: registrado" << svc << s_title
                      << "DEPLOY_OK";
    return app.exec();
}

#include "fake-sni.moc"
