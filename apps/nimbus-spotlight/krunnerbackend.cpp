// Backend KRunner real vía libKF6Runner (F6-T01 Plan B).
#include "krunnerbackend.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QIcon>

#include <KRunner/QueryMatch>
#include <KRunner/RunnerManager>

namespace {
const char *kQuickKeys = "ABCDEFGHIJKLMNOP"; // Quick Keys ≤12 → se usan 12
const int kMaxQuickKeys = 12;

QString iconSource(const KRunner::QueryMatch &m)
{
    const QString name = m.iconName();
    if (!name.isEmpty())
        return QStringLiteral("image://nimbusicon/") + name;
    return QString();
}
} // namespace

KRunnerBackend::KRunnerBackend(bool demo, QObject *parent)
    : QObject(parent)
    , m_demo(demo)
{
    if (m_demo)
        return;
    m_manager = new KRunner::RunnerManager(this);
    // Como el popup stock: preparar sesión de matches antes de consultar.
    m_manager->setupMatchSession();
    connect(m_manager, &KRunner::RunnerManager::matchesChanged, this,
            &KRunnerBackend::onMatchesChanged);
    connect(m_manager, &KRunner::RunnerManager::queryFinished, this,
            &KRunnerBackend::onQueryFinished);
}

void KRunnerBackend::setQuerying(bool v)
{
    if (m_querying == v)
        return;
    m_querying = v;
    Q_EMIT queryingChanged();
}

QString KRunnerBackend::categoryOf(const KRunner::QueryMatch &m)
{
    // Mapeo a pestañas Cmd+1..4 (contrato §3): Apps/Files/Actions/Otros.
    const QString id = m.runner()->id().toLower();
    const QString cat = m.matchCategory().toLower();
    if (id.contains(QLatin1String("service")) || id.contains(QLatin1String("app"))
        || id.contains(QLatin1String("window")) || cat.contains(QLatin1String("application")))
        return QStringLiteral("apps");
    if (id.contains(QLatin1String("baloo")) || id.contains(QLatin1String("places"))
        || id.contains(QLatin1String("recent")) || id.contains(QLatin1String("location"))
        || id.contains(QLatin1String("bookmark")) || cat.contains(QLatin1String("file")))
        return QStringLiteral("files");
    if (id.contains(QLatin1String("shell")) || id.contains(QLatin1String("power"))
        || id.contains(QLatin1String("session")) || id.contains(QLatin1String("kill"))
        || id.contains(QLatin1String("calc")) || id.contains(QLatin1String("web"))
        || id.contains(QLatin1String("help")))
        return QStringLiteral("actions");
    return QStringLiteral("actions");
}

QVariantMap KRunnerBackend::matchToMap(const KRunner::QueryMatch &m, int i)
{
    QVariantMap o;
    o[QStringLiteral("text")] = m.text();
    o[QStringLiteral("subtext")] = m.subtext();
    o[QStringLiteral("category")] = categoryOf(m);
    o[QStringLiteral("runner")] = m.runner()->name();
    o[QStringLiteral("relevance")] = m.relevance();
    o[QStringLiteral("icon")] = iconSource(m);
    o[QStringLiteral("quickKey")] = (i < kMaxQuickKeys)
        ? QString(QChar::fromLatin1(kQuickKeys[i])) : QString();
    return o;
}

void KRunnerBackend::publishDemo(const QString &term)
{
    // Fake determinista para test de render (nested sin runners).
    struct Row { const char *t, *s, *c, *r, *k; };
    static const Row rows[] = {
        {"Kate", "Editor de texto — Aplicaciones", "apps", "Editor de texto", "K"},
        {"Konsole", "Terminal — Aplicaciones", "apps", "Terminal", "O"},
        {"Dolphin", "Gestor de archivos — Aplicaciones", "apps", "Gestor de archivos", "D"},
        {"kate.desktop", "/usr/share/applications — Archivos", "files", "Archivo", "A"},
        {"Abrir Kate", "Acción: ejecutar kate", "actions", "Acción", ""},
        {"Reiniciar", "Acción de sesión", "actions", "Acción", ""},
    };
    m_matches.clear();
    int qi = 0;
    for (const Row &r : rows) {
        if (!term.isEmpty()
            && !QString::fromLatin1(r.t).contains(term, Qt::CaseInsensitive)
            && !QString::fromLatin1(r.s).contains(term, Qt::CaseInsensitive))
            continue;
        QVariantMap o;
        o[QStringLiteral("text")] = QString::fromLatin1(r.t);
        o[QStringLiteral("subtext")] = QString::fromLatin1(r.s);
        o[QStringLiteral("category")] = QString::fromLatin1(r.c);
        o[QStringLiteral("runner")] = QString::fromLatin1(r.r);
        o[QStringLiteral("relevance")] = 1.0 - qi * 0.05;
        o[QStringLiteral("icon")] = QString();
        o[QStringLiteral("quickKey")] = qi < kMaxQuickKeys
            ? QString(QChar::fromLatin1(kQuickKeys[qi])) : QString();
        m_matches.append(o);
        ++qi;
    }
    m_lastLatencyMs = m_timer.elapsed();
    qInfo().noquote() << QStringLiteral("spotlight-latency: query=%1ms mode=demo results=%2")
                             .arg(m_lastLatencyMs).arg(m_matches.size());
    Q_EMIT matchesChanged();
}

