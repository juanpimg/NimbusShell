#pragma once
// StatusNotifierModel (F3-T07): system tray vía protocolo SNI real.
// Watcher: org.kde.StatusNotifierWatcher (/StatusNotifierWatcher):
//   prop RegisteredStatusNotifierItems ("servicio/ruta"), señales
//   StatusNotifierItemRegistered/Unregistered, método
//   RegisterStatusNotifierItem (solo lo usa el item, no el host).
// Item: org.kde.StatusNotifierItem — props IconName, IconPixmap
//   (a(iiay) ARGB), Title, Status, ToolTip ((sa(iiay)ss)), Menu
//   (object path a com.canonical.dbusmenu); métodos Activate(x,y) y
//   ContextMenu(x,y). Sin activos Apple: iconos del tema o badge
//   generado (inicial del título).
#include <QAbstractListModel>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QImage>
#include <QList>
#include <QMap>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

struct SniItem {
    QString service; // nombre de bus (bien conocido o único, p.ej. ":1.42")
    QString path; // object path del item
    QString uid; // service + path (clave estable de orden)
    QString title;
    QString iconName;
    QString iconThemePath;
    QString status;
    QString tooltip;
    QString menuPath; // "" si no hay menú dbusmenu
    QImage pixmap; // IconPixmap ya decodificado (puede ser nulo)
};

class StatusNotifierModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
public:
    enum Roles {
        ServiceRole = Qt::UserRole + 1,
        PathRole,
        TitleRole,
        IconNameRole,
        ToolTipRole,
        StatusRole,
        HasMenuRole,
        IconUidRole,
    };

    explicit StatusNotifierModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index,
                  int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // F3-T07: clic izquierdo (Activate) / derecho (ContextMenu).
    Q_INVOKABLE void activate(int row);
    Q_INVOKABLE void contextMenu(int row);
    // Menú dbusmenu: lista plana [{id,label,enabled}] vía GetLayout.
    Q_INVOKABLE QVariantList fetchMenu(int row);
    // Dispara Event(id,"clicked") sobre el menú del item.
    Q_INVOKABLE void triggerMenuAction(int row, int id);
    // Imagen para image://sni/<uid> (pixmap SNI o badge generado).
    QImage imageFor(const QString &uid, const QSize &size) const;
    // --demo-tray: 2 items estáticos si el watcher sigue vacío.
    Q_INVOKABLE void seedDemoItems();

signals:
    void countChanged();

private slots:
    void onItemRegistered(const QString &servicePath);
    void onItemUnregistered(const QString &servicePath);
    void onItemChanged();

private:
    static void splitServicePath(const QString &in, QString &service,
                                 QString &path);
    void addItem(const QString &service, const QString &path);
    void removeItem(const QString &uid);
    void refreshItem(SniItem &it);
    const SniItem *at(int row) const;
    QDBusInterface itemPropIface(const SniItem &it) const;
    static QString decodeToolTip(const QVariant &v);
    static QImage decodePixmap(const QVariant &v);
    static QImage badgeFor(const QString &title, const QSize &size);

    QList<SniItem> m_items;
    QMap<QString, int> m_uidRow; // uid -> fila (orden estable de registro)
    QDBusInterface *m_watcher = nullptr;
};
