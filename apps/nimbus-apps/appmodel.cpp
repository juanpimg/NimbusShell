#include "appmodel.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QPixmap>
#include <QProcess>
#include <QQuickImageProvider>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

namespace {
const char *kFixed[] = {"Todas", "Productividad", "Desarrollo", "Gráficos",
                         "Juegos", "Multimedia", "Utilidades", "Internet",
                         "Ajustes", "Suggestions"};

// Mapeo categoría .desktop -> categoría fija Tahoe (tokens exactos
// case-insensitive; "System" NO es Ajustes: va a Utilidades).
QString mapCategory(const QStringList &cats)
{
    QSet<QString> s;
    for (const QString &c : cats) s.insert(c.toLower());
    auto any = [&](std::initializer_list<const char *> l) {
        for (const char *c : l) if (s.contains(QLatin1String(c))) return true;
        return false;
    };
    if (any({"settings", "desktopsettings", "x-settings"})) return QStringLiteral("Ajustes");
    if (s.contains(QStringLiteral("development"))) return QStringLiteral("Desarrollo");
    if (any({"graphics", "photography"})) return QStringLiteral("Gráficos");
    if (s.contains(QStringLiteral("game"))) return QStringLiteral("Juegos");
    if (any({"audiovideo", "audio", "video", "player", "recorder"})) return QStringLiteral("Multimedia");
    if (any({"network", "webbrowser", "email", "chat", "instantmessaging"})) return QStringLiteral("Internet");
    if (any({"office", "productivity", "education", "science"})) return QStringLiteral("Productividad");
    return QStringLiteral("Utilidades");
}
} // namespace

QString AppModel::cleanExec(const QString &exec)
{
    // Quita %codes de la spec desktop-entry (incluye %u/%U/%f/%F/%i/%c/%k/%d...).
    QString out;
    out.reserve(exec.size());
    for (int i = 0; i < exec.size(); ++i) {
        if (exec[i] == QLatin1Char('%') && i + 1 < exec.size()) { ++i; continue; }
        out += exec[i];
    }
    return out.simplified();
}

QStringList AppModel::dataDirs()
{
    QStringList dirs;
    const QString home = QDir::homePath() + QStringLiteral("/.local/share/applications");
    dirs << home;
    const QByteArray xdg = qgetenv("XDG_DATA_DIRS");
    if (!xdg.isEmpty()) {
        for (const QString &d : QString::fromLocal8Bit(xdg).split(':'))
            if (!d.isEmpty()) dirs << d + QStringLiteral("/applications");
    } else {
        dirs << QStringLiteral("/usr/local/share/applications")
             << QStringLiteral("/usr/share/applications");
    }
    // Directorios estándar de Qt como respaldo.
    for (const QString &d : QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation))
        if (!dirs.contains(d)) dirs << d;
    return dirs;
}

bool AppModel::parseDesktopFile(const QString &path, NimbusApp &out)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    bool inEntry = false;
    QString name, exec, icon, cats, onlyShow, noDisplay, type, terminal, hidden, tryExec;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        if (line.startsWith('[')) { inEntry = (line == QLatin1String("[Desktop Entry]")); continue; }
        if (!inEntry) continue;
        const int eq = line.indexOf('=');
        if (eq < 0) continue;
        QString key = line.left(eq);
        const int br = key.indexOf('['); // Name[es] -> Name
        if (br >= 0) { if (!key.startsWith(QLatin1String("Name["))) continue; key = key.left(br); }
        const QString val = line.mid(eq + 1);
        if (key == QLatin1String("Name") && name.isEmpty()) name = val;
        else if (key == QLatin1String("Exec")) exec = val;
        else if (key == QLatin1String("Icon")) icon = val;
        else if (key == QLatin1String("Categories")) cats = val;
        else if (key == QLatin1String("NoDisplay")) noDisplay = val;
        else if (key == QLatin1String("OnlyShowIn")) onlyShow = val;
        else if (key == QLatin1String("Type")) type = val;
        else if (key == QLatin1String("Terminal")) terminal = val;
        else if (key == QLatin1String("Hidden")) hidden = val;
        else if (key == QLatin1String("TryExec")) tryExec = val;
    }
    if (type != QLatin1String("Application")) return false;
    if (name.isEmpty() || exec.isEmpty()) return false;
    if (noDisplay.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0) return false;
    if (hidden.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0) return false;
    if (!onlyShow.isEmpty()) {
        // Solo KDE/Plasma/Qt son nuestros; GNOME/XFCE ajenos se ignoran.
        bool ok = onlyShow.contains(QLatin1String("KDE"), Qt::CaseInsensitive)
            || onlyShow.contains(QLatin1String("Plasma"), Qt::CaseInsensitive)
            || onlyShow.contains(QLatin1String("Qt"), Qt::CaseInsensitive);
        if (!ok) return false;
    }
    out.id = QFileInfo(path).fileName();
    out.name = name;
    out.exec = cleanExec(exec);
    out.iconName = icon;
    out.categories = cats.split(';', Qt::SkipEmptyParts);
    out.terminal = (terminal.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0);
    Q_UNUSED(tryExec);
    return true;
}

