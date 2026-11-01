// nimbusindex.cpp — fast-path local Nimbus (F6-T02). Sin KF, sin red.
#include "nimbusindex.h"

#include <QClipboard>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusReply>
#include <cmath>
#include <thread>

namespace {
const char *kQuickKeys = "ABCDEFGHIJKL"; // Quick Keys ≤12
const int kMaxQuickKeys = 12;
const int kMaxResults = 20;
const int kMaxFiles = 4000;

// Folding de acentos (F6-T03): "música" ~ "musica", "ratón" ~ "raton".
// Descompone NFD y elimina marcas diacríticas antes de comparar.
QString foldAccents(const QString &s)
{
    const QString n = s.normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(n.size());
    for (const QChar c : n) {
        const QChar::Category cat = c.category();
        if (cat == QChar::Mark_NonSpacing || cat == QChar::Mark_SpacingCombining
            || cat == QChar::Mark_Enclosing)
            continue;
        out += c;
    }
    return out;
}

// KCMs conocidos (id kcm, nombre, keywords) — sin depender de systemsettings.
struct Kcm { const char *id, *name, *kw; };
const Kcm kKcms[] = {
    {"kcm_network", "Red e Internet", "red wifi internet network"},
    {"kcm_bluetooth", "Bluetooth", "bluetooth bt dispositivos"},
    {"kcm_display", "Pantalla", "pantalla monitor resolucion display brightness"},
    {"kcm_sound", "Sonido", "sonido audio volumen altavoces microfono"},
    {"kcm_keyboard", "Teclado", "teclado keyboard atajos layout"},
    {"kcm_mouse", "Ratón y touchpad", "raton mouse touchpad cursor"},
    {"kcm_energy", "Energía", "energia bateria suspension energy power"},
    {"kcm_users", "Usuarios", "usuarios cuentas contrasena users"},
    {"kcm_datetime", "Fecha y hora", "fecha hora reloj timezone"},
    {"kcm_wallpaper", "Fondo de pantalla", "fondo wallpaper escritorio tema"},
    {"kcm_notifications", "Notificaciones", "notificaciones avisos"},
    {"kcm_printers", "Impresoras", "impresora printer imprimir"},
    {"kcm_appearance", "Apariencia", "apariencia tema colores fuentes"},
    {"kcm_region", "Idioma y región", "idioma region locale idioma"},
    {"kcm_access", "Accesibilidad", "accesibilidad acceso a11y"},
};
} // namespace

NimbusIndex::NimbusIndex(QObject *parent) : QObject(parent)
{
    const QString st = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation);
    m_freqPath = st + QStringLiteral("/nimbus-spotlight/frecuencia.json");
    loadFreq();
    scanApps();       // .desktop: rápido y síncrono (<50ms típico)
    scanFilesAsync(); // ficheros: worker para no bloquear UI
    if (!m_scanRunning.load())
        setReady(true);
}

NimbusIndex::~NimbusIndex() = default;

QString NimbusIndex::cleanExec(const QString &exec)
{
    QString out;
    out.reserve(exec.size());
    for (int i = 0; i < exec.size(); ++i) {
        if (exec[i] == QLatin1Char('%') && i + 1 < exec.size()) { ++i; continue; }
        out += exec[i];
    }
    return out.simplified();
}

bool NimbusIndex::parseDesktopFile(const QString &path, LocalApp &out)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    bool inEntry = false;
    QString name, exec, icon, cats, kw, onlyShow, noDisplay, type, hidden;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        if (line.startsWith('[')) { inEntry = (line == QLatin1String("[Desktop Entry]")); continue; }
        if (!inEntry) continue;
        const int eq = line.indexOf('=');
        if (eq < 0) continue;
        QString key = line.left(eq);
        const int br = key.indexOf('[');
        if (br >= 0) {
            if (!key.startsWith(QLatin1String("Name[")) && key.left(br) != QLatin1String("Keywords"))
                continue;
            if (key.startsWith(QLatin1String("Name[")) && !name.isEmpty()) continue;
            key = key.left(br);
        }
        const QString val = line.mid(eq + 1);
        if (key == QLatin1String("Name") && name.isEmpty()) name = val;
        else if (key == QLatin1String("Exec")) exec = val;
        else if (key == QLatin1String("Icon")) icon = val;
        else if (key == QLatin1String("Categories")) cats = val;
        else if (key == QLatin1String("Keywords")) kw += val + ';';
        else if (key == QLatin1String("NoDisplay")) noDisplay = val;
        else if (key == QLatin1String("OnlyShowIn")) onlyShow = val;
        else if (key == QLatin1String("Type")) type = val;
        else if (key == QLatin1String("Hidden")) hidden = val;
    }
    if (type != QLatin1String("Application")) return false;
    if (name.isEmpty() || exec.isEmpty()) return false;
    if (noDisplay.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0) return false;
    if (hidden.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0) return false;
    if (!onlyShow.isEmpty()) {
        bool ok = onlyShow.contains(QLatin1String("KDE"), Qt::CaseInsensitive)
            || onlyShow.contains(QLatin1String("Plasma"), Qt::CaseInsensitive)
            || onlyShow.contains(QLatin1String("Qt"), Qt::CaseInsensitive);
        if (!ok) return false;
    }
    out.id = QFileInfo(path).fileName();
    out.name = name;
    out.exec = cleanExec(exec);
    out.iconName = icon;
    out.keywords = kw + cats;
    const QString cl = cats.toLower();
    out.isSetting = cl.contains(QLatin1String("settings"))
        || cl.contains(QLatin1String("desktopsettings"))
        || cl.contains(QLatin1String("x-settings"));
    return true;
}

