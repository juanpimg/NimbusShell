#pragma once
// CommandRunner mínimo (F3-T04): ejecuta comandos sin Quickshell.
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
signals:
    void finished(const QString &cmd, int code);
};
