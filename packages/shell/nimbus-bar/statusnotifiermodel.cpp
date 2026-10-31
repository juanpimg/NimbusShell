// StatusNotifierModel (F3-T07): implementación del protocolo SNI.
// Referencia: spec StatusNotifierItem (kde.org), verificado en el host
// contra org.kde.StatusNotifierWatcher real (ver evidence/F3-T07).
//
// NOTA Qt 6.12 (verificado con probes en /tmp/dbusprobe): el descenso
// manual de QDBusArgument sobre copias user-side está roto (atEnd
// inmediato en arrays, lecturas a defaults, abort en structs). SÍ
// funciona: QDBusReply<T>/qdbus_cast<T> con tipos registrados, y
// libdbus-1 directo. Por eso:
//  - IconPixmap/ToolTip se demarshalan con qdbus_cast (tipos fijos).
//  - GetLayout (layout RECURSIVO, imposible de registrar: Qt no firma
//    tipos recursivos) se lee con libdbus-1 (DBusMessageIter).
#include "statusnotifiermodel.h"

#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusReply>
#include <QDBusVariant>
#include <QIcon>
#include <QPainter>
#include <QTimer>
#include <dbus/dbus.h>

namespace {
const QString kWatcherSvc = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString kWatcherPath = QStringLiteral("/StatusNotifierWatcher");
const QString kWatcherIface = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString kItemIface = QStringLiteral("org.kde.StatusNotifierItem");
const QString kPropsIface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString kMenuIface = QStringLiteral("com.canonical.dbusmenu");
} // namespace

// --- Tipos fijos del protocolo (firmas no recursivas) -------------------
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