AppModel::AppModel(QObject *parent) : QAbstractListModel(parent)
{
    m_usagePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + QStringLiteral("/nimbus-apps-usage.ini");
    loadUsage();
    rescan();
}

void AppModel::loadUsage()
{
    QSettings s(m_usagePath, QSettings::IniFormat);
    for (const QString &k : s.allKeys()) m_usage[k] = s.value(k).toInt();
}

void AppModel::saveUsage()
{
    QSettings s(m_usagePath, QSettings::IniFormat);
    for (auto it = m_usage.constBegin(); it != m_usage.constEnd(); ++it) s.setValue(it.key(), it.value());
}

QStringList AppModel::fixedCategories() const
{
    return QStringList(std::begin(kFixed), std::end(kFixed));
}

QString AppModel::categoryOf(const NimbusApp &a) const
{
    return mapCategory(a.categories);
}

void AppModel::rescan()
{
    beginResetModel();
    m_all.clear();
    QSet<QString> seen; // deduplica por desktop id: user-local gana.
    QStringList dirs = dataDirs();
    // Orden de prioridad (user-local primero): skip-if-seen, gana el primero.
    for (const QString &dirPath : dirs) {
        QDir d(dirPath);
        if (!d.exists()) continue;
        const QStringList files = d.entryList(QStringList() << QStringLiteral("*.desktop"), QDir::Files);
        for (const QString &fn : files) {
            if (seen.contains(fn)) continue;
            NimbusApp app;
            if (!parseDesktopFile(d.filePath(fn), app)) continue;
            seen.insert(fn);
            app.usage = m_usage.value(app.id, 0);
            m_all.append(app);
        }
    }
    std::sort(m_all.begin(), m_all.end(),
              [](const NimbusApp &a, const NimbusApp &b) {
                  return a.name.localeAwareCompare(b.name) < 0;
              });
    endResetModel();
    rebuild();
}

void AppModel::rebuild()
{
    beginResetModel();
    m_rows.clear();
    const QString f = m_filter.trimmed().toLower();
    QList<QPair<int,int>> sug; // (usage, idx) para Suggestions
    for (int i = 0; i < m_all.size(); ++i) {
        const NimbusApp &a = m_all[i];
        if (!f.isEmpty() && !a.name.toLower().contains(f)) continue;
        if (m_category == QLatin1String("Suggestions")) {
            if (m_usage.value(a.id, 0) > 0) sug << qMakePair(m_usage.value(a.id), i);
            continue;
        }
        if (m_category != QLatin1String("Todas") && categoryOf(a) != m_category) continue;
        m_rows << i;
    }
    if (m_category == QLatin1String("Suggestions")) {
        std::sort(sug.begin(), sug.end(),
                  [](const auto &x, const auto &y) { return x.first > y.first; });
        // Sin historial: muestra las 8 primeras alfabéticas (descubrimiento).
        if (sug.isEmpty()) {
            for (int i = 0; i < qMin(8, m_all.size()); ++i) m_rows << i;
        } else {
            for (const auto &p : sug) m_rows << p.second;
        }
    }
    endResetModel();
    emit countChanged();
}

