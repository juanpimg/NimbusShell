// NotificationServer (F3-T12, R-NOTIF-SERVER): servidor FDO 1.2 mínimo.
// Referencia: spec 1.2 (gal.gnome.org). Timeouts medidos contra el
// comportamiento Plasma (F3-T09: PopupTimeout=5000).
#include "notificationserver.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMetaType>
#include <QFile>
#include <QIcon>
#include <cstdio>

namespace {
const QString kSvc = QStringLiteral("org.freedesktop.Notifications");
const QString kPath = QStringLiteral("/org/freedesktop/Notifications");
const QString kIface = QStringLiteral("org.freedesktop.Notifications");
// Close reasons spec 1.2: 1 expiró, 2 descartada por el usuario,
// 3 cerrada por CloseNotification, 4 indefinida/reservada.
const uint kExpired = 1, kDismissed = 2, kClosedApi = 3, kEvicted = 4;
} // namespace

// image-data hint: struct (iiibiiay) = width,height,rowstride,has_alpha,
// bits_per_sample,channels,data. Vía qdbus_cast (tipos fijos; ver NOTA
// Qt 6.12 en statusnotifiermodel.cpp: el descenso manual user-side está
// roto, el cast con tipos registrados sí funciona).
struct NotifImage {
    qint32 w = 0, h = 0, stride = 0;
    bool alpha = false;
    qint32 bps = 0, channels = 0;
    QByteArray data;
};
Q_DECLARE_METATYPE(NotifImage)
QDBusArgument &operator<<(QDBusArgument &a, const NotifImage &p)
{
    a.beginStructure();
    a << p.w << p.h << p.stride << p.alpha << p.bps << p.channels << p.data;
    a.endStructure();
    return a;
}
const QDBusArgument &operator>>(const QDBusArgument &a, NotifImage &p)
{
    a.beginStructure();
    a >> p.w >> p.h >> p.stride >> p.alpha >> p.bps >> p.channels >> p.data;
    a.endStructure();
    return a;
}

NotificationServer::NotificationServer(QObject *parent)
    : QAbstractListModel(parent)
{
    qDBusRegisterMetaType<NotifImage>();
    new NotificationServerAdaptor(this);
}

bool NotificationServer::registerOnBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        // fprintf (no qWarning): este Qt suprime qDebug/qWarning por
        // defecto (F3-T05-fix); el aviso de conflicto lo lee el test.
        fprintf(stderr, "nimbus-bar: sin bus de sesión, notificaciones "
                "solo locales (--demo-notification)\n");
        return false;
    }
    if (!bus.registerService(kSvc)) {
        // NO fatal (contrato §3 / R-NOTIF-SERVER): el applet stock de
        // Plasma suele poseer el nombre; la barra sigue viva.
        fprintf(stderr, "nimbus-bar: org.freedesktop.Notifications ya "
                "registrado (plasmashell stock?) — sigo SIN servidor de "
                "notificaciones\n");
        return false;
    }
    if (!bus.registerObject(kPath, this)) {
        fprintf(stderr, "nimbus-bar: no se pudo registrar "
                "/org/freedesktop/Notifications (sigo sin servidor)\n");
        bus.unregisterService(kSvc);
        return false;
    }
    m_available = true;
    emit availableChanged();
    qInfo("nimbus-bar: servidor org.freedesktop.Notifications activo");
    return true;
}

