#pragma once
// CommandRunner mínimo (F3-T04/T05): ejecuta + consulta con salida.
#include <QObject>
#include <QProcess>
#include <QString>

class CommandRunner : public QObject {
    Q_OBJECT
public:
    explicit CommandRunner(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void run(const QString &cmd) {
        QStringList parts = QProcess::splitCommand(cmd);
        if (parts.isEmpty())
            return;
        QString prog = parts.takeFirst();
        QProcess::startDetached(prog, parts);
        emit finished(cmd, 0);
    }
    // F3-T05: ejecuta vía shell y emite outputReady(tag, stdout recortado).
    Q_INVOKABLE void query(const QString &cmd, const QString &tag) {
        auto *p = new QProcess(this);
        connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, p, tag](int, QProcess::ExitStatus) {
                    emit outputReady(tag, QString::fromUtf8(p->readAllStandardOutput()).trimmed());
                    p->deleteLater();
                });
        p->start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), cmd});
    }
signals:
    void finished(const QString &cmd, int code);
    void outputReady(const QString &tag, const QString &output);
};
