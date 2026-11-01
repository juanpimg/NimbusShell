// weathermodel.h — F10-T01 Tiempo Open-Meteo (Qt6 Network).
// Config ~/.config/nimbus-bar/weather.json {"name","lat","lon"} (Madrid por
// defecto). Caché 10 min en GenericCacheLocation/nimbus-bar/weather.json.
// Offline: última caché o «—», nunca falla. NIMBUS_WEATHER_SIM=1 o
// --demo-weather: datos fijos deterministas.
#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QNetworkAccessManager>

class WeatherModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString city READ city NOTIFY changed)
    Q_PROPERTY(QString temp READ temp NOTIFY changed)
    Q_PROPERTY(QString cond READ cond NOTIFY changed)
    Q_PROPERTY(int condCode READ condCode NOTIFY changed)
    Q_PROPERTY(QString minMax READ minMax NOTIFY changed)
    Q_PROPERTY(QVariantList days READ days NOTIFY changed)
    Q_PROPERTY(bool stale READ stale NOTIFY changed)
public:
    explicit WeatherModel(QObject *parent = nullptr);
    QString city() const { return m_city; }
    QString temp() const { return m_temp; }
    QString cond() const { return m_cond; }
    int condCode() const { return m_code; }
    QString minMax() const { return m_minmax; }
    QVariantList days() const { return m_days; }
    bool stale() const { return m_stale; }
    void setDemo(bool d);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString condName(int code) const;
Q_SIGNALS:
    void changed();
private:
    void loadConfig();
    void loadCache();
    void fetch();
    void applyDoc(const QByteArray &data, bool fromCache);
    QString m_city = QStringLiteral("Madrid");
    double m_lat = 40.4168, m_lon = -3.7038;
    QString m_temp = QStringLiteral("—"), m_cond = QStringLiteral("—"),
            m_minmax = QStringLiteral("—");
    int m_code = -1;
    QVariantList m_days;
    bool m_stale = true, m_demo = false;
    QNetworkAccessManager m_nam;
};