// exacto=0 > prefijo=1 > subcadena=2 > subsecuencia=3(+span) ; -1 sin match.
// Insensible a mayúsculas y acentos (foldAccents: música~musica).
int NimbusIndex::fuzzyScore(const QString &candidate, const QString &query)
{
    const QString c = foldAccents(candidate).toLower(),
                  q = foldAccents(query).toLower().trimmed();
    if (q.isEmpty() || c.isEmpty()) return -1;
    if (c == q) return 0;
    if (c.startsWith(q)) return 1;
    if (c.contains(q)) return 2;
    // Subsecuencia ordenada (fuzzy): "kte" ~ "kate".
    int ci = 0, first = -1, last = -1;
    for (int i = 0; i < q.size(); ++i) {
        bool found = false;
        while (ci < c.size()) {
            if (c[ci] == q[i]) {
                if (first < 0) first = ci;
                last = ci; ++ci; found = true; break;
            }
            ++ci;
        }
        if (!found) return -1;
    }
    return 3 + (last - first);
}

bool NimbusIndex::isCalcQuery(const QString &term)
{
    const QString t = term.trimmed();
    if (t.isEmpty()) return false;
    static const QRegularExpression ok(QStringLiteral("^[0-9+\\-*/%^().,\\s]+$"));
    if (!ok.match(t).hasMatch()) return false;
    static const QRegularExpression hasOp(QStringLiteral("[+\\-*/%^]"));
    static const QRegularExpression hasDigit(QStringLiteral("[0-9]"));
    return hasOp.match(t).hasMatch() && hasDigit.match(t).hasMatch();
}

// Shunting-yard seguro: + - * / % ^ paréntesis, decimales, unario -.
double NimbusIndex::evalCalc(const QString &expr, bool &ok)
{
    ok = false;
    QString s = expr.trimmed();
    s.remove(' ');
    s.replace(',', '.');
    if (s.isEmpty()) return 0;
    auto prec = [](QChar o) {
        if (o == '+' || o == '-') return 1;
        if (o == '*' || o == '/' || o == '%') return 2;
        if (o == '^') return 3;
        return 0;
    };
    QList<double> vals;
    QList<QChar> ops;
    auto apply = [&](bool &good) {
        if (ops.isEmpty() || vals.size() < 2) { good = false; return 0.0; }
        const QChar o = ops.takeLast();
        const double b = vals.takeLast(), a = vals.takeLast();
        if (o == '+') return a + b;
        if (o == '-') return a - b;
        if (o == '*') return a * b;
        if (o == '/') { if (b == 0) { good = false; return 0.0; } return a / b; }
        if (o == '%') { if (b == 0) { good = false; return 0.0; } return fmod(a, b); }
        if (o == '^') return pow(a, b);
        good = false; return 0.0;
    };
    bool good = true, expectVal = true;
    int i = 0;
    while (i < s.size() && good) {
        const QChar ch = s[i];
        if (ch.isDigit() || ch == '.' || (ch == '-' && expectVal)) {
            int j = i + (ch == '-' ? 1 : 0);
            bool dot = false;
            while (j < s.size() && (s[j].isDigit() || s[j] == '.')) {
                if (s[j] == '.') { if (dot) { good = false; break; } dot = true; }
                ++j;
            }
            if (j == i + (ch == '-' ? 1 : 0)) { good = false; break; }
            vals << s.mid(i, j - i).toDouble(&good);
            i = j; expectVal = false;
        } else if (ch == '(') { ops << ch; ++i; expectVal = true; }
        else if (ch == ')') {
            while (!ops.isEmpty() && ops.last() != '(') vals << apply(good);
            if (ops.isEmpty()) { good = false; break; }
            ops.takeLast(); ++i; expectVal = false;
        } else if (QStringLiteral("+-*/%^").contains(ch)) {
            while (!ops.isEmpty() && ops.last() != '('
                   && (prec(ops.last()) > prec(ch) || (prec(ops.last()) == prec(ch) && ch != '^')))
                vals << apply(good);
            ops << ch; ++i; expectVal = true;
        } else { good = false; break; }
    }
    while (good && !ops.isEmpty()) {
        if (ops.last() == '(') { good = false; break; }
        vals << apply(good);
    }
    if (!good || vals.size() != 1 || !std::isfinite(vals.first())) { ok = false; return 0; }
    ok = true;
    return vals.first();
}

QString NimbusIndex::webUrl(const QString &term)
{
    QString t = term.trimmed();
    if (t.startsWith('?')) t = t.mid(1).trimmed();
    return QStringLiteral("https://duckduckgo.com/?q=")
        + QString::fromLatin1(QUrl::toPercentEncoding(t));
}

void NimbusIndex::loadFreq()
{
    QFile f(m_freqPath);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonDocument d = QJsonDocument::fromJson(f.readAll());
    if (!d.isObject()) return;
    const QJsonObject o = d.object();
    for (auto it = o.begin(); it != o.end(); ++it) m_freq[it.key()] = it.value().toInt();
}

