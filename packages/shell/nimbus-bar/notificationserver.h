#pragma once
// Servidor FDO de notificaciones dentro de nimbus-bar (F3-T12,
// R-NOTIF-SERVER): sustituye al applet stock de Plasma (que hoy provee
// org.freedesktop.Notifications) para poder retirar el panel stock.
//
// Spec: gal.gnome.org/NotificationSpec 1.2 (GetCapabilities, Notify,
// CloseNotification, GetServerInformation; señales NotificationClosed y
// ActionInvoked). Nombre de bus org.freedesktop.Notifications, objeto
// /org/freedesktop/Notifications.
//
// Si el nombre ya está tomado (plasmashell stock), el registro falla de
// forma NO fatal: available()=false, log claro y la barra sigue viva
// (flag --notifications/--no-notifications; por defecto intenta).
//
// DND: propiedades Inhibited (bool) e InhibitedBy (string) sobre la
// misma interfaz (lectura/escritura vía org.freedesktop.DBus.Properties,
// p.ej. `gdbus call ... /org/freedesktop/Notifications
// org.freedesktop.DBus.Properties Set org.freedesktop.Notifications
// Inhibited "<true>"`). Con DND activo los banners no se muestran pero
// se guardan en el modelo (rol inhibited=true).
//
// Extensiones Nimbus (documentadas, fuera de spec, solo para
// verificación/test): propiedad de solo lectura HistoryCount (nº de
// notificaciones activas en el modelo) y método InvokeAction(id, key)
// (emite ActionInvoked como lo haría el clic en el banner; el clic real
// no es inyectable en nested sin wtype/ydotool).
#include <QAbstractListModel>
#include <QDBusAbstractAdaptor>
#include <QDateTime>
#include <QList>
#include <QMap>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

struct NotifItem {
    uint id = 0;
    QString app;
    QString appIcon;
    QString summary;
    QString body;
    QStringList actionKeys; // claves pares (spec: [key0,label0,...])
    QStringList actionLabels;
    int urgency = 1; // hint urgency 0=baja 1=normal 2=crítica
    QString category;
    QString desktopEntry;
    QString iconSource; // file:// o "" (badge con inicial en QML)
    QString iconName; // nombre de tema (fallback)
    QDateTime stamp;
    bool inhibited = false; // llegó con DND activo (sin banner, con historial)
    QTimer *timer = nullptr; // cierre por timeout (0 = persistente)
};

class NotificationServer : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool inhibited READ inhibited WRITE setInhibited NOTIFY
                   inhibitedChanged)
    Q_PROPERTY(QString inhibitedBy READ inhibitedBy WRITE setInhibitedBy
                   NOTIFY inhibitedChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QVariantList banners READ banners NOTIFY bannersChanged)
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AppRole,
        SummaryRole,
        BodyRole,
        IconSourceRole,
        IconNameRole,
        ActionsRole, // [{key,label}]
        UrgencyRole,
        CategoryRole,
        TimeStrRole, // HH:mm
        TimestampRole, // ms epoch (para tests de timeout)
        InhibitedRole,
    };

    explicit NotificationServer(QObject *parent = nullptr);

    // Intenta registrar el nombre en el bus de sesión. true = somos el
    // servidor. false = nombre tomado o sin bus: log y seguir sin servidor.
    bool registerOnBus();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index,
                  int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool inhibited() const { return m_inhibited; }
    QString inhibitedBy() const { return m_inhibitedBy; }
    bool available() const { return m_available; }
    // Banners visibles para QML: snapshot de no-inhibidas, la más nueva
    // primera (el QML corta a 4 + contador; agrupación por app vía rol app).
    QVariantList banners() const;
    uint historyCount() const;

    // Spec 1.2 (también expuestos por el adaptador DBus).
    QStringList capabilities() const;
    void serverInfo(QString &name, QString &vendor, QString &version,
                    QString &spec) const;

public slots:
    uint Notify(const QString &appName, uint replacesId,
                const QString &appIcon, const QString &summary,
                const QString &body, const QStringList &actions,
                const QVariantMap &hints, int expireTimeout);
    void CloseNotification(uint id);
    // Extensión Nimbus (ver cabecera): invoca una acción por DBus.
    void InvokeAction(uint id, const QString &key);
    // QML: descarte por el usuario (×, clic, Esc) → reason 2.
    void dismiss(uint id);
    void invokeAction(uint id, const QString &key);
    void clearAll();
    void setInhibited(bool v);
    void setInhibitedBy(const QString &v);

signals:
    void inhibitedChanged();
    void availableChanged();
    void countChanged();
    void bannersChanged();
    void notificationClosed(uint id, uint reason);
    void actionInvoked(uint id, const QString &key);

private slots:
    void onExpire(uint id);

private:
    static QStringList splitActions(const QStringList &in, QStringList &keys,
                                    QStringList &labels);
    static QVariantList actionsToQml(const QStringList &keys,
                                     const QStringList &labels);
    static QString resolveIcon(const QString &appIcon,
                               const QVariantMap &hints, QString &iconName);
    int rowOf(uint id) const;
    void removeAt(int row, uint reason);
    void refreshBanners();

    QList<NotifItem> m_items; // la más nueva primera
    QMap<uint, int> m_idRow;
    void rebuildIndex();
    uint m_nextId = 1;
    bool m_inhibited = false;
    QString m_inhibitedBy;
    bool m_available = false;
    static const int kMaxItems = 50;
    static const int kDefaultTimeout = 5000;
};

// Fachada DBus (Q_CLASSINFO org.freedesktop.Notifications). El objeto
// registrado en /org/freedesktop/Notifications es el NotificationServer;
// Qt exporta esta interfaz del adaptador hijo.
class NotificationServerAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
    Q_PROPERTY(bool Inhibited READ inhibited WRITE setInhibited)
    Q_PROPERTY(QString InhibitedBy READ inhibitedBy WRITE setInhibitedBy)
    Q_PROPERTY(uint HistoryCount READ historyCount)
public:
    explicit NotificationServerAdaptor(NotificationServer *srv);
    bool inhibited() const;
    void setInhibited(bool v);
    QString inhibitedBy() const;
    void setInhibitedBy(const QString &v);
    uint historyCount() const;
public slots:
    QStringList GetCapabilities();
    uint Notify(const QString &appName, uint replacesId,
                const QString &appIcon, const QString &summary,
                const QString &body, const QStringList &actions,
                const QVariantMap &hints, int expireTimeout);
    void CloseNotification(uint id);
    QString GetServerInformation(QString &vendor, QString &version,
                                 QString &specVersion);
    // Extensión Nimbus (ver cabecera de NotificationServer).
    void InvokeAction(uint id, const QString &key);
signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &actionKey);
private:
    NotificationServer *m_srv;
};
