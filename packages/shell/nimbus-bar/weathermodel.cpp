// weathermodel.cpp — F10-T01. Open-Meteo sin API key.
#include "weathermodel.h"
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>

WeatherModel::WeatherModel(QObject *parent)
    : QObject(parent)
{
    m_demo = !qEnvironmentVariableIsEmpty("NIMBUS_WEATHER_SIM");
    loadConfig();
    if (m_demo) {
        m_temp = QStringLiteral("21°");
        m_cond = condName(0);
        m_code = 0;
        m_minmax = QStringLiteral("14° / 24°");
        m_days = { QVariantMap{{"d", "hoy"}, {"code", 0}, {"mx", "24°"}, {"mn", "14°"}},
                   QVariantMap{{"d", "mañana"}, {"code", 2}, {"mx", "23°"}, {"mn", "13°"}},
                   QVariantMap{{"d", "pasado"}, {"code", 61}, {"mx", "19°"}, {"mn", "12°"}} };
        m_stale = false;
        return;
    }
    loadCache();
    fetch();
}

void WeatherModel::setDemo(bool d)
{
    m_demo = d;
    if (d) {
        m_temp = QStringLiteral("21°");
        m_cond = condName(0);
        m_code = 0;
        m_minmax = QStringLiteral("14° / 24°");
        m_days = { QVariantMap{{"d", "hoy"}, {"code", 0}, {"mx", "24°"}, {"mn", "14°"}},
                   QVariantMap{{"d", "mañana"}, {"code", 2}, {"mx", "23°"}, {"mn", "13°"}},
                   QVariantMap{{"d", "pasado"}, {"code", 61}, {"mx", "19°"}, {"mn", "12°"}} };
        m_stale = false;
        Q_EMIT changed();
    } else {
        fetch();
    }
}

void WeatherModel::refresh() { if (!m_demo) fetch(); }

QString WeatherModel::condName(int code) const
{
    if (code < 0) return QStringLiteral("—");
    if (code == 0) return QStringLiteral("Despejado");
    if (code <= 3) return QStringLiteral("Nublado");
    if (code <= 48) return QStringLiteral("Niebla");
    if (code <= 67) return QStringLiteral("Lluvia");
    if (code <= 77) return QStringLiteral("Nieve");
    if (code <= 82) return QStringLiteral("Chubascos");
    if (code <= 99) return QStringLiteral("Tormenta");
    return QStringLiteral("—");
}

void WeatherModel::loadConfig()
{
    const QString cfg = qEnvironmentVariable(
        "XDG_CONFIG_HOME", QDir::homePath() + QStringLiteral("/.config"))
        + QStringLiteral("/nimbus-bar/weather.json");
    QFile f(cfg);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    if (!o.value(QStringLiteral("name")).toString().isEmpty())
        m_city = o.value(QStringLiteral("name")).toString();
    if (o.value(QStringLiteral("lat")).isDouble())
        m_lat = o.value(QStringLiteral("lat")).toDouble();
    if (o.value(QStringLiteral("lon")).isDouble())
        m_lon = o.value(QStringLiteral("lon")).toDouble();
}

static QString cachePath()
{
    const QString d = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
        + QStringLiteral("/nimbus-bar");
    QDir().mkpath(d);
    return d + QStringLiteral("/weather.json");
}

void WeatherModel::loadCache()
{
    QFile f(cachePath());
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    const qint64 ts = root.value(QStringLiteral("ts")).toVariant().toLongLong();
    const qint64 age = QDateTime::currentSecsSinceEpoch() - ts;
    applyDoc(QJsonDocument(root.value(QStringLiteral("payload")).toObject()).toJson(), true);
    m_stale = age > 600;
}

void WeatherModel::fetch()
{
    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("latitude"), QString::number(m_lat, 'f', 4));
    q.addQueryItem(QStringLiteral("longitude"), QString::number(m_lon, 'f', 4));
    q.addQueryItem(QStringLiteral("current"), QStringLiteral("temperature_2m,weather_code"));
    q.addQueryItem(QStringLiteral("daily"),
                   QStringLiteral("temperature_2m_max,temperature_2m_min,weather_code"));
    q.addQueryItem(QStringLiteral("timezone"), QStringLiteral("auto"));
    url.setQuery(q);
    QNetworkReply *r = m_nam.get(QNetworkRequest(url));
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (m_demo)
            return; // --demo-weather gana a la red tardía
        if (r->error() != QNetworkReply::NoError)
            return; // offline honesto: se queda la caché o «—»
        const QByteArray data = r->readAll();
        applyDoc(data, false);
        QJsonObject root;
        root[QStringLiteral("ts")] = QDateTime::currentSecsSinceEpoch();
        root[QStringLiteral("payload")] = QJsonDocument::fromJson(data).object();
        QFile f(cachePath());
        if (f.open(QIODevice::WriteOnly))
            f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    });
}

void WeatherModel::applyDoc(const QByteArray &data, bool fromCache)
{
    Q_UNUSED(fromCache);
    const QJsonObject o = QJsonDocument::fromJson(data).object();
    const QJsonObject cur = o.value(QStringLiteral("current")).toObject();
    const QJsonObject daily = o.value(QStringLiteral("daily")).toObject();
    if (cur.isEmpty() || daily.isEmpty())
        return;
    m_code = cur.value(QStringLiteral("weather_code")).toInt(-1);
    m_temp = QString::number(qRound(cur.value(QStringLiteral("temperature_2m")).toDouble())) + QStringLiteral("°");
    m_cond = condName(m_code);
    const QJsonArray mx = daily.value(QStringLiteral("temperature_2m_max")).toArray();
    const QJsonArray mn = daily.value(QStringLiteral("temperature_2m_min")).toArray();
    const QJsonArray wc = daily.value(QStringLiteral("weather_code")).toArray();
    const QJsonArray tm = daily.value(QStringLiteral("time")).toArray();
    if (!mx.isEmpty() && !mn.isEmpty())
        m_minmax = QString::number(qRound(mn[0].toDouble())) + QStringLiteral("° / ")
            + QString::number(qRound(mx[0].toDouble())) + QStringLiteral("°");
    m_days.clear();
    for (int i = 0; i < qMin(3, mx.size()); ++i) {
        QVariantMap d;
        d[QStringLiteral("d")] = tm.size() > i ? tm[i].toString().mid(5) : QString::number(i);
        d[QStringLiteral("code")] = wc.size() > i ? wc[i].toInt() : -1;
        d[QStringLiteral("mx")] = QString::number(qRound(mx[i].toDouble())) + QStringLiteral("°");
        d[QStringLiteral("mn")] = QString::number(qRound(mn[i].toDouble())) + QStringLiteral("°");
        m_days.append(d);
    }
    m_stale = false;
    Q_EMIT changed();
}