void NimbusIndex::saveFreq()
{
    QJsonObject o;
    for (auto it = m_freq.constBegin(); it != m_freq.constEnd(); ++it) o[it.key()] = it.value();
    QFile f(m_freqPath);
    QDir().mkpath(QFileInfo(f).absolutePath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

void NimbusIndex::setReady(bool v)
{
    if (m_ready == v) return;
    m_ready = v;
    Q_EMIT indexReadyChanged();
}

void NimbusIndex::setKRunnerFallback(bool v)
{
    if (m_krunnerFallback == v) return;
    m_krunnerFallback = v;
    Q_EMIT krunnerFallbackChanged();
}

void NimbusIndex::scanApps()
{
    m_apps.clear();
    QStringList dirs;
    dirs << QDir::homePath() + QStringLiteral("/.local/share/applications");
    const QByteArray xdg = qgetenv("XDG_DATA_DIRS");
    if (!xdg.isEmpty()) {
        for (const QString &d : QString::fromLocal8Bit(xdg).split(':'))
            if (!d.isEmpty()) dirs << d + QStringLiteral("/applications");
    } else {
        dirs << QStringLiteral("/usr/local/share/applications")
             << QStringLiteral("/usr/share/applications");
    }
    QSet<QString> seen;
    for (const QString &dirPath : dirs) {
        QDir d(dirPath);
        if (!d.exists()) continue;
        for (const QString &fn : d.entryList({QStringLiteral("*.desktop")}, QDir::Files)) {
            if (seen.contains(fn)) continue;
            LocalApp a;
            if (!parseDesktopFile(d.filePath(fn), a)) continue;
            seen.insert(fn);
            m_apps.append(a);
        }
    }
    // KCMs conocidos como ajustes (evita depender de systemsettings).
    for (const Kcm &k : kKcms) {
        LocalApp a;
        a.id = QString::fromLatin1(k.id) + QStringLiteral(".kcm");
        a.name = QString::fromLatin1(k.name);
        a.exec = QStringLiteral("systemsettings ") + QString::fromLatin1(k.id);
        a.keywords = QString::fromLatin1(k.kw) + QStringLiteral(";settings;ajustes");
        a.isSetting = true;
        m_apps.append(a);
    }
}

QList<LocalFile> NimbusIndex::scanRoots(const QStringList &roots, int maxFiles)
{
    QList<LocalFile> files;
    QSet<QString> seen;
    for (const QString &r : roots) {
        if (files.size() >= maxFiles) break;
        QDirIterator it(r, QDir::Files | QDir::NoDotAndDotDot,
                        QDirIterator::Subdirectories);
        const int depth0 = r.count('/');
        int count = 0;
        while (it.hasNext() && files.size() < maxFiles && count < 1500) {
            const QString p = it.next();
            ++count;
            if (p.count('/') - depth0 > 3) continue; // profundidad limitada
            const QString name = QFileInfo(p).fileName();
            if (name.startsWith('.')) continue;
            if (seen.contains(p)) continue;
            seen.insert(p);
            files.append({name, p, false});
        }
    }
    return files;
}

void NimbusIndex::scanFilesAsync()
{
    if (m_scanRunning.exchange(true)) return;
    // Copia caminos en el hilo de llamada (QDir::homePath es barato).
    const QString home = QDir::homePath();
    const QString xbel = home + QStringLiteral("/.local/share/recently-used.xbel");
    const QStringList roots = {home + QStringLiteral("/Desktop"),
                               home + QStringLiteral("/Documents"),
                               home + QStringLiteral("/Downloads"),
                               home + QStringLiteral("/Escritorio"),
                               home + QStringLiteral("/Documentos"),
                               home + QStringLiteral("/Descargas")};
    std::thread([this, guard = QPointer<NimbusIndex>(this), xbel, roots]() {
        QList<LocalFile> files = scanRoots(roots, kMaxFiles);
        QSet<QString> seen;
        for (const LocalFile &f : files) seen.insert(f.path);
        // Recientes de recently-used.xbel (solo file:// existentes).
        QFile xf(xbel);
        if (xf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QString xml = QString::fromUtf8(xf.readAll());
            static const QRegularExpression href(QStringLiteral("href=\"file://([^\"]+)\""));
            auto it = href.globalMatch(xml);
            while (it.hasNext() && files.size() < kMaxFiles) {
                QString p = QUrl::fromPercentEncoding(it.next().captured(1).toUtf8());
                if (seen.contains(p) || !QFileInfo(p).exists()) continue;
                seen.insert(p);
                files.append({QFileInfo(p).fileName(), p, true});
            }
        }
        // F6-T03: si el índice murió (tests crean/destruyen varios),
        // no se toca `this`: el evento nunca se entrega a un colgado.
        if (guard.isNull()) return;
        QMetaObject::invokeMethod(this, [this, files]() {
            m_files = files;
            m_scanRunning.store(false);
            setReady(true);
        }, Qt::QueuedConnection);
    }).detach();
}

QVariantMap NimbusIndex::appToMap(const LocalApp &a, int rank, int qi) const
{
    QVariantMap o;
    o[QStringLiteral("text")] = a.name;
    o[QStringLiteral("subtext")] = a.isSetting ? QStringLiteral("Ajustes") : a.exec;
    o[QStringLiteral("category")] = a.isSetting ? QStringLiteral("actions") : QStringLiteral("apps");
    o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
    o[QStringLiteral("relevance")] = 1.0 - rank * 0.02;
    o[QStringLiteral("icon")] = a.iconName.isEmpty() ? QString()
        : QStringLiteral("image://nimbusicon/") + a.iconName;
    o[QStringLiteral("quickKey")] = qi < kMaxQuickKeys
        ? QString(QChar::fromLatin1(kQuickKeys[qi])) : QString();
    o[QStringLiteral("localKind")] = a.isSetting ? QStringLiteral("setting") : QStringLiteral("app");
    o[QStringLiteral("localId")] = a.id;
    o[QStringLiteral("localExec")] = a.exec;
    return o;
}

QVariantMap NimbusIndex::fileToMap(const LocalFile &f, int rank, int qi) const
{
    QVariantMap o;
    o[QStringLiteral("text")] = f.name;
    o[QStringLiteral("subtext")] = f.path;
    o[QStringLiteral("category")] = QStringLiteral("files");
    o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
    o[QStringLiteral("relevance")] = 0.9 - rank * 0.02;
    o[QStringLiteral("icon")] = QString();
    o[QStringLiteral("quickKey")] = qi < kMaxQuickKeys
        ? QString(QChar::fromLatin1(kQuickKeys[qi])) : QString();
    o[QStringLiteral("localKind")] = QStringLiteral("file");
    o[QStringLiteral("localId")] = f.path;
    o[QStringLiteral("localExec")] = f.path;
    return o;
}

void NimbusIndex::searchLocal(const QString &term, const QString &tab)
{
    QElapsedTimer t;
    t.start();
    m_lastTab = tab;
    setKRunnerFallback(false);
    m_matches.clear();
    const QString q = term.trimmed();
    // Comandos directos: calculadora y web siempre responden sin índice.
    if (isCalcQuery(q)) {
        bool ok = false;
        const double v = evalCalc(q, ok);
        if (ok) {
            QVariantMap o;
            o[QStringLiteral("text")] = QStringLiteral("= %1").arg(v);
            o[QStringLiteral("subtext")] = q + QStringLiteral(" — Calculadora (Enter: copiar)");
            o[QStringLiteral("category")] = QStringLiteral("actions");
            o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
            o[QStringLiteral("relevance")] = 1.0;
            o[QStringLiteral("icon")] = QString();
            o[QStringLiteral("quickKey")] = QStringLiteral("A");
            o[QStringLiteral("localKind")] = QStringLiteral("calc");
            o[QStringLiteral("localId")] = q;
            o[QStringLiteral("localExec")] = QString::number(v);
            m_matches.append(o);
        }
    }
    struct Scored { int score; int freq; QString name; QVariantMap map; };
    QList<Scored> hits;
    if (!q.isEmpty()) {
        // Apps (+ajustes/KCMs).
        for (const LocalApp &a : m_apps) {
            if (tab == QLatin1String("files") || tab == QLatin1String("clipboard")) continue;
            if (tab == QLatin1String("actions") && !a.isSetting) continue;
            if (tab == QLatin1String("apps") && a.isSetting) continue;
            int s = fuzzyScore(a.name, q);
            const int sId = fuzzyScore(QString(a.id).section('.', 0, 0).replace('-', ' '), q);
            QString kw = a.keywords;
            const int sKw = fuzzyScore(kw.replace(';', ' '), q);
            int best = s;
            if (sId >= 0 && (best < 0 || sId < best + 1)) best = sId + 1;
            if (sKw >= 0 && (best < 0 || sKw + 1 < best)) best = sKw + 1;
            if (best < 0) continue;
            hits.append({best, m_freq.value(a.id, 0), a.name, {}});
            hits.last().map = appToMap(a, best, -1);
        }
        // Archivos (caché en memoria, índice ya construido).
        if (tab != QLatin1String("apps") && tab != QLatin1String("actions")
            && tab != QLatin1String("clipboard")) {
            int n = 0;
            for (const LocalFile &f : m_files) {
                int s = fuzzyScore(f.name, q);
                if (s < 0) s = fuzzyScore(f.path, q);
                if (s < 0) continue;
                hits.append({s + 4, m_freq.value(f.path, 0), f.name, {}});
                hits.last().map = fileToMap(f, s + 4, -1);
                if (++n > 60) break; // límite: no ahogar apps
            }
        }
        // Web: siempre una acción ?/texto (sin red).
        if (tab != QLatin1String("apps") && tab != QLatin1String("files")
            && tab != QLatin1String("clipboard")) {
            QVariantMap o;
            const bool bang = q.startsWith('?');
            const QString clean = bang ? q.mid(1).trimmed() : q;
            o[QStringLiteral("text")] = QStringLiteral("Buscar \"%1\" en la web").arg(clean.left(40));
            o[QStringLiteral("subtext")] = QStringLiteral("DuckDuckGo — Enter: abrir");
            o[QStringLiteral("category")] = QStringLiteral("actions");
            o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
            o[QStringLiteral("relevance")] = 0.1;
            o[QStringLiteral("icon")] = QString();
            o[QStringLiteral("quickKey")] = QString();
            o[QStringLiteral("localKind")] = QStringLiteral("web");
            o[QStringLiteral("localId")] = clean;
            o[QStringLiteral("localExec")] = webUrl(q);
            hits.append({100, 0, QString(), o});
        }
    } else {
        // Vacío: top frecuencia (descubrimiento).
        QList<QPair<int, LocalApp>> sug;
        for (const LocalApp &a : m_apps)
            if (m_freq.value(a.id, 0) > 0) sug << qMakePair(m_freq.value(a.id), a);
        std::sort(sug.begin(), sug.end(),
                  [](const auto &x, const auto &y) { return x.first > y.first; });
        for (int i = 0; i < qMin(8, sug.size()); ++i)
            hits.append({0, sug[i].first, sug[i].second.name,
                         appToMap(sug[i].second, 0, -1)});
    }
    // Ranking: exacto>prefijo>fuzzy, luego frecuencia local.
    std::sort(hits.begin(), hits.end(), [](const Scored &a, const Scored &b) {
        if (a.score != b.score) return a.score < b.score;
        return a.freq > b.freq;
    });
    int qi = 0;
    for (auto &h : hits) {
        if (qi >= kMaxResults) break;
        h.map[QStringLiteral("quickKey")] = qi < kMaxQuickKeys
            ? QString(QChar::fromLatin1(kQuickKeys[qi])) : QString();
        m_matches.append(h.map);
        ++qi;
    }
    m_latency = t.elapsed();
    qInfo().noquote() << QStringLiteral("spotlight-local-latency: query=%1ms mode=nimbus results=%2 tab=%3")
                             .arg(m_latency).arg(m_matches.size()).arg(tab);
    Q_EMIT localMatchesChanged();
}

void NimbusIndex::rescan()
{
    scanApps();
    scanFilesAsync();
}

bool NimbusIndex::activateLocal(int index, const QString &action)
{
    if (index < 0 || index >= m_matches.size()) return false;
    const QVariantMap m = m_matches.at(index).toMap();
    const QString kind = m.value(QStringLiteral("localKind")).toString();
    const QString target = m.value(QStringLiteral("localExec")).toString();
    const QString id = m.value(QStringLiteral("localId")).toString();
    const QString act = action.isEmpty() ? QStringLiteral("open") : action;
    recordUse(id);
    if (act == QLatin1String("copy")) {
        if (QGuiApplication::clipboard()) {
            // clip/emoji: copiar el texto COMPLETO (localExec), no el
            // título truncado a 80 (F6-T06: Pegar/Copiar pega todo).
            if (kind == QLatin1String("calc") || kind == QLatin1String("clip")
                || kind == QLatin1String("emoji"))
                QGuiApplication::clipboard()->setText(target);
            else
                QGuiApplication::clipboard()->setText(id);
            return true;
        }
        return false;
    }
    if (act == QLatin1String("reveal")) {
        QString dir = QFileInfo(target).absolutePath();
        if (kind == QLatin1String("file") && !dir.isEmpty())
            return QProcess::startDetached(QStringLiteral("xdg-open"),
                                           {dir});
        return false;
    }
    // open
    if (kind == QLatin1String("calc")) {
        if (QGuiApplication::clipboard()) {
            QGuiApplication::clipboard()->setText(target);
            return true;
        }
        return false;
    }
    if (kind == QLatin1String("web"))
        return QProcess::startDetached(QStringLiteral("xdg-open"), {target});
    if (kind == QLatin1String("file"))
        return QProcess::startDetached(QStringLiteral("xdg-open"), {target});
    // app / setting: argv separado, sin shell.
    QStringList argv = QProcess::splitCommand(target);
    if (argv.isEmpty()) return false;
    return QProcess::startDetached(argv.takeFirst(), argv);
}

void NimbusIndex::recordUse(const QString &id)
{
    if (id.isEmpty()) return;
    m_freq[id] = m_freq.value(id, 0) + 1;
    saveFreq();
}

void NimbusIndex::requestKRunner() { setKRunnerFallback(true); }
void NimbusIndex::clearKRunnerFallback() { setKRunnerFallback(false); }

QVariantMap NimbusIndex::clipEntry(const QString &text, int i)
{
    const QString t = text.left(16384);
    QVariantMap o;
    o[QStringLiteral("text")] = t.left(80);
    // Tipo visible; fecha no la expone el menú klipper (ver evidencia F6-T06).
    o[QStringLiteral("subtext")] = QStringLiteral("Portapapeles · texto · %1 caracteres").arg(t.size());
    o[QStringLiteral("category")] = QStringLiteral("clipboard");
    o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
    o[QStringLiteral("relevance")] = 1.0;
    o[QStringLiteral("icon")] = QString();
    o[QStringLiteral("quickKey")] = i < kMaxQuickKeys
        ? QString(QChar::fromLatin1(kQuickKeys[i])) : QString();
    o[QStringLiteral("localKind")] = QStringLiteral("clip");
    o[QStringLiteral("localId")] = t.left(80);
    o[QStringLiteral("localExec")] = t;
    o[QStringLiteral("clipType")] = QStringLiteral("texto");
    o[QStringLiteral("clipDate")] = QString();
    return o;
}

QStringList NimbusIndex::parseKlipperHistoryFile(const QString &data)
{
    // history2.lst puede traer NUL (QDataStream) o líneas: se aceptan ambos.
    QStringList out;
    QSet<QString> seen;
    QString tmp = data;
    tmp.replace(QChar::Null, '\n');
    for (QString line : tmp.split('\n')) {
        line = line.trimmed();
        if (line.isEmpty() || seen.contains(line)) continue;
        seen.insert(line);
        out.append(line);
    }
    return out;
}

QVariantList NimbusIndex::clipboardEntries(const QString &filter)
{
    QElapsedTimer t;
    t.start();
    // Cadena: klipper DBus → history2.lst → wl-paste (último clipboard).
    // Sin passwords ni Universal Clipboard (R-KRUNNER: fuera de alcance).
    QStringList texts;
    QDBusInterface klipper(QStringLiteral("org.kde.klipper"),
                           QStringLiteral("/klipper"),
                           QStringLiteral("org.kde.klipper.klipper"),
                           QDBusConnection::sessionBus());
    if (klipper.isValid()) {
        QDBusReply<QStringList> r = klipper.call(QStringLiteral("getClipboardHistoryMenu"));
        if (r.isValid()) texts = r.value();
        if (texts.isEmpty()) {
            // getClipboardHistory si existe (índice → texto); tolerante.
            QDBusReply<QString> r1 = klipper.call(QStringLiteral("getClipboardHistoryItem"), 0);
            if (r1.isValid() && !r1.value().isEmpty()) texts << r1.value();
        }
    }
    if (texts.isEmpty()) {
        QFile f(QDir::homePath() + QStringLiteral("/.local/share/klipper/history2.lst"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text))
            texts = parseKlipperHistoryFile(QString::fromUtf8(f.readAll()));
    }
    if (texts.isEmpty()) {
        QProcess wl;
        wl.start(QStringLiteral("wl-paste"), {});
        if (wl.waitForFinished(1500) && wl.exitCode() == 0) {
            const QString cur = QString::fromUtf8(wl.readAllStandardOutput()).trimmed();
            if (!cur.isEmpty()) texts << cur;
        }
    }
    QVariantList out;
    int i = 0;
    const QString q = filter.trimmed();
    for (const QString &e : texts) {
        if (i >= 20) break;
        if (!q.isEmpty() && fuzzyScore(e.left(512), q) < 0
            && !e.contains(q, Qt::CaseInsensitive))
            continue;
        out.append(clipEntry(e, i));
        ++i;
    }
    m_latency = t.elapsed(); // sin emit: QML lo lee vía lastClipLatency()
    return out;
}

bool NimbusIndex::copyToClipboard(const QString &text)
{
    QClipboard *c = QGuiApplication::clipboard();
    if (!c || text.isEmpty()) return false;
    c->setText(text);
    return true;
}

bool NimbusIndex::pasteFromClipboard()
{
    // La app destino necesita recuperar el foco tras ocultar el overlay;
    // ydotool (uinput) inyecta Ctrl+V sin depender del protocolo del compositor.
    const QString exe = QStandardPaths::findExecutable(QStringLiteral("ydotool"));
    if (exe.isEmpty())
        return false;
    QTimer::singleShot(260, this, [exe]() {
        QProcess::startDetached(exe, {QStringLiteral("key"),
                                      QStringLiteral("29:1"), QStringLiteral("47:1"),
                                      QStringLiteral("47:0"), QStringLiteral("29:0")});
    });
    return true;
}

// Tabla emoji propia (F6-T06): glifo Unicode (fuente del sistema) + nombre
// ES + keywords ES/EN para búsqueda. Sin assets externos; i18n: los nombres
// viven aquí listos para traducir (QML los muestra con qsTr en la UI).
struct EmojiRow { const char *glyph, *name, *kw, *cat; };
static const EmojiRow kEmojis[] = {
    {"\xF0\x9F\x98\x80", "sonrisa", "alegre feliz cara smile happy", "caras"},
    {"\xF0\x9F\x98\x82", "risa", "llorar alegria laugh joy", "caras"},
    {"\xF0\x9F\x98\x8D", "enamorado", "corazon ojos love heart", "caras"},
    {"\xF0\x9F\xA4\x94", "pensando", "duda think", "caras"},
    {"\xF0\x9F\x98\x8E", "genial", "gafas sol cool", "caras"},
    {"\xF0\x9F\x98\xB4", "dormido", "dormir sleep", "caras"},
    {"\xF0\x9F\x98\xA2", "triste", "llanto cry sad", "caras"},
    {"\xF0\x9F\x98\xA1", "enfado", "furioso angry", "caras"},
    {"\xF0\x9F\xA4\xAF", "alucinado", "mente explotar mind blown", "caras"},
    {"\xF0\x9F\xA5\xB3", "fiesta", "celebrar party", "caras"},
    {"\xF0\x9F\x98\x87", "angel", "halo bueno halo", "caras"},
    {"\xF0\x9F\xA4\x96", "robot", "maquina robot", "caras"},
    {"\xF0\x9F\x91\x8D", "pulgar arriba", "bien ok like yes", "gestos"},
    {"\xF0\x9F\x91\x8E", "pulgar abajo", "mal no dislike", "gestos"},
    {"\xF0\x9F\x91\x8F", "aplauso", "aplaudir bien clap", "gestos"},
    {"\xF0\x9F\x99\x8F", "gracias", "rezar por favor pray thanks", "gestos"},
    {"\xF0\x9F\x91\x8B", "hola", "adios mano wave", "gestos"},
    {"\xE2\x9C\x8C\xEF\xB8\x8F", "victoria", "paz dos peace", "gestos"},
    {"\xF0\x9F\x92\xAA", "fuerza", "musculo fuerte strong", "gestos"},
    {"\xF0\x9F\x91\x8C", "perfecto", "ok vale okay", "gestos"},
    {"\xF0\x9F\x90\xB1", "gato", "cat", "animales"},
    {"\xF0\x9F\x90\xB6", "perro", "dog", "animales"},
    {"\xF0\x9F\xA6\x8A", "zorro", "fox", "animales"},
    {"\xF0\x9F\x90\xBC", "panda", "oso panda", "animales"},
    {"\xF0\x9F\xA6\x81", "leon", "lion", "animales"},
    {"\xF0\x9F\x90\xB8", "rana", "frog", "animales"},
    {"\xF0\x9F\xA6\x84", "unicornio", "magia unicorn", "animales"},
    {"\xF0\x9F\x90\x9D", "abeja", "miel bee", "animales"},
    {"\xF0\x9F\x8D\x95", "pizza", "comida italiana pizza", "comida"},
    {"\xF0\x9F\x8D\x94", "hamburguesa", "burger comida", "comida"},
    {"\xF0\x9F\x8D\x8E", "manzana", "fruta apple", "comida"},
    {"\xE2\x98\x95", "cafe", "coffee desayuno", "comida"},
    {"\xF0\x9F\x8D\xB0", "tarta", "pastel cumpleanos cake", "comida"},
    {"\xF0\x9F\x8C\xAE", "taco", "mexicana comida", "comida"},
    {"\xF0\x9F\x8D\x87", "uvas", "fruta vino grape", "comida"},
    {"\xF0\x9F\x8D\xA9", "donut", "dona dulce", "comida"},
    {"\xF0\x9F\x8C\x9E", "sol", "soleado sun", "naturaleza"},
    {"\xF0\x9F\x8C\x99", "luna", "noche moon", "naturaleza"},
    {"\xE2\xAD\x90", "estrella", "star", "naturaleza"},
    {"\xF0\x9F\x8C\xA7\xEF\xB8\x8F", "lluvia", "llover rain", "naturaleza"},
    {"\xF0\x9F\x94\xA5", "fuego", "caliente fire hot", "naturaleza"},
    {"\xF0\x9F\x8C\xB3", "arbol", "planta tree", "naturaleza"},
    {"\xF0\x9F\x8C\xB8", "flor", "primavera flower", "naturaleza"},
    {"\xE2\x9D\x84\xEF\xB8\x8F", "nieve", "frio invierno snow", "naturaleza"},
    {"\xF0\x9F\x92\xBB", "portatil", "ordenador laptop computer", "objetos"},
    {"\xF0\x9F\x93\xB1", "movil", "telefono smartphone phone", "objetos"},
    {"\xE2\x9C\x8F\xEF\xB8\x8F", "lapiz", "escribir pencil", "objetos"},
    {"\xF0\x9F\x93\x9A", "libros", "leer books", "objetos"},
    {"\xF0\x9F\x94\x91", "llave", "abrir key", "objetos"},
    {"\xF0\x9F\x92\xA1", "idea", "bombilla pensar idea", "objetos"},
    {"\xF0\x9F\x8E\xA7", "auriculares", "musica headphones", "objetos"},
    {"\xF0\x9F\x93\xB7", "camara", "foto camera photo", "objetos"},
    {"\xE2\x9C\x85", "visto", "ok correcto check", "simbolos"},
    {"\xE2\x9D\x8C", "cruz", "error mal cross", "simbolos"},
    {"\xE2\x9A\xA0\xEF\xB8\x8F", "aviso", "alerta cuidado warning", "simbolos"},
    {"\xE2\x9D\x93", "pregunta", "duda question", "simbolos"},
    {"\xE2\x9D\x97", "exclamacion", "atencion exclamation", "simbolos"},
    {"\xE2\x9E\xA1\xEF\xB8\x8F", "flecha", "derecha arrow", "simbolos"},
    {"\xE2\x99\xBB\xEF\xB8\x8F", "reciclaje", "verde recycle", "simbolos"},
    {"\xE2\x84\xB9\xEF\xB8\x8F", "info", "informacion information", "simbolos"},
    {"\xE2\x9C\x88\xEF\xB8\x8F", "avion", "volar viaje plane", "viajes"},
    {"\xF0\x9F\x9A\x97", "coche", "auto car", "viajes"},
    {"\xF0\x9F\x9A\xB2", "bici", "bicicleta bike", "viajes"},
    {"\xE2\x9B\xB5", "barco", "vela boat", "viajes"},
    {"\xF0\x9F\x8F\xA0", "casa", "hogar home", "viajes"},
    {"\xF0\x9F\x97\xBA\xEF\xB8\x8F", "mapa", "viaje map", "viajes"},
};

QVariantMap NimbusIndex::emojiToMap(const QString &glyph, const QString &name,
                                    const QString &category, const QString &kw, int i)
{
    QVariantMap o;
    o[QStringLiteral("text")] = glyph + QStringLiteral(" ") + name;
    o[QStringLiteral("subtext")] = category + QStringLiteral(" · :")
        + name.split(' ').first() + QStringLiteral(":");
    o[QStringLiteral("category")] = QStringLiteral("clipboard");
    o[QStringLiteral("runner")] = QStringLiteral("Nimbus");
    o[QStringLiteral("relevance")] = 1.0;
    o[QStringLiteral("icon")] = QString();
    o[QStringLiteral("quickKey")] = i < kMaxQuickKeys
        ? QString(QChar::fromLatin1(kQuickKeys[i])) : QString();
    o[QStringLiteral("localKind")] = QStringLiteral("emoji");
    o[QStringLiteral("localId")] = glyph;
    o[QStringLiteral("localExec")] = glyph;
    return o;
}

QString NimbusIndex::emojiRecentsPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
        + QStringLiteral("/nimbus-spotlight/emoji-recents.json");
}

void NimbusIndex::loadEmojiRecents()
{
    m_emojiLoaded = true;
    m_emojiRecents.clear();
    QFile f(emojiRecentsPath());
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonDocument d = QJsonDocument::fromJson(f.readAll());
    const QVariantList l = d.isObject() ? d.object().value(QStringLiteral("recents")).toArray().toVariantList()
                                        : QVariantList();
    for (const QVariant &v : l) {
        const QString g = v.toString();
        if (!g.isEmpty() && !m_emojiRecents.contains(g)) m_emojiRecents.append(g);
    }
    m_emojiRecents = m_emojiRecents.mid(0, 12);
}

void NimbusIndex::saveEmojiRecents()
{
    QJsonObject o;
    QJsonArray a;
    for (const QString &g : m_emojiRecents) a.append(g);
    o[QStringLiteral("recents")] = a;
    QFile f(emojiRecentsPath());
    QDir().mkpath(QFileInfo(f).absolutePath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QStringList NimbusIndex::emojiCategories()
{
    return {QStringLiteral("caras"), QStringLiteral("gestos"),
            QStringLiteral("animales"), QStringLiteral("comida"),
            QStringLiteral("naturaleza"), QStringLiteral("objetos"),
            QStringLiteral("simbolos"), QStringLiteral("viajes")};
}

QVariantList NimbusIndex::emojiList(const QString &term, const QString &category)
{
    QElapsedTimer t;
    t.start();
    if (!m_emojiLoaded) loadEmojiRecents();
    const QString q = term.trimmed();
    const QString cat = category.trimmed().toLower();
    struct Hit { int score; int recent; QVariantMap map; };
    QList<Hit> hits;
    auto known = [&](const QString &g) { return m_emojiRecents.indexOf(g); };
    // Recientes primero con consulta vacía y sin categoría.
    if (q.isEmpty() && cat.isEmpty()) {
        int i = 0;
        for (const QString &g : m_emojiRecents) {
            for (const EmojiRow &e : kEmojis) {
                if (QString::fromUtf8(e.glyph) == g) {
                    hits.append({-100 + i, i,
                                 emojiToMap(g, QString::fromUtf8(e.name),
                                            QString::fromUtf8(e.cat),
                                            QString::fromUtf8(e.kw), 0)});
                    ++i;
                    break;
                }
            }
        }
    }
    for (const EmojiRow &e : kEmojis) {
        const QString glyph = QString::fromUtf8(e.glyph);
        const QString name = QString::fromUtf8(e.name);
        const QString c = QString::fromUtf8(e.cat);
        if (!cat.isEmpty() && c != cat) continue;
        const QString hay = name + QStringLiteral(" ") + QString::fromUtf8(e.kw);
        if (!q.isEmpty() && fuzzyScore(hay, q) < 0
            && !hay.contains(q, Qt::CaseInsensitive)
            && fuzzyScore(name, q) < 0)
            continue;
        const int ri = known(glyph);
        const int s = q.isEmpty() ? 0 : fuzzyScore(hay, q);
        hits.append({s, ri >= 0 ? ri - 1000 : 0,
                     emojiToMap(glyph, name, c, QString::fromUtf8(e.kw), 0)});
    }
    std::sort(hits.begin(), hits.end(), [](const Hit &a, const Hit &b) {
        if (a.recent != b.recent) return a.recent < b.recent;
        return a.score < b.score;
    });
    QVariantList out;
    int qi = 0;
    QSet<QString> seen;
    for (auto &h : hits) {
        const QString g = h.map.value(QStringLiteral("localId")).toString();
        if (seen.contains(g)) continue;
        seen.insert(g);
        if (qi >= 20) break;
        h.map[QStringLiteral("quickKey")] = qi < kMaxQuickKeys
            ? QString(QChar::fromLatin1(kQuickKeys[qi])) : QString();
        out.append(h.map);
        ++qi;
    }
    m_latency = t.elapsed(); // sin emit: QML lo lee vía lastClipLatency()
    return out;
}

void NimbusIndex::recordEmoji(const QString &glyph)
{
    if (glyph.isEmpty()) return;
    if (!m_emojiLoaded) loadEmojiRecents();
    m_emojiRecents.removeAll(glyph);
    m_emojiRecents.prepend(glyph);
    m_emojiRecents = m_emojiRecents.mid(0, 12);
    saveEmojiRecents();
}

QVariantList NimbusIndex::recentEmojis()
{
    if (!m_emojiLoaded) loadEmojiRecents();
    QVariantList out;
    int i = 0;
    for (const QString &g : m_emojiRecents) {
        for (const EmojiRow &e : kEmojis) {
            if (QString::fromUtf8(e.glyph) == g) {
                out.append(emojiToMap(g, QString::fromUtf8(e.name),
                                      QString::fromUtf8(e.cat),
                                      QString::fromUtf8(e.kw), i++));
                break;
            }
        }
    }
    return out;
}