StatusNotifierModel::StatusNotifierModel(QObject *parent)
    : QAbstractListModel(parent)
{
    qDBusRegisterMetaType<SniPixmap>();
    qDBusRegisterMetaType<QList<SniPixmap>>();
    qDBusRegisterMetaType<SniToolTip>();
    m_watcher = new QDBusInterface(kWatcherSvc, kWatcherPath, kWatcherIface,
                                   QDBusConnection::sessionBus(), this);
    // Lista inicial (prop RegisteredStatusNotifierItems: "servicio/ruta").
    QVariant v = m_watcher->property("RegisteredStatusNotifierItems");
    const QStringList initial = v.toStringList();
    for (const QString &sp : initial) {
        QString svc, path;
        splitServicePath(sp, svc, path);
        if (!svc.isEmpty() && !path.isEmpty())
            addItem(svc, path);
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(kWatcherSvc, kWatcherPath, kWatcherIface,
                QStringLiteral("StatusNotifierItemRegistered"), this,
                SLOT(onItemRegistered(QString)));
    bus.connect(kWatcherSvc, kWatcherPath, kWatcherIface,
                QStringLiteral("StatusNotifierItemUnregistered"), this,
                SLOT(onItemUnregistered(QString)));
}

void StatusNotifierModel::splitServicePath(const QString &in, QString &service,
                                           QString &path)
{
    const int slash = in.indexOf(QLatin1Char('/'));
    if (slash <= 0) {
        service.clear();
        path.clear();
        return;
    }
    service = in.left(slash);
    path = in.mid(slash); // incluye la '/' inicial
}

int StatusNotifierModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant StatusNotifierModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();
    const SniItem &it = m_items.at(index.row());
    switch (role) {
    case ServiceRole:
        return it.service;
    case PathRole:
        return it.path;
    case TitleRole:
        return it.title;
    case IconNameRole:
        return it.iconName;
    case ToolTipRole:
        return it.tooltip;
    case StatusRole:
        return it.status;
    case HasMenuRole:
        return !it.menuPath.isEmpty();
    case IconUidRole:
        return it.uid;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> StatusNotifierModel::roleNames() const
{
    return {
        {ServiceRole, "service"},
        {PathRole, "path"},
        {TitleRole, "title"},
        {IconNameRole, "iconName"},
        {ToolTipRole, "tooltip"},
        {StatusRole, "status"},
        {HasMenuRole, "hasMenu"},
        {IconUidRole, "iconUid"},
    };
}

QDBusInterface
StatusNotifierModel::itemPropIface(const SniItem &it) const
{
    return QDBusInterface(it.service, it.path, kPropsIface,
                          QDBusConnection::sessionBus());
}

void StatusNotifierModel::addItem(const QString &service, const QString &path)
{
    const QString uid = service + path;
    if (m_uidRow.contains(uid))
        return;
    SniItem it;
    it.service = service;
    it.path = path;
    it.uid = uid;
    refreshItem(it);
    // Señales de cambio del item -> refresco de esa fila.
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(service, path, kItemIface, QStringLiteral("NewIcon"), this,
                SLOT(onItemChanged()));
    bus.connect(service, path, kItemIface, QStringLiteral("NewTitle"), this,
                SLOT(onItemChanged()));
    bus.connect(service, path, kItemIface, QStringLiteral("NewStatus"), this,
                SLOT(onItemChanged()));
    bus.connect(service, path, kItemIface, QStringLiteral("NewToolTip"), this,
                SLOT(onItemChanged()));
    bus.connect(service, path, kPropsIface,
                QStringLiteral("PropertiesChanged"), this,
                SLOT(onItemChanged()));
    beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
    m_items.append(it);
    m_uidRow[uid] = m_items.size() - 1;
    endInsertRows();
    emit countChanged();
}

void StatusNotifierModel::removeItem(const QString &uid)
{
    if (!m_uidRow.contains(uid))
        return;
    const int row = m_uidRow.take(uid);
    beginRemoveRows(QModelIndex(), row, row);
    m_items.removeAt(row);
    endRemoveRows();
    m_uidRow.clear();
    for (int i = 0; i < m_items.size(); ++i)
        m_uidRow[m_items[i].uid] = i;
    emit countChanged();
}

void StatusNotifierModel::onItemRegistered(const QString &servicePath)
{
    QString svc, path;
    splitServicePath(servicePath, svc, path);
    if (!svc.isEmpty() && !path.isEmpty())
        addItem(svc, path);
}

void StatusNotifierModel::onItemUnregistered(const QString &servicePath)
{
    QString svc, path;
    splitServicePath(servicePath, svc, path);
    if (!svc.isEmpty())
        removeItem(svc + path);
}

void StatusNotifierModel::onItemChanged()
{
    // Relee props de todos los items (barato: <10 items típico).
    for (int r = 0; r < m_items.size(); ++r) {
        refreshItem(m_items[r]);
        const QModelIndex idx = index(r, 0);
        emit dataChanged(idx, idx);
    }
}

void StatusNotifierModel::refreshItem(SniItem &it)
{
    QDBusInterface props = itemPropIface(it);
    if (!props.isValid())
        return;
    QDBusReply<QVariantMap> reply = props.call(
        QStringLiteral("GetAll"), kItemIface);
    if (!reply.isValid())
        return;
    const QVariantMap m = reply.value();
    it.title = m.value(QStringLiteral("Title")).toString();
    it.iconName = m.value(QStringLiteral("IconName")).toString();
    it.iconThemePath = m.value(QStringLiteral("IconThemePath")).toString();
    it.status = m.value(QStringLiteral("Status")).toString();
    it.tooltip = decodeToolTip(m.value(QStringLiteral("ToolTip")));
    it.pixmap = decodePixmap(m.value(QStringLiteral("IconPixmap")));
    const QVariant menu = m.value(QStringLiteral("Menu"));
    it.menuPath.clear();
    if (menu.userType() == qMetaTypeId<QDBusObjectPath>())
        it.menuPath = menu.value<QDBusObjectPath>().path();
    else if (menu.typeId() == QMetaType::QString)
        it.menuPath = menu.toString();
    if (it.title.isEmpty())
        it.title = m.value(QStringLiteral("Id")).toString();
}

QString StatusNotifierModel::decodeToolTip(const QVariant &v)
{
    // ToolTip: (sa(iiay)ss) = (icon-name, pixmaps, title, text).
    const SniToolTip tt = qdbus_cast<SniToolTip>(v);
    if (!tt.title.isEmpty() && !tt.text.isEmpty())
        return tt.title + QStringLiteral(" — ") + tt.text;
    return tt.title + tt.text;
}

QImage StatusNotifierModel::decodePixmap(const QVariant &v)
{
    // IconPixmap: a(iiay); se elige la entrada de mayor resolución.
    const QList<SniPixmap> list = qdbus_cast<QList<SniPixmap>>(v);
    int best = -1;
    QImage out;
    for (const SniPixmap &p : list) {
        if (p.w <= 0 || p.h <= 0 || p.bytes.size() < p.w * p.h * 4)
            continue;
        if (p.w * p.h <= best)
            continue;
        best = p.w * p.h;
        // Bytes en orden ARGB big-endian (spec SNI); decodificación
        // explícita por píxel (independiente del endianness del host).
        QImage img(p.w, p.h, QImage::Format_ARGB32);
        const auto *d =
            reinterpret_cast<const unsigned char *>(p.bytes.constData());
        for (int y = 0; y < p.h; ++y) {
            auto *row = reinterpret_cast<QRgb *>(img.scanLine(y));
            for (int x = 0; x < p.w; ++x) {
                const int o = (y * p.w + x) * 4;
                row[x] = qRgba(d[o + 1], d[o + 2], d[o + 3], d[o]);
            }
        }
        out = img;
    }
    return out;
}

QImage StatusNotifierModel::badgeFor(const QString &title,
                                     const QSize &size)
{
    // Badge propio (sin activos externos): círculo gris + inicial.
    const int s = qMax(16, qMax(size.width(), size.height()));
    QImage img(s, s, QImage::Format_ARGB32);
    img.fill(Qt::transparent);
    QPainter pt(&img);
    pt.setRenderHint(QPainter::Antialiasing);
    pt.setBrush(QColor(0x8E, 0x8E, 0x93));
    pt.setPen(Qt::NoPen);
    pt.drawEllipse(0, 0, s, s);
    pt.setPen(Qt::white);
    QFont f(QStringLiteral("Sans"));
    f.setPixelSize(s * 9 / 16);
    f.setBold(true);
    pt.setFont(f);
    const QString letter =
        title.isEmpty() ? QStringLiteral("?") : title.left(1).toUpper();
    pt.drawText(img.rect(), Qt::AlignCenter, letter);
    return img;
}

QImage StatusNotifierModel::imageFor(const QString &uid,
                                     const QSize &size) const
{
    for (const SniItem &it : m_items) {
        if (it.uid != uid)
            continue;
        if (!it.pixmap.isNull())
            return it.pixmap.scaled(size, Qt::KeepAspectRatio,
                                    Qt::SmoothTransformation);
        if (!it.iconName.isEmpty()) {
            if (!it.iconThemePath.isEmpty())
                QIcon::setThemeSearchPaths(
                    QIcon::themeSearchPaths() << it.iconThemePath);
            const QIcon ic = QIcon::fromTheme(it.iconName);
            if (!ic.isNull())
                return ic.pixmap(size).toImage();
        }
        return badgeFor(it.title, size);
    }
    return QImage();
}

const SniItem *StatusNotifierModel::at(int row) const
{
    if (row < 0 || row >= m_items.size())
        return nullptr;
    return &m_items.at(row);
}

void StatusNotifierModel::activate(int row)
{
    const SniItem *it = at(row);
    if (!it)
        return;
    QDBusInterface iface(it->service, it->path, kItemIface,
                         QDBusConnection::sessionBus());
    iface.asyncCall(QStringLiteral("Activate"), 0, 0);
}

void StatusNotifierModel::contextMenu(int row)
{
    const SniItem *it = at(row);
    if (!it)
        return;
    QDBusInterface iface(it->service, it->path, kItemIface,
                         QDBusConnection::sessionBus());
    iface.asyncCall(QStringLiteral("ContextMenu"), 0, 0);
}

namespace {
// --- Lector dbusmenu con libdbus-1 (ver NOTA Qt 6.12 arriba) ---------
QVariantMap parseDbusMenuNode(DBusMessageIter *parent)
{
    // Nodo: struct(int32 id, array{dict(string,variant)} props,
    //              array(struct...) children).
    QVariantMap out;
    DBusMessageIter st;
    dbus_message_iter_recurse(parent, &st);
    if (dbus_message_iter_get_arg_type(&st) != DBUS_TYPE_INT32)
        return out;
    dbus_int32_t id = 0;
    dbus_message_iter_get_basic(&st, &id);
    out[QStringLiteral("id")] = id;
    QString label;
    bool enabled = true;
    if (dbus_message_iter_next(&st)
        && dbus_message_iter_get_arg_type(&st) == DBUS_TYPE_ARRAY) {
        DBusMessageIter dict;
        dbus_message_iter_recurse(&st, &dict);
        while (dbus_message_iter_get_arg_type(&dict)
               == DBUS_TYPE_DICT_ENTRY) {
            DBusMessageIter entry;
            dbus_message_iter_recurse(&dict, &entry);
            const char *key = nullptr;
            if (dbus_message_iter_get_arg_type(&entry) == DBUS_TYPE_STRING) {
                dbus_message_iter_get_basic(&entry, &key);
                if (dbus_message_iter_next(&entry)
                    && dbus_message_iter_get_arg_type(&entry)
                        == DBUS_TYPE_VARIANT) {
                    DBusMessageIter var;
                    dbus_message_iter_recurse(&entry, &var);
                    const int vt = dbus_message_iter_get_arg_type(&var);
                    if (key && qstrcmp(key, "label") == 0
                        && vt == DBUS_TYPE_STRING) {
                        const char *s = nullptr;
                        dbus_message_iter_get_basic(&var, &s);
                        label = QString::fromUtf8(s ? s : "");
                    } else if (key && qstrcmp(key, "enabled") == 0
                               && vt == DBUS_TYPE_BOOLEAN) {
                        dbus_bool_t b = true;
                        dbus_message_iter_get_basic(&var, &b);
                        enabled = b;
                    }
                }
            }
            dbus_message_iter_next(&dict);
        }
    }
    out[QStringLiteral("label")] = label;
    out[QStringLiteral("enabled")] = enabled;
    QVariantList kids;
    if (dbus_message_iter_next(&st)
        && dbus_message_iter_get_arg_type(&st) == DBUS_TYPE_ARRAY) {
        DBusMessageIter arr;
        dbus_message_iter_recurse(&st, &arr);
        while (dbus_message_iter_get_arg_type(&arr) == DBUS_TYPE_STRUCT) {
            kids.append(parseDbusMenuNode(&arr));
            dbus_message_iter_next(&arr);
        }
    }
    out[QStringLiteral("children")] = kids;
    return out;
}

// Aplana el árbol dbusmenu a filas clicables [{id,label,enabled}].
void flattenMenu(const QVariantMap &node, QVariantList &rows)
{
    const QString label = node.value(QStringLiteral("label")).toString();
    const QVariantList kids =
        node.value(QStringLiteral("children")).toList();
    if (!label.isEmpty() || kids.isEmpty()) {
        if (!label.isEmpty())
            rows.append(node);
        for (const QVariant &k : kids)
            flattenMenu(k.toMap(), rows);
    } else {
        for (const QVariant &k : kids)
            flattenMenu(k.toMap(), rows);
    }
}
} // namespace

QVariantList StatusNotifierModel::fetchMenu(int row)
{
    QVariantList rows;
    const SniItem *it = at(row);
    if (!it || it->menuPath.isEmpty())
        return rows;
    DBusError err;
    dbus_error_init(&err);
    DBusConnection *conn = dbus_bus_get(DBUS_BUS_SESSION, &err);
    if (!conn || dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        return rows;
    }
    // AboutToShow(0) según spec (best-effort).
    {
        DBusMessage *about = dbus_message_new_method_call(
            it->service.toUtf8().constData(), it->menuPath.toUtf8().constData(),
            "com.canonical.dbusmenu", "AboutToShow");
        dbus_int32_t zero = 0;
        dbus_message_append_args(about, DBUS_TYPE_INT32, &zero,
                                 DBUS_TYPE_INVALID);
        DBusMessage *aboutRep = dbus_connection_send_with_reply_and_block(
            conn, about, 2000, nullptr);
        if (aboutRep)
            dbus_message_unref(aboutRep);
        dbus_message_unref(about);
    }
    DBusMessage *call = dbus_message_new_method_call(
        it->service.toUtf8().constData(), it->menuPath.toUtf8().constData(),
        "com.canonical.dbusmenu", "GetLayout");
    {
        dbus_int32_t parentId = 0, depth = -1;
        const char *props[2] = {"label", "enabled"};
        DBusMessageIter ai, arr;
        dbus_message_iter_init_append(call, &ai);
        dbus_message_iter_append_basic(&ai, DBUS_TYPE_INT32, &parentId);
        dbus_message_iter_append_basic(&ai, DBUS_TYPE_INT32, &depth);
        dbus_message_iter_open_container(&ai, DBUS_TYPE_ARRAY, "s", &arr);
        dbus_message_iter_append_basic(&arr, DBUS_TYPE_STRING, &props[0]);
        dbus_message_iter_append_basic(&arr, DBUS_TYPE_STRING, &props[1]);
        dbus_message_iter_close_container(&ai, &arr);
    }
    DBusMessage *rep = dbus_connection_send_with_reply_and_block(
        conn, call, 3000, nullptr);
    dbus_message_unref(call);
    if (rep) {
        DBusMessageIter ri;
        if (dbus_message_iter_init(rep, &ri)
            && dbus_message_iter_get_arg_type(&ri) == DBUS_TYPE_UINT32
            && dbus_message_iter_next(&ri)
            && dbus_message_iter_get_arg_type(&ri) == DBUS_TYPE_STRUCT) {
            flattenMenu(parseDbusMenuNode(&ri), rows);
        }
        dbus_message_unref(rep);
    }
    dbus_connection_unref(conn);
    return rows;
}

void StatusNotifierModel::triggerMenuAction(int row, int id)
{
    const SniItem *it = at(row);
    if (!it || it->menuPath.isEmpty())
        return;
    QDBusInterface menu(it->service, it->menuPath, kMenuIface,
                        QDBusConnection::sessionBus());
    menu.asyncCall(QStringLiteral("Event"), id,
                   QStringLiteral("clicked"),
                   QVariant::fromValue(QDBusVariant(QString())),
                   static_cast<quint32>(0));
}

void StatusNotifierModel::seedDemoItems()
{
    // Solo si el watcher sigue vacío (fallback determinista nested).
    if (!m_items.isEmpty())
        return;
    for (int i = 0; i < 2; ++i) {
        SniItem it;
        it.service = QStringLiteral("demo");
        it.path = QStringLiteral("/demo/%1").arg(i);
        it.uid = it.service + it.path;
        it.title = i == 0 ? QStringLiteral("Demo A")
                          : QStringLiteral("Demo B");
        it.status = QStringLiteral("Active");
        it.tooltip = it.title;
        beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
        m_items.append(it);
        m_uidRow[it.uid] = m_items.size() - 1;
        endInsertRows();
    }
    emit countChanged();
}
