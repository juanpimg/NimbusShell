// mprismodel.cpp — F10-T01. Poll 2s sobre sessionBus.
#include "mprismodel.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QUrl>

MprisModel::MprisModel(QObject *parent)
    : QObject(parent)
{
    m_demo = !qEnvironmentVariableIsEmpty("NIMBUS_MPRIS_SIM");
    if (m_demo) {
        m_has = true; m_playing = true;
        m_name = QStringLiteral("demo");
        m_title = QStringLiteral("Canción demo");
        m_artist = QStringLiteral("Artista demo");
        m_art.clear();
    }
    m_timer.setInterval(2000);
    connect(&m_timer, &QTimer::timeout, this, &MprisModel::poll);
    m_timer.start();
    if (!m_demo)
        poll();
}

void MprisModel::setDemo(bool d)
{
    m_demo = d;
    if (d) {
        m_has = true; m_playing = true;
        m_name = QStringLiteral("demo");
        m_title = QStringLiteral("Canción demo");
        m_artist = QStringLiteral("Artista demo");
        m_art.clear();
        Q_EMIT changed();
    } else {
        poll();
    }
}

void MprisModel::refresh() { poll(); }

void MprisModel::poll()
{
    if (m_demo)
        return;
    const QStringList svcs =
        QDBusConnection::sessionBus().interface()->registeredServiceNames().value();
    QString found;
    for (const QString &s : svcs) {
        if (s.startsWith(QStringLiteral("org.mpris.MediaPlayer2."))) {
            found = s;
            break;
        }
    }
    if (found.isEmpty()) {
        if (m_has) {
            m_has = false; m_title.clear(); m_artist.clear(); m_art.clear();
            Q_EMIT changed();
        }
        return;
    }
    QDBusInterface props(found, QStringLiteral("/org/mpris/MediaPlayer2"),
                         QStringLiteral("org.freedesktop.DBus.Properties"),
                         QDBusConnection::sessionBus());
    QDBusReply<QVariant> st = props.call(QStringLiteral("Get"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("PlaybackStatus"));
    QDBusReply<QVariant> md = props.call(QStringLiteral("Get"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"), QStringLiteral("Metadata"));
    m_service = found;
    m_name = found.mid(QStringLiteral("org.mpris.MediaPlayer2.").size());
    m_has = true;
    m_playing = st.isValid() && st.value().toString() == QStringLiteral("Playing");
    m_title.clear(); m_artist.clear(); m_art.clear();
    if (md.isValid()) {
        const QVariantMap m = qdbus_cast<QVariantMap>(md.value().value<QDBusArgument>());
        m_title = m.value(QStringLiteral("xesam:title")).toString();
        const QStringList ax = m.value(QStringLiteral("xesam:artist")).toStringList();
        m_artist = ax.join(QStringLiteral(", "));
        const QString art = m.value(QStringLiteral("mpris:artUrl")).toString();
        if (art.startsWith(QStringLiteral("file://"))) {
            const QString local = QUrl(art).toLocalFile();
            if (!local.isEmpty())
                m_art = local;
        }
        // http(s):// se ignora a propósito (sin red).
    }
    if (m_title.isEmpty())
        m_title = QStringLiteral("Sin título");
    Q_EMIT changed();
}

void MprisModel::callPlayer(const QString &method)
{
    if (m_demo) {
        if (method == QStringLiteral("PlayPause"))
            m_playing = !m_playing;
        Q_EMIT changed();
        return;
    }
    if (m_service.isEmpty())
        return;
    QDBusInterface player(m_service, QStringLiteral("/org/mpris/MediaPlayer2"),
                          QStringLiteral("org.mpris.MediaPlayer2.Player"),
                          QDBusConnection::sessionBus());
    player.asyncCall(method);
}

void MprisModel::playPause() { callPlayer(QStringLiteral("PlayPause")); }
void MprisModel::next() { callPlayer(QStringLiteral("Next")); }
void MprisModel::previous() { callPlayer(QStringLiteral("Previous")); }
