#pragma once
// AppMenuModel (F3-T06): menú global Qt vía DBus, sin dependencias privadas.
//
// Canal verificado en nested (docs/plans/evidence/F3-T06-nested.md):
//   1. Qt6 (QDBusMenuBar, dentro de QtGui) exporta el menubar en el
//      servicio propio de la app, objeto /MenuBar/N, interfaz
//      com.canonical.dbusmenu — PERO solo si el nombre bien conocido
//      com.canonical.AppMenu.Registrar existe en el bus (sin registrar,
//      Kate/Dolphin no exportan nada).
//   2. Ventana activa -> pid vía scripting KWin (workspace.activeWindow.pid;
//      queryWindowInfo() es interactivo y no sirve).
//   3. pid -> servicio: org.freedesktop.DBus.GetConnectionUnixProcessID.
//   4. Layout: GetLayout(0,-1,[]) recursivo; AboutToShow(id) antes de
//      abrir un submenú; Event(id,"clicked",v,t) al activar.
//   5. GTK (Nautilus/Firefox): no exportan dbusmenu -> hasMenu=false,
//      la barra muestra solo el nombre de la app (R-GTK: menú in-window).
//
// Límites conocidos: un solo objeto /MenuBar/N por app (multi-ventana
// resuelve al primero); sin iconos; popup con drill-in en vez de
// submenú lateral macOS (gap documentado en la evidencia).
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusVariant>
#include <QDateTime>
#include <QFile>
#include <QDir>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

// Nodo del layout dbusmenu: (i, a{sv}, av-recursivo).
struct MenuNode {
    qint32 id = 0;
    QVariantMap props;
    QList<MenuNode> children;
};
Q_DECLARE_METATYPE(MenuNode)

inline QDBusArgument &operator<<(QDBusArgument &arg, const MenuNode &node)
{
    // Firma real Qt: (ia{sv}av) — hijos envueltos en variante.
    arg.beginStructure();
    arg << node.id << node.props;
    arg.beginArray(qMetaTypeId<QDBusVariant>());
    for (const auto &c : node.children)
        arg << QDBusVariant(QVariant::fromValue(c));
    arg.endArray();
    arg.endStructure();
    return arg;
}

inline QDBusArgument &operator>>(const QDBusArgument &arg, MenuNode &node)
{
    // Solo lectura: usar SIEMPRE las sobrecargas const de QDBusArgument
    // (las no-const son de escritura y abortan sobre datos recibidos).
    arg.beginStructure();
    arg >> node.id;
    arg >> node.props;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant vw;
        arg >> vw;
        QVariant inner = vw.variant();
        if (inner.userType() == qMetaTypeId<MenuNode>()) {
            node.children.append(inner.value<MenuNode>());
        } else if (inner.userType() == qMetaTypeId<QDBusArgument>()) {
            const QDBusArgument ca = inner.value<QDBusArgument>();
            MenuNode c;
            ca >> c;
            node.children.append(c);
        }
    }
    arg.endArray();
    arg.endStructure();
    return const_cast<QDBusArgument &>(arg);
}

class ActiveProbe : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.bar")
public:
    explicit ActiveProbe(QObject *parent = nullptr) : QObject(parent) {}
public slots:
    void reportActive(const QString &info) { emit activeReported(info); }
signals:
    void activeReported(const QString &info);
};

class AppMenuModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString appName READ appName NOTIFY menusChanged)
    Q_PROPERTY(bool hasMenu READ hasMenu NOTIFY menusChanged)
    Q_PROPERTY(QVariantList topLevel READ topLevel NOTIFY menusChanged)
    Q_PROPERTY(QVariantList submenu READ submenu NOTIFY submenuChanged)
    Q_PROPERTY(QString submenuTitle READ submenuTitle NOTIFY submenuChanged)
public:
    explicit AppMenuModel(bool logDbus = false, QObject *parent = nullptr);
    QString appName() const { return m_appName; }
    bool hasMenu() const { return m_hasMenu; }
    QVariantList topLevel() const { return m_topLevel; }
    QVariantList submenu() const { return m_submenu; }
    QString submenuTitle() const { return m_submenuTitle; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void openSubmenu(int id);
    Q_INVOKABLE void backToTop();
    Q_INVOKABLE void trigger(int id);
    Q_INVOKABLE void closeMenu();
    static QString formatShortcut(const QVariant &v);

signals:
    void menusChanged();
    void submenuChanged();

private slots:
    void onActiveReported(const QString &info);
    void onPoll();

private:
    void ensureScript();
    void pollActive();
    void discoverMenu();
    bool fetchTopLevel();
    QVariantMap nodeToMap(const MenuNode &n, bool withKids) const;
    QDBusInterface menuIface() const;
    void log(const QString &msg) const;
    static void nodeFromList(const QVariantList &l, MenuNode &node);
    static void nodeFromArg(const QDBusArgument &a, MenuNode &node);

    bool m_logDbus = false;
    QTimer m_poll;
    ActiveProbe m_probe;
    bool m_busOwn = false;
    bool m_pollBusy = false;
    QString m_probePath;
    qlonglong m_activePid = -1;
    QString m_appName = QStringLiteral("Nimbus");
    bool m_hasMenu = false;
    QVariantList m_topLevel;
    QVariantList m_submenu;
    QString m_submenuTitle;
    QString m_service;
    QString m_menuPath;
    MenuNode m_root;
};
