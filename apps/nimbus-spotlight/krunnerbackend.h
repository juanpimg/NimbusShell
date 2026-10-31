#pragma once
// Backend KRunner real vía libKF6Runner (F6-T01 Plan B).
// RunnerManager::launchQuery + matchesChanged/queryFinished + run().
// Modo --demo: matches falsos para test de render sin runners.
#include <QElapsedTimer>
#include <QObject>
#include <QStringList>
#include <QVariantList>

#include <KRunner/QueryMatch>

namespace KRunner {
class RunnerManager;
}

class KRunnerBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList matches READ matches NOTIFY matchesChanged)
    Q_PROPERTY(bool querying READ querying NOTIFY queryingChanged)
    Q_PROPERTY(qint64 lastLatencyMs READ lastLatencyMs NOTIFY matchesChanged)
    Q_PROPERTY(bool demo READ demo CONSTANT)
public:
    explicit KRunnerBackend(bool demo, QObject *parent = nullptr);
    QVariantList matches() const { return m_matches; }
    bool querying() const { return m_querying; }
    qint64 lastLatencyMs() const { return m_lastLatencyMs; }
    bool demo() const { return m_demo; }

    Q_INVOKABLE void search(const QString &term);
    Q_INVOKABLE void activate(int index);
    Q_INVOKABLE void clipboardHistory(); // pestaña Clipboard vía klipper

Q_SIGNALS:
    void matchesChanged();
    void queryingChanged();

private Q_SLOTS:
    void onMatchesChanged(const QList<KRunner::QueryMatch> &matches);
    void onQueryFinished();

private:
    void setQuerying(bool v);
    void publishDemo(const QString &term);
    static QVariantMap matchToMap(const KRunner::QueryMatch &m, int i);
    static QString categoryOf(const KRunner::QueryMatch &m);

    KRunner::RunnerManager *m_manager = nullptr;
    QVariantList m_matches;
    QString m_lastTerm;
    QList<KRunner::QueryMatch> m_live; // para activate()
    bool m_querying = false;
    bool m_demo = false;
    QElapsedTimer m_timer;
    qint64 m_lastLatencyMs = -1;
};
