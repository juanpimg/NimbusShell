// Modelo de aplicaciones .desktop — NimbusShell F6-T04 (R-APPSVIEW).
// Escanea XDG_DATA_DIRS + ~/.local/share/applications, parsea .desktop,
// deduplica por id, ignora NoDisplay y OnlyShowIn ajenos.
#pragma once

#include <QAbstractListModel>
#include <QIcon>
#include <QPixmap>
#include <QProcess>
#include <QQuickImageProvider>
#include <QStringList>

struct NimbusApp {
    QString id;          // nombre de fichero .desktop
    QString name;
    QString exec;        // Exec limpio (sin %codes)
    QString iconName;
    QStringList categories;
    bool terminal = false;
    int usage = 0;       // frecuencia propia (Suggestions)
};

class AppModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged)
    Q_PROPERTY(bool listMode READ listMode WRITE setListMode NOTIFY listModeChanged)
public:
    enum Roles {
        NameRole = Qt::UserRole + 1, ExecRole, IconRole, CategoriesRole,
        CategoryLabelRole, IdRole, TerminalRole, UsageRole
    };
    explicit AppModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &p = QModelIndex()) const override;
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE void rescan();
    Q_INVOKABLE bool launch(int row);
    Q_INVOKABLE QStringList fixedCategories() const;

    QString filter() const { return m_filter; }
    void setFilter(const QString &f);
    QString category() const { return m_category; }
    void setCategory(const QString &c);
    bool listMode() const { return m_listMode; }
    void setListMode(bool v);

    // Parseo unit-testeable (misma regla que rescan usa por fichero).
    static bool parseDesktopFile(const QString &path, NimbusApp &out);

signals:
    void countChanged();
    void filterChanged();
    void categoryChanged();
    void listModeChanged();

private:
    void rebuild();
    QString categoryOf(const NimbusApp &a) const;
    static QString cleanExec(const QString &exec);
    static QStringList dataDirs();

    QList<NimbusApp> m_all;
    QList<int> m_rows; // índices filtrados en m_all
    QString m_filter;
    QString m_category = QStringLiteral("Todas");
    bool m_listMode = false;
    QString m_usagePath;
    QHash<QString, int> m_usage;
    void loadUsage();
    void saveUsage();
};

// Proveedor de iconos QML: image://nimbusicons/<iconName>.
// QIcon::fromTheme con fallback (ruta absoluta o icono genérico).
class NimbusIconProvider : public QQuickImageProvider
{
public:
    NimbusIconProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
    static QIcon iconFor(const QString &name);
    static QString fallbackLetter(const QString &appName);
};