int NotificationServer::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant NotificationServer::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();
    const NotifItem &it = m_items.at(index.row());
    switch (role) {
    case IdRole:
        return it.id;
    case AppRole:
        return it.app;
    case SummaryRole:
        return it.summary;
    case BodyRole:
        return it.body;
    case IconSourceRole:
        return it.iconSource;
    case IconNameRole:
        return it.iconName;
    case ActionsRole:
        return actionsToQml(it.actionKeys, it.actionLabels);
    case UrgencyRole:
        return it.urgency;
    case CategoryRole:
        return it.category;
    case TimeStrRole:
        return it.stamp.toString(QStringLiteral("HH:mm"));
    case TimestampRole:
        return it.stamp.toMSecsSinceEpoch();
    case InhibitedRole:
        return it.inhibited;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> NotificationServer::roleNames() const
{
    return {
        {IdRole, "nid"},
        {AppRole, "app"},
        {SummaryRole, "summary"},
        {BodyRole, "body"},
        {IconSourceRole, "iconSource"},
        {IconNameRole, "iconName"},
        {ActionsRole, "actions"},
        {UrgencyRole, "urgency"},
        {CategoryRole, "category"},
        {TimeStrRole, "timeStr"},
        {TimestampRole, "timestamp"},
        {InhibitedRole, "inhibited"},
    };
}

QVariantList NotificationServer::banners() const
{
    QVariantList out;
    for (const NotifItem &it : m_items) {
        if (it.inhibited)
            continue;
        QVariantMap m;
        m[QStringLiteral("nid")] = it.id;
        m[QStringLiteral("app")] = it.app;
        m[QStringLiteral("summary")] = it.summary;
        m[QStringLiteral("body")] = it.body;
        m[QStringLiteral("iconSource")] = it.iconSource;
        m[QStringLiteral("iconName")] = it.iconName;
        m[QStringLiteral("actions")] =
            actionsToQml(it.actionKeys, it.actionLabels);
        m[QStringLiteral("urgency")] = it.urgency;
        m[QStringLiteral("timeStr")] =
            it.stamp.toString(QStringLiteral("HH:mm"));
        out.append(m);
    }
    return out;
}

uint NotificationServer::historyCount() const
{
    return static_cast<uint>(m_items.size());
}

QStringList NotificationServer::capabilities() const
{
    return {QStringLiteral("body"), QStringLiteral("actions"),
            QStringLiteral("icon-static"), QStringLiteral("persistence"),
            QStringLiteral("body-markup")};
}

void NotificationServer::serverInfo(QString &name, QString &vendor,
                                    QString &version, QString &spec) const
{
    name = QStringLiteral("Nimbus");
    vendor = QStringLiteral("NimbusOS");
    version = QStringLiteral("1.0");
    spec = QStringLiteral("1.2");
}

QStringList NotificationServer::splitActions(const QStringList &in,
                                             QStringList &keys,
                                             QStringList &labels)
{
    keys.clear();
    labels.clear();
    // Spec: lista plana [key0,label0,key1,label1,...]; "default" = acción
    // por defecto (clic en el banner).
    for (int i = 0; i + 1 < in.size(); i += 2) {
        keys << in.at(i);
        labels << in.at(i + 1);
    }
    return keys;
}

QVariantList NotificationServer::actionsToQml(const QStringList &keys,
                                             const QStringList &labels)
{
    QVariantList out;
    for (int i = 0; i < keys.size(); ++i) {
        QVariantMap m;
        m[QStringLiteral("key")] = keys.at(i);
        m[QStringLiteral("label")] = labels.at(i);
        out.append(m);
    }
    return out;
}

QString NotificationServer::resolveIcon(const QString &appIcon,
                                        const QVariantMap &hints,
                                        QString &iconName)
{
    iconName.clear();
    // 1. image-path (ruta directa).
    const QString imgPath = hints.value(QStringLiteral("image-path")).toString();
    if (!imgPath.isEmpty() && QFile::exists(imgPath))
        return QStringLiteral("file://") + imgPath;
    // 2. app_icon como ruta.
    if (!appIcon.isEmpty() && appIcon.startsWith(QLatin1Char('/'))
        && QFile::exists(appIcon))
        return QStringLiteral("file://") + appIcon;
    // 3. image-data: decodifica (RGBA/RGB 8bit) — "si es viable".
    if (hints.contains(QStringLiteral("image-data"))) {
        const NotifImage img =
            qdbus_cast<NotifImage>(hints.value(QStringLiteral("image-data")));
        const bool lineal = !img.data.isEmpty() && img.w > 0 && img.h > 0
            && img.bps == 8 && (img.channels == 4 || img.channels == 3)
            && img.data.size() >= img.h * img.stride;
        if (lineal) {
            QImage out(img.w, img.h,
                       img.channels == 4 ? QImage::Format_ARGB32
                                         : QImage::Format_RGB32);
            const auto *d = reinterpret_cast<const unsigned char *>(
                img.data.constData());
            for (int y = 0; y < img.h; ++y) {
                auto *row = reinterpret_cast<QRgb *>(out.scanLine(y));
                const unsigned char *src = d + y * img.stride;
                for (int x = 0; x < img.w; ++x) {
                    const unsigned char *p = src + x * img.channels;
                    row[x] = img.channels == 4 ? qRgba(p[0], p[1], p[2], p[3])
                                               : qRgb(p[0], p[1], p[2]);
                }
            }
            // (sin caché a disco: QML dibuja badge con inicial; el PNG
            // temporal se evita para no dejar basura en nested/CI).
            Q_UNUSED(out);
        }
    }
    // 4. nombre de tema como fallback (rol iconName para uso futuro;
    // QML dibuja badge con inicial si no hay iconSource).
    if (!appIcon.isEmpty() && !appIcon.startsWith(QLatin1Char('/')))
        iconName = appIcon;
    return QString();
}

int NotificationServer::rowOf(uint id) const
{
    return m_idRow.value(id, -1);
}

void NotificationServer::rebuildIndex()
{
    m_idRow.clear();
    for (int i = 0; i < m_items.size(); ++i)
        m_idRow[m_items[i].id] = i;
}

uint NotificationServer::Notify(const QString &appName, uint replacesId,
                                const QString &appIcon,
                                const QString &summary, const QString &body,
                                const QStringList &actions,
                                const QVariantMap &hints, int expireTimeout)
{
    QStringList keys, labels;
    splitActions(actions, keys, labels);
    // Hints útiles: urgency (byte 0/1/2), category, desktop-entry.
    int urgency = 1;
    const QVariant u = hints.value(QStringLiteral("urgency"));
    if (u.isValid()) {
        bool ok = false;
        const int n = u.toInt(&ok);
        if (ok)
            urgency = qBound(0, n, 2);
    }
    // replaces_id: actualiza en su sitio (conserva id y posición).
    if (replacesId != 0) {
        const int row = rowOf(replacesId);
        if (row >= 0) {
            NotifItem &it = m_items[row];
            it.summary = summary;
            it.body = body;
            splitActions(actions, it.actionKeys, it.actionLabels);
            it.urgency = urgency;
            it.category =
                hints.value(QStringLiteral("category")).toString();
            it.desktopEntry =
                hints.value(QStringLiteral("desktop-entry")).toString();
            it.iconSource = resolveIcon(appIcon, hints, it.iconName);
            it.stamp = QDateTime::currentDateTime();
            if (it.timer) {
                it.timer->stop();
                it.timer->deleteLater();
                it.timer = nullptr;
            }
            int timeout = expireTimeout < 0 ? kDefaultTimeout : expireTimeout;
            if (timeout > 0) {
                it.timer = new QTimer(this);
                it.timer->setSingleShot(true);
                it.timer->setInterval(timeout);
                connect(it.timer, &QTimer::timeout, this,
                        [this, id = it.id]() { onExpire(id); });
                it.timer->start();
            }
            const QModelIndex idx = index(row, 0);
            emit dataChanged(idx, idx);
            emit bannersChanged();
            return it.id;
        }
    }
    NotifItem it;
    it.id = m_nextId++;
    it.app = appName.isEmpty() ? QStringLiteral("?") : appName;
    it.appIcon = appIcon;
    it.summary = summary;
    it.body = body;
    it.actionKeys = keys;
    it.actionLabels = labels;
    it.urgency = urgency;
    it.category = hints.value(QStringLiteral("category")).toString();
    it.desktopEntry = hints.value(QStringLiteral("desktop-entry")).toString();
    it.iconSource = resolveIcon(appIcon, hints, it.iconName);
    it.stamp = QDateTime::currentDateTime();
    it.inhibited = m_inhibited; // DND: sin banner pero con historial
    const int timeout = expireTimeout < 0 ? kDefaultTimeout : expireTimeout;
    beginInsertRows(QModelIndex(), 0, 0);
    m_items.prepend(it);
    endInsertRows();
    if (timeout > 0) {
        QTimer *t = new QTimer(this);
        t->setSingleShot(true);
        t->setInterval(timeout);
        const uint nid = m_items.first().id;
        connect(t, &QTimer::timeout, this, [this, nid]() { onExpire(nid); });
        t->start();
        m_items.first().timer = t;
    }
    // Límite 50: se expulsa la más antigua (reason 4, documentada).
    while (m_items.size() > kMaxItems) {
        const int last = m_items.size() - 1;
        const uint evicted = m_items.at(last).id;
        beginRemoveRows(QModelIndex(), last, last);
        if (m_items.at(last).timer)
            m_items.at(last).timer->deleteLater();
        m_items.removeAt(last);
        endRemoveRows();
        emit notificationClosed(evicted, kEvicted);
    }
    rebuildIndex();
    emit countChanged();
    emit bannersChanged();
    return it.id;
}

void NotificationServer::onExpire(uint id)
{
    const int row = rowOf(id);
    if (row < 0)
        return;
    removeAt(row, kExpired);
}

void NotificationServer::removeAt(int row, uint reason)
{
    if (row < 0 || row >= m_items.size())
        return;
    const uint id = m_items.at(row).id;
    beginRemoveRows(QModelIndex(), row, row);
    if (m_items.at(row).timer)
        m_items.at(row).timer->deleteLater();
    m_items.removeAt(row);
    endRemoveRows();
    rebuildIndex();
    emit countChanged();
    emit bannersChanged();
    emit notificationClosed(id, reason);
}

void NotificationServer::CloseNotification(uint id)
{
    const int row = rowOf(id);
    if (row < 0)
        return;
    removeAt(row, kClosedApi);
}

void NotificationServer::dismiss(uint id)
{
    const int row = rowOf(id);
    if (row < 0)
        return;
    removeAt(row, kDismissed);
}

void NotificationServer::invokeAction(uint id, const QString &key)
{
    if (rowOf(id) < 0)
        return;
    emit actionInvoked(id, key);
    // Tras la acción el banner se descarta (comportamiento habitual).
    dismiss(id);
}

void NotificationServer::InvokeAction(uint id, const QString &key)
{
    invokeAction(id, key);
}

void NotificationServer::clearAll()
{
    while (!m_items.isEmpty())
        removeAt(0, kDismissed);
}

void NotificationServer::setInhibited(bool v)
{
    if (m_inhibited == v)
        return;
    m_inhibited = v;
    emit inhibitedChanged();
    emit bannersChanged();
}

void NotificationServer::setInhibitedBy(const QString &v)
{
    if (m_inhibitedBy == v)
        return;
    m_inhibitedBy = v;
    emit inhibitedChanged();
}

void NotificationServer::refreshBanners() { emit bannersChanged(); }

// --- Adaptador DBus ----------------------------------------------------
NotificationServerAdaptor::NotificationServerAdaptor(NotificationServer *srv)
    : QDBusAbstractAdaptor(srv), m_srv(srv)
{
    connect(srv, &NotificationServer::notificationClosed, this,
            &NotificationServerAdaptor::NotificationClosed);
    connect(srv, &NotificationServer::actionInvoked, this,
            &NotificationServerAdaptor::ActionInvoked);
}

bool NotificationServerAdaptor::inhibited() const
{
    return m_srv->inhibited();
}
void NotificationServerAdaptor::setInhibited(bool v)
{
    m_srv->setInhibited(v);
}
QString NotificationServerAdaptor::inhibitedBy() const
{
    return m_srv->inhibitedBy();
}
void NotificationServerAdaptor::setInhibitedBy(const QString &v)
{
    m_srv->setInhibitedBy(v);
}
uint NotificationServerAdaptor::historyCount() const
{
    return m_srv->historyCount();
}
QStringList NotificationServerAdaptor::GetCapabilities()
{
    return m_srv->capabilities();
}
uint NotificationServerAdaptor::Notify(const QString &appName,
                                       uint replacesId,
                                       const QString &appIcon,
                                       const QString &summary,
                                       const QString &body,
                                       const QStringList &actions,
                                       const QVariantMap &hints,
                                       int expireTimeout)
{
    return m_srv->Notify(appName, replacesId, appIcon, summary, body,
                         actions, hints, expireTimeout);
}
void NotificationServerAdaptor::CloseNotification(uint id)
{
    m_srv->CloseNotification(id);
}
QString NotificationServerAdaptor::GetServerInformation(QString &vendor,
                                                       QString &version,
                                                       QString &specVersion)
{
    QString name;
    m_srv->serverInfo(name, vendor, version, specVersion);
    return name;
}
void NotificationServerAdaptor::InvokeAction(uint id, const QString &key)
{
    m_srv->InvokeAction(id, key);
}
