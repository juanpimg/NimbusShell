// mprismodel.h — F10-T01 Now Playing MPRIS (Qt6 DBus, sin KF).
// Lista org.mpris.MediaPlayer2.*, lee PlaybackStatus/Metadata y envía
// PlayPause/Next/Previous. Carátula solo file:// local (sin red).
// Sin reproductor: hasPlayer=false (el QML se oculta). NIMBUS_MPRIS_SIM=1
// o --demo-media: datos fijos deterministas para capturas/tests.
#pragma once
#include <QObject>
#include <QString>
#include <QTimer>

class MprisModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasPlayer READ hasPlayer NOTIFY changed)
    Q_PROPERTY(QString playerName READ playerName NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QString artist READ artist NOTIFY changed)
    Q_PROPERTY(QString artFile READ artFile NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
public:
    explicit MprisModel(QObject *parent = nullptr);
    bool hasPlayer() const { return m_has; }
    QString playerName() const { return m_name; }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString artFile() const { return m_art; }
    bool playing() const { return m_playing; }
    void setDemo(bool d);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
Q_SIGNALS:
    void changed();
private:
    void poll();
    void callPlayer(const QString &method);
    bool m_has = false, m_playing = false, m_demo = false;
    QString m_name, m_title, m_artist, m_art, m_service;
    QTimer m_timer;
};
