#pragma once
// CommandRunner mínimo (F3-T04/T05): ejecuta + consulta con salida.
#include <QDebug>
#include <QObject>
#include <QProcess>
#include <QString>

class CommandRunner : public QObject {
    Q_OBJECT
public:
    explicit CommandRunner(QObject *parent = nullptr) : QObject(parent) {}
    void setLogQuery(bool v) { m_logQuery = v; }
    Q_INVOKABLE void run(const QString &cmd) {
        if (m_logQuery)
            qDebug().noquote() << "runner-run:" << cmd;
        if (cmd.contains(QLatin1Char('|')) || cmd.contains(QLatin1Char(';'))
            || cmd.contains(QLatin1Char('&')) || cmd.contains(QLatin1Char('$'))
            || cmd.contains(QLatin1Char('"')) || cmd.contains(QLatin1Char('\''))) {
            QProcess::startDetached(QStringLiteral("/bin/sh"),
                                    {QStringLiteral("-c"), cmd});
        } else {
            QStringList parts = QProcess::splitCommand(cmd);
            if (parts.isEmpty())
                return;
            QString prog = parts.takeFirst();
            QProcess::startDetached(prog, parts);
        }
        emit finished(cmd, 0);
    }
    // F3-T05-fix: traza tag + 1ª línea solo con --log-query/demo.
    Q_INVOKABLE void query(const QString &cmd, const QString &tag) {
        if (m_logQuery)
            qDebug().noquote() << "cc-query:" << tag
                               << cmd.split(QLatin1Char('\n')).first().left(80);
        auto *p = new QProcess(this);
        connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, p, tag](int, QProcess::ExitStatus) {
                    QString out = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
                    if (m_logQuery)
                        qDebug().noquote() << "cc-output:" << tag
                                           << out.split(QLatin1Char('\n')).first().left(80);
                    emit outputReady(tag, out);
                    p->deleteLater();
                });
        p->start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), cmd});
    }
    // Log sin ejecución (diagnóstico --log-actions, stderr sin buffer).
    Q_INVOKABLE void logAction(int i, const QString &cmd) {
        qInfo().noquote() << QStringLiteral("MENU_ACTION %1 %2")
                                 .arg(i)
                                 .arg(cmd.isEmpty() ? QStringLiteral("-") : cmd);
    }
signals:
    void finished(const QString &cmd, int code);
    void outputReady(const QString &tag, const QString &output);
private:
    bool m_logQuery = false;
};