int AppModel::rowCount(const QModelIndex &p) const
{
    Q_UNUSED(p);
    return m_rows.size();
}

QVariant AppModel::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid() || idx.row() < 0 || idx.row() >= m_rows.size()) return {};
    const NimbusApp &a = m_all[m_rows[idx.row()]];
    switch (role) {
    case NameRole: return a.name;
    case ExecRole: return a.exec;
    case IconRole: return a.iconName;
    case CategoriesRole: return a.categories;
    case CategoryLabelRole: return categoryOf(a);
    case IdRole: return a.id;
    case TerminalRole: return a.terminal;
    case UsageRole: return a.usage;
    default: return {};
    }
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {{NameRole, "appName"}, {ExecRole, "appExec"}, {IconRole, "appIcon"},
            {CategoriesRole, "appCategories"}, {CategoryLabelRole, "appCategory"},
            {IdRole, "appId"}, {TerminalRole, "appTerminal"}, {UsageRole, "appUsage"}};
}

void AppModel::setFilter(const QString &f)
{
    if (m_filter == f) return;
    m_filter = f;
    rebuild();
    emit filterChanged();
}

void AppModel::setCategory(const QString &c)
{
    if (m_category == c) return;
    m_category = c;
    rebuild();
    emit categoryChanged();
}

void AppModel::setListMode(bool v)
{
    if (m_listMode == v) return;
    m_listMode = v;
    emit listModeChanged();
}

bool AppModel::launch(int row)
{
    if (row < 0 || row >= m_rows.size()) return false;
    NimbusApp &a = m_all[m_rows[row]];
    m_usage[a.id] = m_usage.value(a.id, 0) + 1;
    a.usage = m_usage[a.id];
    saveUsage();
    // Sin shell: argv separado, detached. Terminal -> envuelve en x-terminal-emulator.
    QStringList argv = QProcess::splitCommand(a.exec);
    if (argv.isEmpty()) return false;
    QString prog = argv.takeFirst();
    if (a.terminal) {
        argv.prepend(prog);
        argv.prepend(QStringLiteral("-e"));
        prog = QStringLiteral("x-terminal-emulator");
    }
    return QProcess::startDetached(prog, argv);
}

NimbusIconProvider::NimbusIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap NimbusIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int px = requestedSize.isValid() ? qMax(requestedSize.width(), requestedSize.height()) : 64;
    QString key = id;
    QString hint;
    const int q = key.indexOf('?'); // "?name=" solo desambigua caché QML
    if (q >= 0) {
        const QString query = key.mid(q + 1);
        key.truncate(q);
        if (query.startsWith(QLatin1String("name="))) hint = query.mid(5);
    }
    QIcon ic = iconFor(key);
    QPixmap pm = ic.pixmap(px, px);
    if (pm.isNull()) {
        // Fallback: letra sobre fondo neutro (sin assets Apple).
        pm = QPixmap(px, px);
        pm.fill(Qt::transparent);
        QPainter p(&pm);
        p.setRenderHint(QPainter::Antialiasing);
        p.setBrush(QColor(0xE3, 0xE3, 0xE8));
        p.setPen(Qt::NoPen);
        p.drawRoundedRect(pm.rect(), 12, 12);
        p.setPen(QColor(0x00, 0x7A, 0xFF));
        QFont f = p.font();
        f.setPixelSize(px / 2);
        p.setFont(f);
        p.drawText(pm.rect(), Qt::AlignCenter, fallbackLetter(hint.isEmpty() ? key : hint));
    }
    if (size) *size = pm.size();
    return pm;
}

QIcon NimbusIconProvider::iconFor(const QString &name)
{
    if (name.isEmpty()) return {};
    if (QFileInfo(name).isAbsolute() || name.contains('/')) {
        QIcon ic(name);
        if (!ic.isNull()) return ic;
    }
    QIcon themed = QIcon::fromTheme(name);
    if (!themed.isNull()) return themed;
    return QIcon::fromTheme(QStringLiteral("application-x-executable"));
}

QString NimbusIconProvider::fallbackLetter(const QString &appName)
{
    return appName.isEmpty() ? QStringLiteral("?") : appName.left(1).toUpper();
}