void KRunnerBackend::search(const QString &term)
{
    // Guarda anti-race: mismo término en vuelo → no relanzar (RunnerManager
    // pierde queryFinished con launchQuery encadenados).
    if (term == m_lastTerm && m_querying)
        return;
    m_lastTerm = term;
    m_timer.start();
    setQuerying(true);
    if (m_demo) {
        publishDemo(term.trimmed());
        setQuerying(false);
        return;
    }
    m_manager->launchQuery(term);
    qInfo().noquote() << QStringLiteral("spotlight-search: term='%1'").arg(term);
}

void KRunnerBackend::onMatchesChanged(const QList<KRunner::QueryMatch> &matches)
{
    qInfo().noquote() << QStringLiteral("spotlight-matches: n=%1").arg(matches.size());
    m_live = matches;
    m_matches.clear();
    int i = 0;
    for (const auto &m : matches) {
        if (!m.isValid())
            continue;
        m_matches.append(matchToMap(m, i++));
    }
    m_lastLatencyMs = m_timer.elapsed();
    qInfo().noquote() << QStringLiteral("spotlight-latency: query=%1ms mode=krunner-progressive results=%2")
                             .arg(m_lastLatencyMs).arg(m_matches.size());
    Q_EMIT matchesChanged();
}

void KRunnerBackend::onQueryFinished()
{
    setQuerying(false);
    m_lastLatencyMs = m_timer.elapsed();
    qInfo().noquote() << QStringLiteral("spotlight-latency: query=%1ms mode=krunner results=%2")
                             .arg(m_lastLatencyMs).arg(m_matches.size());
    Q_EMIT matchesChanged();
}

void KRunnerBackend::activate(int index)
{
    if (m_demo) {
        qInfo() << "spotlight-demo-activate index=" << index;
        return;
    }
    if (index < 0 || index >= m_live.size())
        return;
    const KRunner::QueryMatch m = m_live.at(index);
    if (m.isValid())
        m_manager->run(m);
}

void KRunnerBackend::clipboardHistory()
{
    // Pestaña Clipboard (Cmd+4): historial klipper vía DBus, texto plano.
    m_timer.start();
    m_matches.clear();
    QDBusInterface klipper(QStringLiteral("org.kde.klipper"),
                           QStringLiteral("/klipper"),
                           QStringLiteral("org.kde.klipper.klipper"),
                           QDBusConnection::sessionBus());
    if (klipper.isValid()) {
        QDBusReply<QStringList> r = klipper.call(QStringLiteral("getClipboardHistoryMenu"));
        int i = 0;
        if (r.isValid()) {
            for (const QString &e : r.value()) {
                if (i >= 20)
                    break;
                QString t = e.left(16384); // contrato §3: clip <16k
                QVariantMap o;
                o[QStringLiteral("text")] = t.left(80);
                o[QStringLiteral("subtext")] = QStringLiteral("Portapapeles");
                o[QStringLiteral("category")] = QStringLiteral("clipboard");
                o[QStringLiteral("runner")] = QStringLiteral("Klipper");
                o[QStringLiteral("relevance")] = 1.0;
                o[QStringLiteral("icon")] = QString();
                o[QStringLiteral("quickKey")] = QString();
                m_matches.append(o);
                ++i;
            }
        }
    }
    m_lastLatencyMs = m_timer.elapsed();
    qInfo().noquote() << QStringLiteral("spotlight-latency: query=%1ms mode=clipboard results=%2")
                             .arg(m_lastLatencyMs).arg(m_matches.size());
    setQuerying(false);
    Q_EMIT matchesChanged();
}
